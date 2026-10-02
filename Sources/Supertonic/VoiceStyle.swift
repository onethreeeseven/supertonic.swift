import Foundation

struct VoiceStyle: Decodable {
    struct Component: Decodable {
        let data: [[[Float]]]
        let dimensions: [Int64]

        enum CodingKeys: String, CodingKey {
            case data
            case dimensions = "dims"
        }

        func tensor(runtime: Runtime) throws -> Tensor {
            guard dimensions.count == 3, dimensions[0] == 1,
                dimensions.allSatisfy({ (1...4096).contains($0) })
            else {
                throw SupertonicError.invalidModel(
                    "Voice style dimensions must describe one bounded three-dimensional tensor")
            }
            let values = data.flatMap { $0.flatMap { $0 } }
            guard values.allSatisfy(\.isFinite) else {
                throw SupertonicError.invalidModel("Voice style contains non-finite values")
            }
            return try Tensor(values, shape: dimensions, runtime: runtime)
        }
    }
    let textStyle: Component
    let durationStyle: Component

    enum CodingKeys: String, CodingKey {
        case textStyle = "styleTtl"
        case durationStyle = "styleDp"
    }
}
