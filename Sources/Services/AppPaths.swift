import Foundation

struct AppError: LocalizedError {
    let description: String
    var errorDescription: String? { description }

    init(_ description: String) {
        self.description = description
    }
}

enum DefaultPaths {
    static var downloads: String {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? NSHomeDirectory()
    }
}

enum AppPaths {
    struct Binaries {
        let ytdlp: URL
        let binDir: URL
    }

    static func prepare() throws -> Binaries {
        guard let binDir = Bundle.main.resourceURL?.appendingPathComponent("bin", isDirectory: true) else {
            throw AppError("找不到内置组件目录，应用包可能不完整")
        }
        for name in ["yt-dlp", "ffmpeg", "ffprobe"] {
            let url = binDir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw AppError("缺少内置组件：\(name)")
            }
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            clearQuarantine(url)
        }
        return Binaries(ytdlp: binDir.appendingPathComponent("yt-dlp"), binDir: binDir)
    }

    private static func clearQuarantine(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-r", "-d", "com.apple.quarantine", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
