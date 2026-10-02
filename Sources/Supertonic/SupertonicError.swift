import Foundation

public enum SupertonicError: Error, LocalizedError, Sendable {
    case playback(String)
    case runtime(String)
    case invalidVoice(String)
    case invalidModel(String)
    case download(String, Int)

    public var errorDescription: String? {
        switch self {
        case .playback(let message): return "Audio playback: \(message)"
        case .runtime(let message): return "ONNX Runtime: \(message)"
        case .invalidVoice(let message): return "Invalid Supertonic voice: \(message)"
        case .invalidModel(let message): return "Invalid Supertonic model: \(message)"
        case .download(let path, let status): return "Model download failed for \(path): HTTP \(status)"
        }
    }
}
