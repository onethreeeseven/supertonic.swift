import Foundation

struct NoiseGenerator {
    var state: UInt64

    mutating func gaussian() -> Float {
        let first = max(Float.leastNonzeroMagnitude, uniform())
        let second = uniform()
        return sqrt(-2 * log(first)) * cos(2 * .pi * second)
    }

    private mutating func uniform() -> Float {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Float(value >> 40) / Float(1 << 24)
    }
}
