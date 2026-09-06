import SwiftUI

private struct BrowserOption: Identifiable {
    let value: String
    let label: String
    var id: String { value }
}

struct SettingsTabView: View {
    @EnvironmentObject var manager: DownloadManager
    @AppStorage("defaultOutputDir") private var outputDir = DefaultPaths.downloads
    @AppStorage("defaultFormat") private var formatRaw = AudioFormat.mp3.rawValue
    @AppStorage("maxConcurrent") private var maxConcurrent = 2
    @AppStorage("cookiesBrowser") private var cookiesBrowser = ""
    @AppStorage("proxy") private var proxy = ""

    private let browsers = [
        BrowserOption(value: "", label: "不使用"),
        BrowserOption(value: "chrome", label: "Chrome"),
        BrowserOption(value: "firefox", label: "Firefox"),
        BrowserOption(value: "edge", label: "Edge"),
        BrowserOption(value: "brave", label: "Brave"),
        BrowserOption(value: "chromium", label: "Chromium"),
    ]

    var body: some View {
        Form {
            Section("下载") {
                HStack {
                    Text("默认目录")
                    Text(outputDir)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("选择…") {
                        if let picked = DirectoryPicker.pick() {
                            outputDir = picked
                        }
                    }
                }
                Picker("默认格式", selection: $formatRaw) {
                    ForEach(AudioFormat.allCases) { item in
                        Text(item.label).tag(item.rawValue)
                    }
                }
                Stepper(value: $maxConcurrent, in: 1...6) {
                    Text("同时下载 \(maxConcurrent) 个任务")
                }
            }

            Section("网络") {
                Picker("Cookies 来源", selection: $cookiesBrowser) {
                    ForEach(browsers) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                TextField("HTTP 代理（可选，例如 http://127.0.0.1:7890）", text: $proxy)
            }

            Section("内置组件") {
                LabeledContent("yt-dlp", value: manager.ytdlpVersion ?? "读取中…")
                LabeledContent("FFmpeg", value: manager.ffmpegVersion ?? "读取中…")
                if let error = manager.binariesError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section("说明") {
                Text("应用为 ad-hoc 签名，仅供本机使用。首次运行时组件的隔离属性已自动清理；若系统仍提示无法验证，请在终端执行：xattr -cr /Applications/YTMusicDL.app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("更新 yt-dlp 版本：到仓库的 Actions 页面手动触发 Build 工作流（可指定版本号），重新下载安装即可。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
