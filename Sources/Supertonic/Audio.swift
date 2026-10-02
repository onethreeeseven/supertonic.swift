import Foundation

public struct Audio: Sendable {
    public let samples: [Float]
    public let sampleRate: Int
    public var duration: Double { Double(samples.count) / Double(sampleRate) }

    public func write(to url: URL) throws {
        try wavData.write(to: url, options: .atomic)
    }

    public var wavData: Data {
        var data = Data("RIFF".utf8)
        data.appendInteger(UInt32(36 + samples.count * 2))
        data.append(contentsOf: "WAVEfmt ".utf8)
        data.appendInteger(UInt32(16))
        data.appendInteger(UInt16(1))
        data.appendInteger(UInt16(1))
        data.appendInteger(UInt32(sampleRate))
        data.appendInteger(UInt32(sampleRate * 2))
        data.appendInteger(UInt16(2))
        data.appendInteger(UInt16(16))
        data.append(contentsOf: "data".utf8)
        data.appendInteger(UInt32(samples.count * 2))
        for sample in samples {
            let value = sample.isFinite ? min(1, max(-1, sample)) : 0
            data.appendInteger(Int16(value * 32767))
        }
        return data
    }
}

extension Data {
    fileprivate mutating func appendInteger<Value: FixedWidthInteger>(_ value: Value) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
