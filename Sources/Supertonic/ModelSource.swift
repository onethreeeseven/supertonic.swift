import Foundation

enum ModelSource: Sendable {
    case huggingFace
    case githubRelease

    static let preservationTag = "models-supertonic-3-aafc6e32416a"

    func url(for file: ModelFile) throws -> URL {
        let address: String
        switch self {
        case .huggingFace:
            let endpoint = file.path.hasSuffix(".onnx") ? "resolve" : "raw"
            address =
                "https://huggingface.co/supertone-oss-archive/supertonic-3/\(endpoint)/\(ModelAssets.revision)/\(file.path)"
        case .githubRelease:
            let name = URL(fileURLWithPath: file.path).lastPathComponent
            address =
                "https://github.com/onethreeeseven/supertonic.swift/releases/download/\(Self.preservationTag)/\(name)"
        }
        guard let url = URL(string: address) else {
            throw SupertonicError.invalidModel("Invalid model asset URL")
        }
        return url
    }
}
