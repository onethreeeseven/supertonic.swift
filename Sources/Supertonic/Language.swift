import Foundation

public enum SynthesisLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case korean = "ko"
    case japanese = "ja"
    case arabic = "ar"
    case bulgarian = "bg"
    case czech = "cs"
    case danish = "da"
    case german = "de"
    case greek = "el"
    case spanish = "es"
    case estonian = "et"
    case finnish = "fi"
    case french = "fr"
    case hindi = "hi"
    case croatian = "hr"
    case hungarian = "hu"
    case indonesian = "id"
    case italian = "it"
    case lithuanian = "lt"
    case latvian = "lv"
    case dutch = "nl"
    case polish = "pl"
    case portuguese = "pt"
    case romanian = "ro"
    case russian = "ru"
    case slovak = "sk"
    case slovenian = "sl"
    case swedish = "sv"
    case turkish = "tr"
    case ukrainian = "uk"
    case vietnamese = "vi"
    case unspecified = "na"

    public init?(languageCode: String) {
        let primary =
            languageCode.replacingOccurrences(of: "_", with: "-")
            .lowercased().split(separator: "-").first.map(String.init) ?? "na"
        self.init(rawValue: primary)
    }
}

public enum Voice: String, CaseIterable, Codable, Sendable {
    case female1 = "F1"
    case female2 = "F2"
    case female3 = "F3"
    case female4 = "F4"
    case female5 = "F5"
    case male1 = "M1"
    case male2 = "M2"
    case male3 = "M3"
    case male4 = "M4"
    case male5 = "M5"
}

public struct SynthesisOptions: Sendable {
    public enum Quality: Int, Sendable {
        case fast = 4
        case balanced = 8
        case high = 16
    }

    public let quality: Quality
    public let speed: Float
    public let seed: UInt64

    public init(quality: Quality = .balanced, speed: Float = 1.05, seed: UInt64 = .random(in: .min ... .max))
    {
        self.quality = quality
        self.speed = speed.isFinite ? min(2, max(0.5, speed)) : 1.05
        self.seed = seed
    }
}
