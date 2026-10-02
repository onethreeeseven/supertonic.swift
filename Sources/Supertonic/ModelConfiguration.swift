import Foundation

struct ModelConfiguration: Decodable {
    struct AudioEncoder: Decodable {
        let sampleRate: Int
        let baseChunkSize: Int
    }
    struct TextToLatent: Decodable {
        let chunkCompressFactor: Int
        let latentDimension: Int

        enum CodingKeys: String, CodingKey {
            case chunkCompressFactor
            case latentDimension = "latentDim"
        }
    }
    let audioEncoder: AudioEncoder
    let textToLatent: TextToLatent

    enum CodingKeys: String, CodingKey {
        case audioEncoder = "ae"
        case textToLatent = "ttl"
    }

    var chunkSize: Int { audioEncoder.baseChunkSize * textToLatent.chunkCompressFactor }
    var channels: Int { textToLatent.latentDimension * textToLatent.chunkCompressFactor }

    func validate() throws {
        guard (8000...192000).contains(audioEncoder.sampleRate),
              (1...8192).contains(audioEncoder.baseChunkSize),
              (1...64).contains(textToLatent.chunkCompressFactor),
              (1...256).contains(textToLatent.latentDimension) else {
            throw SupertonicError.invalidModel("Audio and latent dimensions are outside supported limits")
        }
    }
}

struct VoiceStyle: Decodable {
    struct Component: Decodable {
        let data: [[[Float]]]
        let dims: [Int64]

        func tensor(runtime: Runtime) throws -> Tensor {
            guard dims.count == 3, dims[0] == 1, dims.allSatisfy({ (1...4096).contains($0) }) else {
                throw SupertonicError.invalidModel("Voice style dimensions must describe one bounded three-dimensional tensor")
            }
            let values = data.flatMap { $0.flatMap { $0 } }
            guard values.allSatisfy(\.isFinite) else { throw SupertonicError.invalidModel("Voice style contains non-finite values") }
            return try Tensor(values, shape: dims, runtime: runtime)
        }
    }
    let textStyle: Component
    let durationStyle: Component

    enum CodingKeys: String, CodingKey {
        case textStyle = "styleTtl"
        case durationStyle = "styleDp"
    }
}

func decode<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(type, from: Data(contentsOf: url))
}
