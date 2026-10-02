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
            (1...256).contains(textToLatent.latentDimension)
        else {
            throw SupertonicError.invalidModel("Audio and latent dimensions are outside supported limits")
        }
    }
}
