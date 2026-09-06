import AppKit
import SwiftUI

enum DirectoryPicker {
    static func pick() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "选择音频保存目录"
        panel.prompt = "选择"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }
}

struct QueueTabView: View {
    @EnvironmentObject var manager: DownloadManager
    @AppStorage("defaultOutputDir") private var outputDir = DefaultPaths.downloads
    @AppStorage("defaultFormat") private var defaultFormatRaw = AudioFormat.mp3.rawValue
    @State private var urlText = ""
    @State private var format: AudioFormat = .mp3

    private var activeTasks: [DownloadTask] {
        manager.tasks.filter { !$0.isFinished }
    }

    var body: some View {
        VStack(spacing: 0) {
            form
            Divider()
            if let error = manager.binariesError {
                errorBanner(error)
            } else if !manager.binariesReady {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在准备内置组件…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            list
        }
        .onAppear {
            format = AudioFormat(rawValue: defaultFormatRaw) ?? .mp3
        }
    }

    private var form: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("粘贴 YouTube Music 链接（单曲 / 专辑 / 歌单均可）", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Picker("格式", selection: $format) {
                    ForEach(AudioFormat.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .fixedSize()
                Button {
                    if let picked = DirectoryPicker.pick() {
                        outputDir = picked
                    }
                } label: {
                    Image(systemName: "folder")
                }
                .help("选择保存目录")
                Button("添加下载", action: add)
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack {
                Text("保存到：\(outputDir)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var list: some View {
        if activeTasks.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text("暂无下载任务，粘贴链接开始")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(activeTasks) { task in
                    TaskRowView(task: task)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private func add() {
        let url = urlText
        manager.addDownload(url: url, format: format, outputDir: outputDir)
        urlText = ""
    }
}
