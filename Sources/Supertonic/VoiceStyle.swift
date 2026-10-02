import Foundation

struct VoiceStyle: Decodable, Sendable {
    struct Component: Decodable, Sendable {
        let data: [[[Float]]]
        let dimensions: [Int64]

        enum CodingKeys: String, CodingKey {
            case data
            case dimensions = "dims"
        }

        func validate() throws {
            guard dimensions.count == 3, dimensions[0] == 1,
                dimensions.allSatisfy({ (1...4096).contains($0) }),
                data.count == 1,
                data.allSatisfy({ $0.count == Int(dimensions[1]) }),
                data.allSatisfy({ $0.allSatisfy { $0.count == Int(dimensions[2]) } })
            else {
                throw SupertonicError.invalidVoice("Voice style dimensions do not match its nested data")
            }
            guard data.allSatisfy({ $0.allSatisfy { $0.allSatisfy(\.isFinite) } }) else {
                throw SupertonicError.invalidVoice("Voice style contains non-finite values")
            }
        }

        func tensor(runtime: Runtime) throws -> Tensor {
            return try Tensor(data.flatMap { $0.flatMap { $0 } }, shape: dimensions, runtime: runtime)
        }
    }

    let textStyle: Component
    let durationStyle: Component

    enum CodingKeys: String, CodingKey {
        case textStyle = "styleTtl"
        case durationStyle = "styleDp"
    }

    func validate() throws {
        guard textStyle.dimensions == [1, 50, 256], durationStyle.dimensions == [1, 8, 16] else {
            throw SupertonicError.invalidVoice(
                "Expected Supertonic 3 style_ttl [1, 50, 256] and style_dp [1, 8, 16]")
        }
        try textStyle.validate()
        try durationStyle.validate()
    }
}
