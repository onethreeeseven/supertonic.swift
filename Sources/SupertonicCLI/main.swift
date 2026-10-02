import Foundation
import Supertonic

@main
struct SupertonicCommand {
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count >= 2 else {
            print("Usage: supertonic <text> <output.wav> [language=na] [voice=F1] [model-directory]")
            return
        }
        guard let request = SynthesisRequest(arguments: arguments) else {
            print(
                "Unknown language or voice. Languages: \(SynthesisLanguage.allCases.map(\.rawValue).joined(separator: ", "))"
            )
            exit(2)
        }
        let synthesizer = try await Supertonic.load(from: request.modelDirectory)
        let audio = try await synthesizer.synthesize(
            request.text, in: request.language, voice: request.voice)
        try audio.write(to: request.outputURL)
        print("Saved \(arguments[1]): \(audio.duration) seconds, \(audio.sampleRate) Hz")
    }
}

private struct SynthesisRequest {
    let text: String
    let outputURL: URL
    let language: SynthesisLanguage
    let voice: Voice
    let modelDirectory: URL

    init?(arguments: [String]) {
        guard arguments.count >= 2,
            let language = SynthesisLanguage(languageCode: arguments.count > 2 ? arguments[2] : "na"),
            let voice = Voice(rawValue: arguments.count > 3 ? arguments[3] : "F1")
        else { return nil }
        text = arguments[0]
        outputURL = URL(fileURLWithPath: arguments[1])
        self.language = language
        self.voice = voice
        modelDirectory =
            arguments.count > 4 ? URL(fileURLWithPath: arguments[4]) : ModelAssets.defaultDirectory
    }
}
