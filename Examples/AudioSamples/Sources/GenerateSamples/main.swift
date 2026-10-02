import Foundation
import Supertonic

struct Passage: Codable {
    let code: String
    let name: String
    let nativeName: String
    let text: String
}

struct Recording: Encodable {
    let passage: Passage
    let duration: Double
    let generationSeconds: Double
    let peakAmplitude: Float
    let waveform: [Float]
}

struct Comparison: Encodable {
    let code: String
    let tag: String
    let generationSeconds: [Double]
    let audioSeconds: Double
}

struct Collection: Encodable {
    let libraryVersion = "0.2.2"
    let modelRevision = ModelAssets.revision
    let voice = "F1"
    let steps = 16
    let speed: Float = 1.05
    let seed: UInt64 = 42
    let threads = 2
    let device: String
    let recordings: [Recording]
    let comparisons: [Comparison]
}

@main
struct GenerateSamples {
    static let options = SynthesisOptions(quality: .high, speed: 1.05, seed: 42)

    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 4 else {
            print("Usage: GenerateSamples <models> <passages.json> <output-directory> <device-description>")
            return
        }
        let assets = ModelAssets(directory: URL(fileURLWithPath: arguments[0]))
        let passages = try JSONDecoder().decode(
            [Passage].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))
        let output = URL(fileURLWithPath: arguments[2])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let synthesizer = try Supertonic(assets: assets, threads: 2)
        _ = try await synthesizer.synthesize("Warm up the model.", in: .english, options: options)
        let recordings = try await record(passages, with: synthesizer, to: output)
        let comparisons = try await compareLanguages(passages, with: synthesizer, to: output)
        let collection = Collection(device: arguments[3], recordings: recordings, comparisons: comparisons)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(collection).write(
            to: output.appendingPathComponent("samples.json"), options: .atomic)
    }

    static func record(_ passages: [Passage], with synthesizer: Supertonic, to output: URL) async throws
        -> [Recording]
    {
        var recordings: [Recording] = []
        for passage in passages {
            guard let language = SynthesisLanguage(rawValue: passage.code) else {
                throw SupertonicError.invalidModel("Unknown sample language: \(passage.code)")
            }
            let start = Date()
            let audio = try await synthesizer.synthesize(passage.text, in: language, options: options)
            let elapsed = Date().timeIntervalSince(start)
            try audio.write(to: output.appendingPathComponent(passage.code + ".wav"))
            recordings.append(
                Recording(
                    passage: passage, duration: audio.duration, generationSeconds: elapsed,
                    peakAmplitude: audio.samples.map(abs).max() ?? 0, waveform: waveform(audio.samples)))
            report(
                "\(passage.code): \(String(format: "%.1f", audio.duration))s audio, \(String(format: "%.2f", elapsed))s generation"
            )
        }
        return recordings
    }

    static func compareLanguages(_ passages: [Passage], with synthesizer: Supertonic, to output: URL)
        async throws -> [Comparison]
    {
        var comparisons: [Comparison] = []
        for passage in passages where ["en", "ko", "ja"].contains(passage.code) {
            guard let language = SynthesisLanguage(rawValue: passage.code) else { continue }
            for tag in [language, .unspecified] {
                var timings: [Double] = []
                var duration: Double = 0
                for iteration in 0..<3 {
                    let start = Date()
                    let audio = try await synthesizer.synthesize(passage.text, in: tag, options: options)
                    timings.append(Date().timeIntervalSince(start))
                    duration = audio.duration
                    if iteration == 0 && tag == .unspecified {
                        try audio.write(to: output.appendingPathComponent(passage.code + "-na.wav"))
                    }
                }
                comparisons.append(
                    Comparison(
                        code: passage.code, tag: tag.rawValue, generationSeconds: timings,
                        audioSeconds: duration))
                report("Compared \(passage.code) with tag \(tag.rawValue)")
            }
        }
        return comparisons
    }

    static func waveform(_ samples: [Float]) -> [Float] {
        let width = 96
        let step = max(1, samples.count / width)
        return (0..<width).map { index in
            let start = min(samples.count, index * step)
            let end = min(samples.count, start + step)
            return samples[start..<end].map(abs).max() ?? 0
        }
    }

    static func report(_ message: String) {
        FileHandle.standardOutput.write(Data((message + "\n").utf8))
    }
}
