import Foundation

struct VoiceTensors {
    let duration: Tensor
    let text: Tensor
}

private struct EncodedText {
    let identifiers: Tensor
    let mask: Tensor
}

private struct NoisyLatent {
    let tensor: Tensor
    let length: Int
    let sampleCount: Int
}

final class SpeechModel {
    private let runtime: Runtime
    private let configuration: ModelConfiguration
    private let processor: TextProcessor
    private let assets: ModelAssets
    private let durationPredictor: Session
    private let textEncoder: Session
    private let vectorEstimator: Session
    private let vocoder: Session
    private var styles: [Voice: VoiceTensors] = [:]

    var sampleRate: Int { configuration.audioEncoder.sampleRate }

    init(assets: ModelAssets, threads: Int = 2) throws {
        self.assets = assets
        let configuration = try Self.loadConfiguration(from: assets)
        self.configuration = configuration
        processor = try Self.loadProcessor(from: assets)
        let runtime = try Runtime()
        self.runtime = runtime
        let threads = min(32, max(1, threads))
        durationPredictor = try Self.loadSession(
            "duration_predictor", assets: assets, runtime: runtime, threads: threads)
        textEncoder = try Self.loadSession("text_encoder", assets: assets, runtime: runtime, threads: threads)
        vectorEstimator = try Self.loadSession(
            "vector_estimator", assets: assets, runtime: runtime, threads: threads)
        vocoder = try Self.loadSession("vocoder", assets: assets, runtime: runtime, threads: threads)
    }

    private static func loadConfiguration(from assets: ModelAssets) throws -> ModelConfiguration {
        let configuration = try decode(
            ModelConfiguration.self, from: assets.directory.appendingPathComponent("onnx/tts.json"))
        try configuration.validate()
        return configuration
    }

    private static func loadProcessor(from assets: ModelAssets) throws -> TextProcessor {
        let indexer = try decode(
            [Int64].self, from: assets.directory.appendingPathComponent("onnx/unicode_indexer.json"))
        guard !indexer.isEmpty, indexer.allSatisfy({ $0 >= -1 }) else {
            throw SupertonicError.invalidModel("Unicode indexer is empty or contains invalid token IDs")
        }
        return TextProcessor(indexer: indexer)
    }

    private static func loadSession(_ name: String, assets: ModelAssets, runtime: Runtime, threads: Int)
        throws -> Session
    {
        let path = assets.directory.appendingPathComponent("onnx/\(name).onnx")
        return try Session(path, runtime: runtime, threads: threads)
    }

    func style(for voice: Voice) throws -> VoiceTensors {
        if let style = styles[voice] { return style }
        let data = try decode(
            VoiceStyle.self,
            from: assets.directory.appendingPathComponent("voice_styles/\(voice.rawValue).json"))
        let style = try VoiceTensors(
            duration: data.durationStyle.tensor(runtime: runtime),
            text: data.textStyle.tensor(runtime: runtime))
        styles[voice] = style
        return style
    }

    func synthesize(
        _ text: String,
        language: SynthesisLanguage,
        style: VoiceTensors,
        options: SynthesisOptions,
        generator: inout NoiseGenerator
    ) throws -> [Float] {
        let text = try encode(text, language: language)
        let duration = try predictDuration(text: text, style: style.duration, speed: options.speed)
        let embedding = try textEncoder.run(
            [
                ("text_ids", text.identifiers), ("style_ttl", style.text), ("text_mask", text.mask),
            ], output: "text_emb")
        let noise = try createNoise(duration: duration, generator: &generator)
        let latent = try denoise(
            noise, embedding: embedding, mask: text.mask,
            style: style.text, steps: options.quality.rawValue
        )
        return try decodeAudio(latent, sampleCount: noise.sampleCount)
    }

    private func encode(_ text: String, language: SynthesisLanguage) throws -> EncodedText {
        let tokens = processor.encode(text, language: language)
        let length = Int64(tokens.count)
        let identifiers = try Tensor(tokens, shape: [1, length], runtime: runtime)
        let mask = try Tensor(
            Array(repeating: Float(1), count: tokens.count), shape: [1, 1, length], runtime: runtime)
        return EncodedText(identifiers: identifiers, mask: mask)
    }

    private func predictDuration(text: EncodedText, style: Tensor, speed: Float) throws -> Float {
        let output = try durationPredictor.run(
            [("text_ids", text.identifiers), ("style_dp", style), ("text_mask", text.mask)],
            output: "duration"
        ).floats()
        guard output.count == 1, let predictedDuration = output.first else {
            throw SupertonicError.invalidModel("Duration predictor did not return one duration")
        }
        let duration = predictedDuration / speed
        guard duration.isFinite, duration > 0, duration <= 60 else {
            throw SupertonicError.invalidModel("Predicted chunk duration is outside 0...60 seconds")
        }
        return duration
    }

    private func createNoise(duration: Float, generator: inout NoiseGenerator) throws -> NoisyLatent {
        let sampleCount = Int(duration * Float(sampleRate))
        let length = (sampleCount + configuration.chunkSize - 1) / configuration.chunkSize
        let shape: [Int64] = [1, Int64(configuration.channels), Int64(length)]
        let values = (0..<(configuration.channels * length)).map { _ in generator.gaussian() }
        let tensor = try Tensor(values, shape: shape, runtime: runtime)
        return NoisyLatent(tensor: tensor, length: length, sampleCount: sampleCount)
    }

    private func denoise(_ noise: NoisyLatent, embedding: Tensor, mask: Tensor, style: Tensor, steps: Int)
        throws -> Tensor
    {
        let latentMask = try Tensor(
            Array(repeating: Float(1), count: noise.length), shape: [1, 1, Int64(noise.length)],
            runtime: runtime)
        let totalSteps = try Tensor([Float(steps)], shape: [1], runtime: runtime)
        var latent = noise.tensor
        for step in 0..<steps {
            try Task.checkCancellation()
            let currentStep = try Tensor([Float(step)], shape: [1], runtime: runtime)
            latent = try vectorEstimator.run(
                [
                    ("noisy_latent", latent), ("text_emb", embedding), ("style_ttl", style),
                    ("latent_mask", latentMask), ("text_mask", mask), ("current_step", currentStep),
                    ("total_step", totalSteps),
                ], output: "denoised_latent")
        }
        return latent
    }

    private func decodeAudio(_ latent: Tensor, sampleCount: Int) throws -> [Float] {
        let waveform = try vocoder.run([("latent", latent)], output: "wav_tts").floats()
        guard waveform.count >= sampleCount, waveform.allSatisfy(\.isFinite) else {
            throw SupertonicError.invalidModel("Vocoder produced invalid audio")
        }
        return Array(waveform.prefix(sampleCount))
    }
}
