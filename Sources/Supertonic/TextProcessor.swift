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
        let decomposed = text.decomposedStringWithCompatibilityMapping
        let scalars = decomposed.unicodeScalars.filter { !isEmoji($0.value) }
        let withoutEmoji = String(String.UnicodeScalarView(scalars))
        let replaced = replaceSymbols(in: withoutEmoji)
        let spaced = normalizeSpacing(in: replaced)
        let quoted = collapseRepeatedQuotes(in: spaced)
        guard let last = quoted.last, !".!?;:,'\")]}…。」』】〉》›»".contains(last) else { return quoted }
        return quoted + "."
    }

    private static func replaceSymbols(in text: String) -> String {
        replacements.reduce(text) { result, replacement in
            result.replacingOccurrences(of: replacement.source, with: replacement.value)
        }
    }

    private static func normalizeSpacing(in text: String) -> String {
        let spaced = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return [",", ".", "!", "?", ";", ":", "'"].reduce(spaced) { result, punctuation in
            result.replacingOccurrences(of: " " + punctuation, with: punctuation)
        }
    }

    private static func collapseRepeatedQuotes(in text: String) -> String {
        var result = text
        for quote in ["\"", "'"] {
            while result.contains(quote + quote) {
                result = result.replacingOccurrences(of: quote + quote, with: quote)
            }
        }
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
        (0x1F300...0x1FAFF).contains(value) || (0x2600...0x27BF).contains(value)
            || (0x1F1E6...0x1F1FF).contains(value)
    }

    private static let replacements: [(source: String, value: String)] = [
        ("–", "-"), ("‑", "-"), ("—", "-"), ("_", " "),
        ("“", "\""), ("”", "\""), ("‘", "'"), ("’", "'"), ("´", "'"), ("`", "'"),
        ("[", " "), ("]", " "), ("|", " "), ("/", " "), ("#", " "), ("→", " "), ("←", " "),
        ("♥", ""), ("☆", ""), ("♡", ""), ("©", ""), ("\\", ""), ("@", " at "),
        ("e.g.,", "for example, "), ("i.e.,", "that is, "),
    ]
}
