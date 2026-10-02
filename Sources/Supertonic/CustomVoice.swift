import Foundation

public struct CustomVoice: Sendable {
    let style: VoiceStyle

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    public init(data: Data) throws {
        let style = try decode(VoiceStyle.self, from: data)
        try style.validate()
        self.style = style
    }
}
