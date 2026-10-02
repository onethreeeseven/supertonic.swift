# supertonic.swift

Supertonic 3 speech synthesis in Swift for macOS, iOS, and Linux. Runs on the CPU, with 31 explicit languages, language-agnostic `na` generation, and ten voices.

## Install

```swift
.package(url: "https://github.com/onethreeeseven/supertonic.swift.git", from: "0.1.0")
```

Add `.product(name: "Supertonic", package: "supertonic.swift")` to your target dependencies.

```swift
import Supertonic

let synthesizer = try await Supertonic.load()
let audio = try await synthesizer.synthesize("안녕하세요.", language: .korean)
try audio.write(to: URL(fileURLWithPath: "hello.wav"))
```

Omitting `language` uses `.unspecified`, the model's `na` mode. This lets the model process text without an explicit language tag; it does not guarantee accurate pronunciation for languages outside its training coverage.

```swift
let audio = try await synthesizer.synthesize(
    "Hello world.",
    voice: .male1,
    options: SynthesisOptions(quality: .high, speed: 1.1, seed: 42)
)
```

Synthesis runs inside an actor so model sessions and voice tensors are reused safely. Calls are serialized. Cancelling the calling task stops work between chunks and denoising steps; an individual ONNX operation finishes before cancellation is checked. Empty text produces empty audio. Speed is bounded to 0.5–2.0; non-finite speed uses 1.05. WAV output is mono, 16-bit PCM at the model's sample rate.

## Models and offline use

`Supertonic.load()` downloads approximately 400 MB of model assets into the user's cache on its first call. Assets come from a fixed Supertonic 3 revision. Downloads check HTTP status and file size, and use staging files before installing each asset. Concurrent requests within a process share one download. Failed downloads can be retried without downloading completed files again.

Set a persistent destination when eviction by the operating system would be inconvenient:

```swift
let synthesizer = try await Supertonic.load(from: modelDirectory)
```

For an application bundle or a fully offline installation, distribute the contents of the model repository's `onnx/` and `voice_styles/` directories, together with its license, then load directly:

```swift
let synthesizer = try Supertonic(assets: ModelAssets(directory: bundledModelDirectory))
```

This initializer performs no network access. The expected directory structure is:

```text
models/
  LICENSE
  onnx/
    tts.json
    unicode_indexer.json
    duration_predictor.onnx
    text_encoder.onnx
    vector_estimator.onnx
    vocoder.onnx
  voice_styles/
    F1.json ... F5.json
    M1.json ... M5.json
```

The pinned model revision is `aafc6e32416a594460b32413efc49d7fe4ce6d46` in [the official model archive](https://huggingface.co/supertone-oss-archive/supertonic-3). Models are downloaded separately to keep weights out of source checkouts. The downloader checks sizes, not cryptographic content hashes.

## Platforms and dependencies

| Platform | Minimum | Runtime delivery |
| --- | --- | --- |
| macOS | 14, Apple Silicon or Intel | Official ONNX Runtime XCFramework, fetched by SwiftPM |
| iOS | 15, device and simulator | Same XCFramework, linked into the application |
| Linux | x86_64 or ARM64, glibc 2.27+ | ONNX Runtime shared library included as a package resource |

There are no Swift package dependencies. The sole inference dependency is ONNX Runtime 1.24.2. Apple builds link its official binary artifact and the system C++/CoreML libraries. Linux builds load the bundled shared library; they require no `apt`, Homebrew, Python, external command, or manually installed ONNX runtime. The Linux binaries are CPU builds and require a glibc distribution. The two Linux architectures add approximately 39 MB to source checkouts and only Linux builds copy them into the resource bundle.

## Languages

`en ko ja ar bg cs da de el es et fi fr hi hr hu id it lt lv nl pl pt ro ru sk sl sv tr uk vi`

Use `SynthesisLanguage(languageCode:)` to parse BCP 47 tags such as `ko-KR` or `en-US`. Unknown codes return `nil`, allowing the caller to choose `.unspecified` explicitly. `Voice.allCases` contains F1–F5 and M1–M5.

## Command line

```sh
swift run supertonic "Hello world." hello.wav en F1
swift run supertonic "안녕하세요." hello.wav na M1 /path/to/models
swift test
SUPERTONIC_TEST_MODELS=/path/to/models swift test
```

The last command enables real-model inference tests in addition to the ordinary unit tests.

## Licenses and sources

Swift code and the inference adaptation are MIT licensed. Text preprocessing and the inference contract follow [Supertone's reference implementation](https://github.com/supertone-oss-archive/supertonic). Its copyright notice is retained in `LICENSE`. ONNX Runtime is MIT licensed; its license and third-party notices are included. Model weights have their separate [OpenRAIL-M license](https://huggingface.co/supertone-oss-archive/supertonic-3/blob/main/LICENSE), downloaded with the assets and included as `MODEL-LICENSE` in this repository.
