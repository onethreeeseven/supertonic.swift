import Foundation

public actor Supertonic {
    private let model: SpeechModel
    private let playback = AudioPlayback()

    public init(assets: ModelAssets, threads: Int = 2) throws {
        model = try SpeechModel(assets: assets, threads: threads)
    }

    public static func load(from directory: URL = ModelAssets.defaultDirectory, threads: Int = 2) async throws
        -> Supertonic
    {
        let assets = try await ModelAssets.download(to: directory)
        return try Supertonic(assets: assets, threads: threads)
    }

    public func speak(
        _ text: String,
        in language: SynthesisLanguage,
        voice: Voice = .female1,
        options: SynthesisOptions = SynthesisOptions()
    ) async throws {
        let audio = try synthesize(text, in: language, voice: voice, options: options)
        try Task.checkCancellation()
        try await playback.play(audio)
    }

    public func stop() async {
        await playback.stop()
    }

    public func synthesize(
        _ text: String,
        in language: SynthesisLanguage,
        voice: Voice = .female1,
        options: SynthesisOptions = SynthesisOptions()
    ) throws -> Audio {
        let chunks = TextProcessor.chunks(text, maximumLength: language.maximumChunkLength)
        guard !chunks.isEmpty else { return Audio(samples: [], sampleRate: model.sampleRate) }
        let style = try model.style(for: voice)
        var generator = NoiseGenerator(state: options.seed)
        var samples: [Float] = []
        for chunk in chunks {
            try Task.checkCancellation()
            if !samples.isEmpty {
                samples.append(contentsOf: repeatElement(0, count: model.sampleRate * 3 / 10))
            }
            samples.append(
                contentsOf: try model.synthesize(
                    chunk, language: language, style: style, options: options, generator: &generator))
        }
        return Audio(samples: samples, sampleRate: model.sampleRate)
    }
}
