import Foundation

enum AudioFormat: String, CaseIterable, Codable, Identifiable {
    case mp3
    case m4a
    case opus
    case flac
    case wav

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mp3: return "MP3"
        case .m4a: return "M4A / AAC"
        case .opus: return "Opus"
        case .flac: return "FLAC"
        case .wav: return "WAV"
        }
    }
}
