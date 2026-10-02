import Foundation

struct TextProcessor {
    let indexer: [Int64]

    func encode(_ text: String, language: SynthesisLanguage) -> [Int64] {
        let normalized = Self.normalize(text)
        let tagged = "<\(language.rawValue)>\(normalized)</\(language.rawValue)>"
        return tagged.unicodeScalars.map {
            let index = Int($0.value)
            return index < indexer.count ? indexer[index] : -1
        }
    }

    static func normalize(_ text: String) -> String {
        var result = text.decomposedStringWithCompatibilityMapping
        result = String(String.UnicodeScalarView(result.unicodeScalars.filter { !isEmoji($0.value) }))
        for (source, replacement) in replacements {
            result = result.replacingOccurrences(of: source, with: replacement)
        }
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        for punctuation in [",", ".", "!", "?", ";", ":", "'"] {
            result = result.replacingOccurrences(of: " " + punctuation, with: punctuation)
        }
        for quote in ["\"", "'"] {
            while result.contains(quote + quote) { result = result.replacingOccurrences(of: quote + quote, with: quote) }
        }
        if let last = result.last, !".!?;:,'\")]}…。」』】〉》›»".contains(last) { result += "." }
        return result
    }

    static func chunks(_ text: String, maximumLength: Int = 120) -> [String] {
        var result: [String] = []
        var chunk = ""
        for character in text {
            chunk.append(character)
            if chunk.count >= maximumLength || ".!?。！？\n".contains(character) {
                append(chunk, to: &result)
                chunk = ""
            }
        }
        append(chunk, to: &result)
        return result
    }

    private static func append(_ text: String, to chunks: inout [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalize(trimmed).isEmpty { chunks.append(trimmed) }
    }

    private static func isEmoji(_ value: UInt32) -> Bool {
        (0x1F300...0x1FAFF).contains(value) || (0x2600...0x27BF).contains(value) || (0x1F1E6...0x1F1FF).contains(value)
    }

    private static let replacements: [(String, String)] = [
        ("–", "-"), ("‑", "-"), ("—", "-"), ("_", " "),
        ("“", "\""), ("”", "\""), ("‘", "'"), ("’", "'"), ("´", "'"), ("`", "'"),
        ("[", " "), ("]", " "), ("|", " "), ("/", " "), ("#", " "), ("→", " "), ("←", " "),
        ("♥", ""), ("☆", ""), ("♡", ""), ("©", ""), ("\\", ""), ("@", " at "),
        ("e.g.,", "for example, "), ("i.e.,", "that is, ")
    ]
}

struct NoiseGenerator {
    var state: UInt64

    mutating func gaussian() -> Float {
        let first = max(Float.leastNonzeroMagnitude, uniform())
        let second = uniform()
        return sqrt(-2 * log(first)) * cos(2 * .pi * second)
    }

    private mutating func uniform() -> Float {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return Float(value >> 40) / Float(1 << 24)
    }
}
