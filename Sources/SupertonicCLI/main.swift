import Foundation
import Supertonic

@main
struct SupertonicCommand {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count >= 2 else {
            print("Usage: supertonic <text> <output.wav> [language=na] [voice=F1] [model-directory]")
            return
        }
        guard let language = SynthesisLanguage(languageCode: arguments.count > 2 ? arguments[2] : "na"),
              let voice = Voice(rawValue: arguments.count > 3 ? arguments[3] : "F1") else {
            print("Unknown language or voice. Languages: \(SynthesisLanguage.allCases.map(\.rawValue).joined(separator: ", "))")
            exit(2)
        }
        let directory = arguments.count > 4 ? URL(fileURLWithPath: arguments[4]) : ModelAssets.defaultDirectory
        let synthesizer = try await Supertonic.load(from: directory)
        let audio = try await synthesizer.synthesize(arguments[0], language: language, voice: voice)
        try audio.write(to: URL(fileURLWithPath: arguments[1]))
        print("Saved \(arguments[1]): \(audio.duration) seconds, \(audio.sampleRate) Hz")
    }
}
