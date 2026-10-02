import Foundation

struct ModelFile: Sendable {
    let path: String
    let size: Int

    static let all: [ModelFile] = [
        ModelFile(path: "LICENSE", size: 15007),
        ModelFile(path: "onnx/duration_predictor.onnx", size: 3700147),
        ModelFile(path: "onnx/text_encoder.onnx", size: 36416150),
        ModelFile(path: "onnx/tts.json", size: 8253),
        ModelFile(path: "onnx/unicode_indexer.json", size: 277676),
        ModelFile(path: "onnx/vector_estimator.onnx", size: 256534781),
        ModelFile(path: "onnx/vocoder.onnx", size: 101424195),
        ModelFile(path: "voice_styles/F1.json", size: 292046),
        ModelFile(path: "voice_styles/F2.json", size: 292423),
        ModelFile(path: "voice_styles/F3.json", size: 290794),
        ModelFile(path: "voice_styles/F4.json", size: 291808),
        ModelFile(path: "voice_styles/F5.json", size: 291479),
        ModelFile(path: "voice_styles/M1.json", size: 291748),
        ModelFile(path: "voice_styles/M2.json", size: 292055),
        ModelFile(path: "voice_styles/M3.json", size: 290198),
        ModelFile(path: "voice_styles/M4.json", size: 291522),
        ModelFile(path: "voice_styles/M5.json", size: 291469),
    ]
}
