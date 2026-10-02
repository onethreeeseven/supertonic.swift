import Foundation

public enum SupertonicError: Error, LocalizedError, Sendable {
    case playback(String)
    case runtime(String)
    case invalidModel(String)
    case download(String, Int)

    public var errorDescription: String? {
        switch self {
        case .playback(let message): return "Audio playback: \(message)"
        case .runtime(let message): return "ONNX Runtime: \(message)"
        case .invalidModel(let message): return "Invalid Supertonic model: \(message)"
        case .download(let path, let status): return "Model download failed for \(path): HTTP \(status)"
        }
    }
}
