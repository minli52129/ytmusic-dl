import SwiftUI

struct HistoryTabView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var search = ""

    private var items: [DownloadTask] {
        manager.tasks
            .filter { $0.isFinished }
            .filter {
                search.isEmpty
                    || $0.title.localizedCaseInsensitiveContains(search)
                    || ($0.filePath ?? "").localizedCaseInsensitiveContains(search)
            }
            .sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("搜索标题或文件路径", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Spacer()
                Button("清空历史", role: .destructive) {
                    manager.clearHistory()
                }
                .disabled(items.isEmpty)
            }
            .padding(12)
            Divider()
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("暂无历史记录")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { task in
                        row(task)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private func dateText(_ task: DownloadTask) -> String {
        guard let date = task.finishedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func row(_ task: DownloadTask) -> some View {
        HStack(spacing: 10) {
            Image(systemName: task.state == .completed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(task.state == .completed ? Color.green : Color.red)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text([dateText(task), task.state.label, task.format.rawValue.uppercased(), task.filePath ?? ""]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                if task.state == .completed {
                    Button {
                        manager.reveal(task)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("在访达中显示")
                }
                Button {
                    manager.retry(task.id)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("再次下载")
                Button {
                    manager.remove(task.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("删除记录")
            }
        }
        .padding(.vertical, 3)
    }
}
