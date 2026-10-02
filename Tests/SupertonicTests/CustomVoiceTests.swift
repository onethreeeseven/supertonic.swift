import Foundation
import Testing

@testable import Supertonic

struct CustomVoiceTests {
    @Test func voiceLoadsFromDataWithoutARequestedName() throws {
        let voice = try CustomVoice(data: VoiceDocument().jsonData())
        #expect(voice.style.textStyle.dimensions == [1, 50, 256])
        #expect(voice.style.durationStyle.dimensions == [1, 8, 16])
    }

    @Test func loadedVoiceSurvivesRemovalOfItsSourceFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        try VoiceDocument().jsonData().write(to: url)
        let voice = try CustomVoice(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        try voice.style.validate()
        #expect(voice.style.textStyle.data[0][0][0] == 0)
    }

    @Test func incompatibleTensorShapesAreRejectedWhenLoading() throws {
        var document = VoiceDocument()
        document.textStyle = Component(rows: 49, columns: 256)
        let data = try document.jsonData()
        #expect(throws: SupertonicError.self) { try CustomVoice(data: data) }
    }

    @Test func raggedDataWithTheRightTotalCountIsRejectedWhenLoading() throws {
        var document = VoiceDocument()
        document.textStyle.data[0][0].removeLast()
        document.textStyle.data[0][1].append(0)
        let data = try document.jsonData()
        #expect(throws: SupertonicError.self) { try CustomVoice(data: data) }
    }

    @Test func incompleteJSONIsRejectedWhenLoading() {
        #expect(throws: DecodingError.self) { try CustomVoice(data: Data("{}".utf8)) }
    }

    @Test func nonFiniteVoiceFeaturesAreRejected() {
        let component = VoiceStyle.Component(data: [[[.infinity]]], dimensions: [1, 1, 1])
        #expect(throws: SupertonicError.self) { try component.validate() }
    }

    @Test func importedProfilesMatchPresetsAndSupportBothSpeechMethods() async throws {
        guard let path = ProcessInfo.processInfo.environment["SUPERTONIC_TEST_MODELS"] else { return }
        let directory = URL(fileURLWithPath: path)
        let synthesizer = try Supertonic(assets: ModelAssets(directory: directory))
        let options = SynthesisOptions(quality: .fast, seed: 42)
        for preset in [Voice.female1, .male5] {
            let url = directory.appendingPathComponent("voice_styles/\(preset.rawValue).json")
            let voice = try CustomVoice(contentsOf: url)
            for language in [SynthesisLanguage.korean, .english] {
                let text = language == .korean ? "안녕하세요." : "Welcome back."
                let expected = try await synthesizer.synthesize(
                    text, in: language, with: preset, options: options)
                let actual = try await synthesizer.synthesize(
                    text, in: language, with: voice, options: options)
                #expect(actual.samples == expected.samples)
                #expect(actual.samples.contains { abs($0) > 0.001 })
            }
            try await synthesizer.speak("", in: .korean, with: voice)
        }
    }

    private struct VoiceDocument: Encodable {
        var textStyle = Component(rows: 50, columns: 256)
        var durationStyle = Component(rows: 8, columns: 16)

        enum CodingKeys: String, CodingKey {
            case textStyle = "style_ttl"
            case durationStyle = "style_dp"
        }

        func jsonData() throws -> Data {
            try JSONEncoder().encode(self)
        }
    }

    private struct Component: Encodable {
        var data: [[[Float]]]
        let dimensions: [Int]

        enum CodingKeys: String, CodingKey {
            case data
            case dimensions = "dims"
        }

        init(rows: Int, columns: Int) {
            data = [Array(repeating: Array(repeating: 0, count: columns), count: rows)]
            dimensions = [1, rows, columns]
        }
    }
}
