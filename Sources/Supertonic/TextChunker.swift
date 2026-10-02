import Foundation

struct TextChunker {
    static func chunks(_ text: String, maximumLength: Int) -> [String] {
        var result: [String] = []
        var current = ""
        for sentence in sentences(in: text) {
            if sentence.count > maximumLength {
                append(current, to: &result)
                current = ""
                result.append(contentsOf: wordChunks(sentence, maximumLength: maximumLength))
            } else if current.isEmpty {
                current = sentence
            } else if current.count + sentence.count + 1 <= maximumLength {
                current += " " + sentence
            } else {
                append(current, to: &result)
                current = sentence
            }
        }
        append(current, to: &result)
        return result
    }

    private static func sentences(in text: String) -> [String] {
        let characters = Array(text)
        var result: [String] = []
        var sentence = ""
        for (index, character) in characters.enumerated() {
            sentence.append(character)
            if endsSentence(characters, at: index) {
                append(sentence, to: &result)
                sentence = ""
            }
        }
        append(sentence, to: &result)
        return result
    }

    private static func endsSentence(_ characters: [Character], at index: Int) -> Bool {
        if index + 1 < characters.count && closingQuotes.contains(characters[index + 1]) { return false }
        var terminalIndex = index
        while terminalIndex > 0 && closingQuotes.contains(characters[terminalIndex]) { terminalIndex -= 1 }
        let terminal = characters[terminalIndex]
        guard ".!?。！？।".contains(terminal) else { return false }
        if terminal == "." && isAbbreviation(characters, endingAt: terminalIndex) { return false }
        if index + 1 == characters.count { return true }
        if "。！？।".contains(terminal) { return true }
        return characters[index + 1].isWhitespace
    }

    private static func isAbbreviation(_ characters: [Character], endingAt index: Int) -> Bool {
        let token = String(characters[...index].reversed().prefix { !$0.isWhitespace }.reversed())
        if abbreviations.contains(token.lowercased()) { return true }
        let initials = token.split(separator: ".")
        return !initials.isEmpty && initials.allSatisfy { $0.count == 1 && $0.first?.isUppercase == true }
    }

    private static func wordChunks(_ sentence: String, maximumLength: Int) -> [String] {
        var result: [String] = []
        var current = ""
        for word in sentence.split(whereSeparator: \.isWhitespace) {
            if !current.isEmpty && current.count + word.count + 1 > maximumLength {
                append(current, to: &result)
                current = ""
            }
            current += (current.isEmpty ? "" : " ") + word
        }
        append(current, to: &result)
        return result
    }

    private static func append(_ text: String, to chunks: inout [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { chunks.append(trimmed) }
    }

    private static let closingQuotes = "\"'”’»)]}」』】〉》"
    private static let abbreviations: Set<String> = [
        "mr.", "mrs.", "ms.", "dr.", "prof.", "sr.", "jr.", "ph.d.", "etc.", "e.g.", "i.e.",
        "vs.", "inc.", "ltd.", "co.", "corp.", "st.", "ave.", "blvd.",
    ]
}
