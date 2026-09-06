import Foundation

enum TaskState: String, Codable {
    case pending
    case running
    case processing
    case completed
    case failed
    case cancelled

    var label: String {
        switch self {
        case .pending: return "排队中"
        case .running: return "下载中"
        case .processing: return "处理中"
        case .completed: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }

    var isFinished: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        default: return false
        }
    }
}

struct DownloadTask: Identifiable, Codable, Equatable {
    let id: UUID
    var url: String
    var title: String
    var format: AudioFormat
    var outputDir: String
    var state: TaskState
    var fileProgress: Double
    var progress: Double
    var speed: String
    var eta: String
    var detail: String
    var itemIndex: Int
    var itemCount: Int
    var errorMessage: String?
    var filePath: String?
    var createdAt: Date
    var finishedAt: Date?

    var isFinished: Bool { state.isFinished }
}
