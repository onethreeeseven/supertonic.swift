import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
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
        #expect(chunks == [text])
    }

    @Test(arguments: ["3.7%", "3,7%", "٣٫٧٪", "1.24.2", "2024", "14:35"])
    func numericExpressionsStayTogether(expression: String) {
        let text = "Value: " + expression + " increased. Next sentence."
        let chunks = TextProcessor.chunks(text)
        #expect(chunks == [text])
    }

    @Test(arguments: ["3.7%", "3,7%", "٣٫٧٪", "1.24.2", "14:35"])
    func lengthLimitDoesNotSplitNumbers(expression: String) {
        let text = "Value: " + expression + " increased."
        for maximumLength in 8...(7 + expression.count) {
            let chunks = TextProcessor.chunks(text, maximumLength: maximumLength)
            #expect(chunks.contains { $0.contains(expression) })
        }
    }

    @Test func shortSentencesShareOneChunk() {
        #expect(TextProcessor.chunks("Hello world. Welcome back!") == ["Hello world. Welcome back!"])
    }

    @Test func sentenceBoundariesArePreferredOverLengthCuts() {
        let text = "First sentence. Second sentence. Third sentence."
        #expect(
            TextProcessor.chunks(text, maximumLength: 34) == [
                "First sentence. Second sentence.", "Third sentence.",
            ])
    }

    @Test func longSentencesSplitOnlyBetweenWholeWords() {
        let text = "Temperature humidity and calibration changed significantly."
        let chunks = TextProcessor.chunks(text, maximumLength: 20)
        #expect(chunks == ["Temperature humidity", "and calibration", "changed", "significantly."])
        #expect(chunks.joined(separator: " ") == text)
    }

    @Test func titlesInitialsAndClosingQuotesStayWithTheirSentences() {
        let text = "Dr. Elena Rossi met J. Smith in the U.S. and said \"It rose 3.7%.\" Next sentence."
        let first = "Dr. Elena Rossi met J. Smith in the U.S. and said \"It rose 3.7%.\""
        #expect(TextProcessor.chunks(text, maximumLength: first.count) == [first, "Next sentence."])
    }

    @Test func sentencesWithoutSpacesKeepTheirPunctuation() {
        #expect(TextProcessor.chunks("こんにちは。ありがとう！", maximumLength: 6) == ["こんにちは。", "ありがとう！"])
        #expect(TextProcessor.chunks("“Hello!” Next.", maximumLength: 8) == ["“Hello!”", "Next."])
    }

    @Test func readmeSamplesUseExactlyOneChunk() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let url = directory.appendingPathComponent("Examples/AudioSamples/passages.json")
        let passages = try JSONDecoder().decode([SamplePassage].self, from: Data(contentsOf: url))
        #expect(passages.count == 32)
        for passage in passages {
            #expect(passage.text.count <= 120)
            let language = try #require(SynthesisLanguage(rawValue: passage.code))
            #expect(
                TextProcessor.chunks(passage.text, maximumLength: language.maximumChunkLength) == [
                    passage.text
                ])
        }
    }

    private struct SamplePassage: Decodable {
        let code: String
        let text: String
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
        let component = VoiceStyle.Component(data: [[[1]]], dimensions: [1, 1, 2])
        #expect(throws: SupertonicError.self) { try component.validate() }
    }

    @Test func modelSourcesPreserveRevisionAndAssetNames() throws {
        let file = ModelFile(path: "onnx/tts.json", size: 8253)
        let upstream = try ModelSource.huggingFace.url(for: file)
        let mirror = try ModelSource.githubRelease.url(for: file)
        #expect(upstream.path.contains("/raw/" + ModelAssets.revision + "/"))
        #expect(mirror.lastPathComponent == "tts.json")
        #expect(mirror.path.contains(ModelSource.preservationTag))
        let names = try ModelFile.all.map { try ModelSource.githubRelease.url(for: $0).lastPathComponent }
        #expect(Set(names).count == ModelFile.all.count)
    }

    @Test(arguments: ["unavailable-model.json", "LICENSE"])
    func unavailableOrInvalidUpstreamFallsBackToPreservedModel(assetName: String) async throws {
        guard let path = ProcessInfo.processInfo.environment["SUPERTONIC_TEST_MODELS"] else { return }
        let file = ModelFile(path: "onnx/tts.json", size: 8253)
        let unavailable = try #require(
            URL(
                string:
                    "https://github.com/onethreeeseven/supertonic.swift/releases/download/\(ModelSource.preservationTag)/\(assetName)"
            ))
        let preserved = try ModelSource.githubRelease.url(for: file)
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let downloaded = try await ModelDownloader.download(
            file, from: [unavailable, preserved][...], session: session)
        defer { try? FileManager.default.removeItem(at: downloaded) }
        let expected = URL(fileURLWithPath: path).appendingPathComponent(file.path)
        #expect(try Data(contentsOf: downloaded) == Data(contentsOf: expected))
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

    @Test func decimalSynthesisMatchesOneContinuousModelInvocation() async throws {
        guard let path = ProcessInfo.processInfo.environment["SUPERTONIC_TEST_MODELS"] else { return }
        let assets = ModelAssets(directory: URL(fileURLWithPath: path))
        let text = "A 3.7% increase does not prove causation."
        let options = SynthesisOptions(quality: .fast, seed: 42)
        let model = try SpeechModel(assets: assets, threads: 2)
        let style = try model.style(for: .female1)
        var generator = NoiseGenerator(state: options.seed)
        let expected = try model.synthesize(
            text, language: .english, style: style, options: options, generator: &generator)
        let synthesizer = try Supertonic(assets: assets)
        let actual = try await synthesizer.synthesize(text, in: .english, options: options)
        #expect(actual.samples == expected)
    }

    @Test func actualInference() async throws {
        guard let path = ProcessInfo.processInfo.environment["SUPERTONIC_TEST_MODELS"] else { return }
        let synthesizer = try Supertonic(assets: ModelAssets(directory: URL(fileURLWithPath: path)))
        for language in SynthesisLanguage.allCases {
            let text = Self.samples[language.rawValue] ?? "Hello world."
            let audio = try await synthesizer.synthesize(
                text, in: language, options: SynthesisOptions(quality: .fast, seed: 42))
            #expect(audio.duration > 0.1 && audio.duration < 20)
            #expect(audio.samples.allSatisfy { $0.isFinite })
            #expect(audio.samples.contains { abs($0) > 0.001 })
        }
    }
}
