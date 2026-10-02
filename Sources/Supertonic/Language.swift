import Foundation

public enum SynthesisLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en", korean = "ko", japanese = "ja", arabic = "ar"
    case bulgarian = "bg", czech = "cs", danish = "da", german = "de"
    case greek = "el", spanish = "es", estonian = "et", finnish = "fi"
    case french = "fr", hindi = "hi", croatian = "hr", hungarian = "hu"
    case indonesian = "id", italian = "it", lithuanian = "lt", latvian = "lv"
    case dutch = "nl", polish = "pl", portuguese = "pt", romanian = "ro"
    case russian = "ru", slovak = "sk", slovenian = "sl", swedish = "sv"
    case turkish = "tr", ukrainian = "uk", vietnamese = "vi"
    case unspecified = "na"

    public init?(languageCode: String) {
        let primary = languageCode.replacingOccurrences(of: "_", with: "-")
            .lowercased().split(separator: "-").first.map(String.init) ?? "na"
        self.init(rawValue: primary)
    }
}

public enum Voice: String, CaseIterable, Codable, Sendable {
    case female1 = "F1", female2 = "F2", female3 = "F3", female4 = "F4", female5 = "F5"
    case male1 = "M1", male2 = "M2", male3 = "M3", male4 = "M4", male5 = "M5"
}

public struct SynthesisOptions: Sendable {
    public enum Quality: Int, Sendable {
        case fast = 4, balanced = 8, high = 16
    }

    public let quality: Quality
    public let speed: Float
    public let seed: UInt64

    public init(quality: Quality = .balanced, speed: Float = 1.05, seed: UInt64 = .random(in: .min ... .max)) {
        self.quality = quality
        self.speed = speed.isFinite ? min(2, max(0.5, speed)) : 1.05
        self.seed = seed
    }
}
