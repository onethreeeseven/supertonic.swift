import Foundation

public actor Supertonic {
    private let runtime: Runtime
    private let configuration: ModelConfiguration
    private let processor: TextProcessor
    private let assets: ModelAssets
    private let durationPredictor: Session
    private let textEncoder: Session
    private let vectorEstimator: Session
    private let vocoder: Session
    private var styles: [Voice: (duration: Tensor, text: Tensor)] = [:]

    public init(assets: ModelAssets, threads: Int = 2) throws {
        self.assets = assets
        let configuration = try decode(ModelConfiguration.self, from: assets.directory.appendingPathComponent("onnx/tts.json"))
        try configuration.validate()
        self.configuration = configuration
        let indexer = try decode([Int64].self, from: assets.directory.appendingPathComponent("onnx/unicode_indexer.json"))
        guard !indexer.isEmpty, indexer.allSatisfy({ $0 >= -1 }) else {
            throw SupertonicError.invalidModel("Unicode indexer is empty or contains invalid token IDs")
        }
        processor = TextProcessor(indexer: indexer)
        let runtime = try Runtime()
        self.runtime = runtime
        let threads = min(32, max(1, threads))
        durationPredictor = try Session(assets.directory.appendingPathComponent("onnx/duration_predictor.onnx"), runtime: runtime, threads: threads)
        textEncoder = try Session(assets.directory.appendingPathComponent("onnx/text_encoder.onnx"), runtime: runtime, threads: threads)
        vectorEstimator = try Session(assets.directory.appendingPathComponent("onnx/vector_estimator.onnx"), runtime: runtime, threads: threads)
        vocoder = try Session(assets.directory.appendingPathComponent("onnx/vocoder.onnx"), runtime: runtime, threads: threads)
    }

    public static func load(from directory: URL = ModelAssets.defaultDirectory, threads: Int = 2) async throws -> Supertonic {
        let assets = try await ModelAssets.download(to: directory)
        return try Supertonic(assets: assets, threads: threads)
    }

    public func synthesize(
        _ text: String,
        language: SynthesisLanguage = .unspecified,
        voice: Voice = .female1,
        options: SynthesisOptions = SynthesisOptions()
    ) throws -> Audio {
        let chunks = TextProcessor.chunks(text)
        guard !chunks.isEmpty else { return Audio(samples: [], sampleRate: configuration.audioEncoder.sampleRate) }
        let style = try style(for: voice)
        var generator = NoiseGenerator(state: options.seed)
        var samples: [Float] = []
        for chunk in chunks {
            try Task.checkCancellation()
            if !samples.isEmpty { samples.append(contentsOf: repeatElement(0, count: configuration.audioEncoder.sampleRate * 3 / 10)) }
            samples.append(contentsOf: try infer(chunk, language: language, style: style, options: options, generator: &generator))
        }
        return Audio(samples: samples, sampleRate: configuration.audioEncoder.sampleRate)
    }

    private func style(for voice: Voice) throws -> (duration: Tensor, text: Tensor) {
        if let style = styles[voice] { return style }
        let data = try decode(VoiceStyle.self, from: assets.directory.appendingPathComponent("voice_styles/\(voice.rawValue).json"))
        let style = try (duration: data.durationStyle.tensor(runtime: runtime), text: data.textStyle.tensor(runtime: runtime))
        styles[voice] = style
        return style
    }

    private func infer(_ text: String, language: SynthesisLanguage, style: (duration: Tensor, text: Tensor), options: SynthesisOptions, generator: inout NoiseGenerator) throws -> [Float] {
        let tokens = processor.encode(text, language: language)
        let identifiers = try Tensor(tokens, shape: [1, Int64(tokens.count)], runtime: runtime)
        let mask = try Tensor(Array(repeating: Float(1), count: tokens.count), shape: [1, 1, Int64(tokens.count)], runtime: runtime)
        let duration = try predictDuration(identifiers: identifiers, mask: mask, style: style.duration, speed: options.speed)
        let embedding = try textEncoder.run([("text_ids", identifiers), ("style_ttl", style.text), ("text_mask", mask)], output: "text_emb")
        let sampleCount = Int(duration * Float(configuration.audioEncoder.sampleRate))
        let latentLength = (sampleCount + configuration.chunkSize - 1) / configuration.chunkSize
        let shape: [Int64] = [1, Int64(configuration.channels), Int64(latentLength)]
        let noise = (0..<(configuration.channels * latentLength)).map { _ in generator.gaussian() }
        let latent = try Tensor(noise, shape: shape, runtime: runtime)
        let denoised = try denoise(latent, embedding: embedding, mask: mask, style: style.text, length: latentLength, steps: options.quality.rawValue)
        let waveform = try vocoder.run([("latent", denoised)], output: "wav_tts").floats()
        guard waveform.count >= sampleCount, waveform.allSatisfy(\.isFinite) else {
            throw SupertonicError.invalidModel("Vocoder produced invalid audio")
        }
        return Array(waveform.prefix(sampleCount))
    }

    private func predictDuration(identifiers: Tensor, mask: Tensor, style: Tensor, speed: Float) throws -> Float {
        let output = try durationPredictor.run([("text_ids", identifiers), ("style_dp", style), ("text_mask", mask)], output: "duration").floats()
        guard output.count == 1, let predicted = output.first else {
            throw SupertonicError.invalidModel("Duration predictor did not return one duration")
        }
        let duration = predicted / speed
        guard duration.isFinite, duration > 0, duration <= 60 else {
            throw SupertonicError.invalidModel("Predicted chunk duration is outside 0...60 seconds")
        }
        return duration
    }

    private func denoise(_ initial: Tensor, embedding: Tensor, mask: Tensor, style: Tensor, length: Int, steps: Int) throws -> Tensor {
        let latentMask = try Tensor(Array(repeating: Float(1), count: length), shape: [1, 1, Int64(length)], runtime: runtime)
        let total = try Tensor([Float(steps)], shape: [1], runtime: runtime)
        var latent = initial
        for step in 0..<steps {
            try Task.checkCancellation()
            let current = try Tensor([Float(step)], shape: [1], runtime: runtime)
            latent = try vectorEstimator.run([
                ("noisy_latent", latent), ("text_emb", embedding), ("style_ttl", style),
                ("latent_mask", latentMask), ("text_mask", mask), ("current_step", current), ("total_step", total)
            ], output: "denoised_latent")
        }
        return latent
    }
}
