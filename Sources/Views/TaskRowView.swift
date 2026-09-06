import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var manager: DownloadManager
    let task: DownloadTask

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 18))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !task.isFinished {
                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(percentText)
                    .font(.caption)
                    .monospacedDigit()
                if !task.speed.isEmpty || !task.eta.isEmpty {
                    Text([task.speed, task.eta].filter { !$0.isEmpty }.joined(separator: "  "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            actions
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch task.state {
        case .pending: return "clock"
        case .running: return "arrow.down.circle.fill"
        case .processing: return "waveform.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }

    private var iconColor: Color {
        switch task.state {
        case .pending: return .secondary
        case .running: return .blue
        case .processing: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }

    private var subtitle: String {
        switch task.state {
        case .pending:
            return "排队中 · \(task.format.rawValue.uppercased())"
        case .running, .processing:
            return task.detail.isEmpty ? task.state.label : task.detail
        case .completed:
            return task.filePath ?? "已完成"
        case .failed:
            return task.errorMessage ?? "下载失败"
        case .cancelled:
            return "已取消"
        }
    }

    private var percentText: String {
        let percent = Int((task.progress * 100).rounded())
        if task.itemCount > 1 && !task.isFinished {
            return "第 \(max(task.itemIndex, 1))/\(task.itemCount) 首 · \(percent)%"
        }
        return "\(percent)%"
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 4) {
            if task.state == .pending || task.state == .running || task.state == .processing {
                Button {
                    manager.cancel(task.id)
                } label: {
                    Image(systemName: "stop.circle")
                }
                .buttonStyle(.borderless)
                .help("取消")
            }
            if task.state == .failed || task.state == .cancelled {
                Button {
                    manager.retry(task.id)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("重新下载")
            }
            if task.state == .completed {
                Button {
                    manager.reveal(task)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("在访达中显示")
            }
            if task.isFinished {
                Button {
                    manager.remove(task.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("移除记录")
            }
        }
    }
}
