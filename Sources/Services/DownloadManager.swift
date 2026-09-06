import AppKit
import Foundation
import SwiftUI

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var tasks: [DownloadTask] = []
    @Published private(set) var binariesReady = false
    @Published private(set) var binariesError: String?
    @Published private(set) var ytdlpVersion: String?
    @Published private(set) var ffmpegVersion: String?

    private var binaries: AppPaths.Binaries?
    private var runners: [UUID: YtDlpRunner] = [:]
    private var downloadDestinations: [UUID: String] = [:]
    private var prepareStarted = false
    private let history = HistoryStore()

    var maxConcurrent: Int {
        let value = UserDefaults.standard.integer(forKey: "maxConcurrent")
        return (1...6).contains(value) ? value : 2
    }

    var cookiesBrowser: String {
        UserDefaults.standard.string(forKey: "cookiesBrowser") ?? ""
    }

    var proxy: String {
        UserDefaults.standard.string(forKey: "proxy") ?? ""
    }

    init() {
        tasks = history.load()
    }

    func prepareBinaries() {
        guard !prepareStarted else { return }
        prepareStarted = true
        do {
            let resolved = try AppPaths.prepare()
            binaries = resolved
            binariesReady = true
            fetchYtdlpVersion(resolved.ytdlp)
            fetchFfmpegVersion(resolved.binDir.appendingPathComponent("ffmpeg"))
            pump()
        } catch {
            binariesError = error.localizedDescription
        }
    }

    func addDownload(url: String, format: AudioFormat, outputDir: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let task = DownloadTask(
            id: UUID(),
            url: trimmed,
            title: trimmed,
            format: format,
            outputDir: outputDir,
            state: .pending,
            fileProgress: 0,
            progress: 0,
            speed: "",
            eta: "",
            detail: "等待中",
            itemIndex: 0,
            itemCount: 0,
            errorMessage: nil,
            filePath: nil,
            createdAt: Date(),
            finishedAt: nil
        )
        tasks.insert(task, at: 0)
        Notifier.requestAuthorizationIfNeeded()
        pump()
    }

    func cancel(_ id: UUID) {
        runners[id]?.cancel()
        update(id) { task in
            if task.state == .pending {
                task.state = .cancelled
                task.detail = "已取消"
                task.finishedAt = Date()
            }
        }
    }

    func retry(_ id: UUID) {
        guard let original = tasks.first(where: { $0.id == id }) else { return }
        let task = DownloadTask(
            id: UUID(),
            url: original.url,
            title: original.url,
            format: original.format,
            outputDir: original.outputDir,
            state: .pending,
            fileProgress: 0,
            progress: 0,
            speed: "",
            eta: "",
            detail: "等待中",
            itemIndex: 0,
            itemCount: 0,
            errorMessage: nil,
            filePath: nil,
            createdAt: Date(),
            finishedAt: nil
        )
        tasks.insert(task, at: 0)
        pump()
    }

    func remove(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        runners[id]?.cancel()
        persistHistory()
    }

    func clearHistory() {
        tasks.removeAll { $0.isFinished }
        persistHistory()
    }

    func reveal(_ task: DownloadTask) {
        let path = task.filePath ?? task.outputDir
        guard FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func pump() {
        guard binariesReady, binaries != nil else { return }
        let running = tasks.filter { $0.state == .running || $0.state == .processing }.count
        var slots = maxConcurrent - running
        guard slots > 0 else { return }
        for index in tasks.indices where slots > 0 {
            guard tasks[index].state == .pending else { continue }
            startTask(at: index)
            slots -= 1
        }
    }

    private func startTask(at index: Int) {
        guard let binaries else { return }
        let task = tasks[index]
        let runner = YtDlpRunner()
        runners[task.id] = runner
        downloadDestinations[task.id] = nil
        update(task.id) { $0.detail = "启动中…" }
        runner.onLine = { [weak self] line in
            Task { @MainActor [weak self] in
                self?.handleLine(task.id, line: line)
            }
        }
        runner.onTerminate = { [weak self] exitCode in
            Task { @MainActor [weak self] in
                self?.handleTerminate(task.id, exitCode: exitCode)
            }
        }
        do {
            try runner.run(executable: binaries.ytdlp, arguments: makeArguments(for: task))
        } catch {
            update(task.id) {
                $0.state = .failed
                $0.errorMessage = error.localizedDescription
                $0.detail = "无法启动"
                $0.finishedAt = Date()
            }
            persistHistory()
            pump()
        }
    }

    private func makeArguments(for task: DownloadTask) -> [String] {
        guard let binaries else { return [] }
        var args: [String] = []
        args += ["--ffmpeg-location", binaries.binDir.path]
        args += ["-x", "--audio-format", task.format.rawValue, "--audio-quality", "0"]
        args += ["--embed-metadata", "--embed-thumbnail"]
        args += ["--newline"]
        args += ["-P", task.outputDir]
        if isPlaylistURL(task.url) {
            args += ["--yes-playlist", "-o", "%(playlist_title)s/%(playlist_index)02d - %(title)s.%(ext)s"]
        } else {
            args += ["--no-playlist", "-o", "%(title)s.%(ext)s"]
        }
        args += ["--progress-template", "download:PROG\t%(progress.downloaded_bytes)s\t%(progress.total_bytes_estimate)s\t%(progress.total_bytes)s\t%(progress.speed)s\t%(progress.eta)s"]
        args += ["--retries", "3", "--fragment-retries", "3"]
        let cookies = cookiesBrowser
        if !cookies.isEmpty {
            args += ["--cookies-from-browser", cookies]
        }
        let proxy = self.proxy
        if !proxy.isEmpty {
            args += ["--proxy", proxy]
        }
        args += [task.url]
        return args
    }

    private func isPlaylistURL(_ url: String) -> Bool {
        let lower = url.lowercased()
        if lower.contains("watch?v=") { return false }
        return lower.contains("list=") || lower.contains("/playlist")
    }

    private func handleLine(_ id: UUID, line raw: String) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }

        if line.hasPrefix("PROG\t") {
            let parts = line.dropFirst(5)
                .split(separator: "\t", omittingEmptySubsequences: false)
                .map(String.init)
            let downloaded = Double(parts.count > 0 ? parts[0] : "") ?? 0
            let estimate = Double(parts.count > 1 ? parts[1] : "") ?? 0
            let total = Double(parts.count > 2 ? parts[2] : "") ?? 0
            let speed = Double(parts.count > 3 ? parts[3] : "")
            let eta = Double(parts.count > 4 ? parts[4] : "")
            applyProgress(id, downloaded: downloaded, total: max(estimate, total), speed: speed, eta: eta)
            return
        }

        if let match = Self.itemRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let ns = line as NSString
            let index = Int(ns.substring(with: match.range(at: 1))) ?? 0
            let count = Int(ns.substring(with: match.range(at: 2))) ?? 0
            update(id) {
                $0.itemIndex = index
                $0.itemCount = count
                $0.fileProgress = 0
                $0.state = .running
                $0.detail = "列表第 \(index)/\(count) 首"
            }
            return
        }

        if line.hasPrefix("[ExtractAudio]") {
            if let range = line.range(of: "Destination: ") {
                let path = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                update(id) {
                    $0.filePath = path
                    $0.title = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                    $0.state = .processing
                    $0.detail = "转码中…"
                }
            } else {
                update(id) {
                    $0.state = .processing
                    $0.detail = "转码中…"
                }
            }
            return
        }

        if line.hasPrefix("[Metadata]") || line.hasPrefix("[EmbedThumbnail]") || line.hasPrefix("[Fixup") {
            update(id) {
                $0.state = .processing
                $0.detail = "写入标签与封面…"
            }
            return
        }

        if let range = line.range(of: "Destination: "), line.hasPrefix("[download]") {
            let path = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            downloadDestinations[id] = path
            let name = URL(fileURLWithPath: path)
                .deletingPathExtension()
                .deletingPathExtension()
                .lastPathComponent
            update(id) {
                if $0.title.isEmpty || $0.title == $0.url {
                    $0.title = name
                }
                $0.detail = "下载中…"
            }
            return
        }

        if let range = line.range(of: "ERROR: ") {
            let message = String(line[range.upperBound...])
            update(id) { $0.errorMessage = String(message.prefix(300)) }
            update(id) { $0.detail = String(line.prefix(160)) }
            return
        }

        if line.hasPrefix("ERROR") {
            update(id) { $0.errorMessage = String(line.prefix(300)) }
            return
        }

        if line.contains("WARNING") || line.hasPrefix("[") {
            update(id) { $0.detail = String(line.prefix(160)) }
        }
    }

    private func handleTerminate(_ id: UUID, exitCode: Int32) {
        let runner = runners[id]
        runners[id] = nil
        let cancelled = runner?.isCancelled ?? false
        let fallbackPath = downloadDestinations[id]
        downloadDestinations[id] = nil

        var completedTitle = ""
        var completedOK = false
        update(id) { task in
            task.finishedAt = Date()
            if cancelled {
                task.state = .cancelled
                task.detail = "已取消"
            } else if exitCode == 0 {
                task.state = .completed
                task.progress = task.itemCount > 1 ? 1 : task.fileProgress
                if task.progress < 1 && task.itemCount <= 1 {
                    task.progress = 1
                }
                task.detail = "完成"
                if task.filePath == nil {
                    task.filePath = fallbackPath
                }
                completedOK = true
                completedTitle = task.title
            } else {
                task.state = .failed
                task.detail = "失败"
                if task.errorMessage == nil {
                    task.errorMessage = "yt-dlp 退出码 \(exitCode)，可尝试在设置中更新 yt-dlp 或开启 Cookies"
                }
                if task.filePath == nil {
                    task.filePath = fallbackPath
                }
            }
        }
        if completedOK {
            Notifier.notifyDownloadFinished(title: completedTitle, success: true)
        } else if !cancelled {
            update(id) { completedTitle = $0.title }
            Notifier.notifyDownloadFinished(title: completedTitle, success: false)
        }
        persistHistory()
        pump()
    }

    private func applyProgress(_ id: UUID, downloaded: Double, total: Double, speed: Double?, eta: Double?) {
        update(id) { task in
            task.state = .running
            task.fileProgress = total > 0 ? min(downloaded / total, 1) : 0
            task.progress = task.itemCount > 1
                ? (Double(max(task.itemIndex - 1, 0)) + task.fileProgress) / Double(task.itemCount)
                : task.fileProgress
            task.speed = Self.formatSpeed(speed)
            task.eta = Self.formatEta(eta)
        }
    }

    private func update(_ id: UUID, _ mutate: (inout DownloadTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        mutate(&tasks[index])
    }

    private func persistHistory() {
        history.save(tasks.filter { $0.isFinished })
    }

    private func fetchYtdlpVersion(_ url: URL) {
        let runner = YtDlpRunner()
        var value = ""
        runner.onLine = {
            if value.isEmpty {
                value = $0.trimmingCharacters(in: .whitespaces)
            }
        }
        runner.onTerminate = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.ytdlpVersion = value.isEmpty ? "未知" : value
            }
        }
        try? runner.run(executable: url, arguments: ["--version"])
    }

    private func fetchFfmpegVersion(_ url: URL) {
        let runner = YtDlpRunner()
        var value = ""
        runner.onLine = {
            if value.isEmpty {
                value = $0.trimmingCharacters(in: .whitespaces)
            }
        }
        runner.onTerminate = { [weak self] _ in
            Task { @MainActor [weak self] in
                let parts = value.split(separator: " ").prefix(3).joined(separator: " ")
                self?.ffmpegVersion = parts.isEmpty ? "未知" : parts
            }
        }
        try? runner.run(executable: url, arguments: ["-version"])
    }

    static func formatSpeed(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond > 0 else { return "" }
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .decimal)
        return formatted + "/s"
    }

    static func formatEta(_ seconds: Double?) -> String {
        guard let seconds, seconds > 0, seconds.isFinite else { return "" }
        let minutes = Int(seconds) / 60
        let rest = Int(seconds) % 60
        return String(format: "剩余 %02d:%02d", minutes, rest)
    }

    private static let itemRegex = try! NSRegularExpression(pattern: "Downloading item (\\d+) of (\\d+)")
}
