import Foundation

public enum SupertonicError: Error, LocalizedError, Sendable {
    case runtime(String)
    case invalidModel(String)
    case download(String, Int)

    public var errorDescription: String? {
        switch self {
        case .runtime(let message): return "ONNX Runtime: \(message)"
        case .invalidModel(let message): return "Invalid Supertonic model: \(message)"
        case .download(let path, let status): return "Model download failed for \(path): HTTP \(status)"
        }
    }
}
