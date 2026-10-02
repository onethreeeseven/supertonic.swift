import Foundation
import Testing
@testable import Supertonic

struct SupertonicTests {
    @Test func languagesInclude31ExplicitCodesAndUnspecified() {
        #expect(SynthesisLanguage.allCases.count == 32)
        #expect(SynthesisLanguage(languageCode: "KO_kr") == .korean)
        #expect(SynthesisLanguage(languageCode: "en-US") == .english)
        #expect(SynthesisLanguage(languageCode: "na") == .unspecified)
        #expect(SynthesisLanguage(languageCode: "") == .unspecified)
        #expect(SynthesisLanguage(languageCode: "xx") == nil)
    }

    @Test func textIsNormalizedAndTaggedUsingUnicodeScalars() {
        let indexer = (0...65535).map(Int64.init)
        let processor = TextProcessor(indexer: indexer)
        let expected = "<ko>\("한글".decomposedStringWithCompatibilityMapping).</ko>"
        #expect(processor.encode("한글", language: .korean) == expected.unicodeScalars.map { Int64($0.value) })
        #expect(TextProcessor.normalize("  “Hello” 😊\nworld  ") == "\"Hello\" world.")
        #expect(TextProcessor.chunks(" \n😊 ").isEmpty)
    }

    @Test func longUnspacedTextIsNeverDropped() {
        let text = String(repeating: "水", count: 1000)
        let chunks = TextProcessor.chunks(text)
        #expect(chunks.joined() == text)
        #expect(chunks.allSatisfy { $0.count <= 120 })
    }

    @Test func noiseIsDeterministicAndFinite() {
        var first = NoiseGenerator(state: 42)
        var second = NoiseGenerator(state: 42)
        let values = (0..<10000).map { _ in first.gaussian() }
        #expect(values == (0..<10000).map { _ in second.gaussian() })
        #expect(values.allSatisfy { $0.isFinite })
        #expect(abs(values.reduce(0, +) / Float(values.count)) < 0.05)
    }

    @Test func wavHasCorrectHeaderAndClampsInvalidSamples() {
        let audio = Audio(samples: [-2, 0, 2, .nan], sampleRate: 24000)
        let data = audio.wavData
        #expect(data.count == 52)
        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "RIFF")
        #expect(String(decoding: data[8..<12], as: UTF8.self) == "WAVE")
        #expect(Array(data.suffix(8)) == [1, 128, 0, 0, 255, 127, 0, 0])
    }

    @Test func malformedVoiceDimensionsAreRejectedBeforeCallingRuntime() throws {
        let runtime = try Runtime()
        let component = VoiceStyle.Component(data: [[[1]]], dimensions: [1, 1, 2])
        #expect(throws: SupertonicError.self) { try component.tensor(runtime: runtime) }
    }

    private static let samples = [
        "en": "Hello world.", "ko": "안녕하세요.", "ja": "こんにちは。", "ar": "مرحبا بالعالم.",
        "bg": "Здравей свят.", "cs": "Ahoj světe.", "da": "Hej verden.", "de": "Hallo Welt.",
        "el": "Γεια σου κόσμε.", "es": "Hola mundo.", "et": "Tere maailm.", "fi": "Hei maailma.",
        "fr": "Bonjour le monde.", "hi": "नमस्ते दुनिया।", "hr": "Pozdrav svijete.", "hu": "Helló világ.",
        "id": "Halo dunia.", "it": "Ciao mondo.", "lt": "Labas pasauli.", "lv": "Sveika pasaule.",
        "nl": "Hallo wereld.", "pl": "Witaj świecie.", "pt": "Olá mundo.", "ro": "Salut lume.",
        "ru": "Привет мир.", "sk": "Ahoj svet.", "sl": "Pozdravljen svet.", "sv": "Hej världen.",
        "tr": "Merhaba dünya.", "uk": "Привіт світ.", "vi": "Xin chào thế giới.", "na": "안녕하세요.",
    ]

    @Test func actualInference() async throws {
        guard let path = ProcessInfo.processInfo.environment["SUPERTONIC_TEST_MODELS"] else { return }
        let synthesizer = try Supertonic(assets: ModelAssets(directory: URL(fileURLWithPath: path)))
        for language in SynthesisLanguage.allCases {
            let text = Self.samples[language.rawValue] ?? "Hello world."
            let audio = try await synthesizer.synthesize(
                text, language: language, options: SynthesisOptions(quality: .fast, seed: 42))
            #expect(audio.duration > 0.1 && audio.duration < 20)
            #expect(audio.samples.allSatisfy { $0.isFinite })
            #expect(audio.samples.contains { abs($0) > 0.001 })
        }
    }
}
