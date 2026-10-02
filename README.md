# supertonic.swift

[![CI](https://github.com/onethreeeseven/supertonic.swift/actions/workflows/swift.yml/badge.svg?branch=main)](https://github.com/onethreeeseven/supertonic.swift/actions/workflows/swift.yml) [![Release](https://img.shields.io/github/v/release/onethreeeseven/supertonic.swift)](https://github.com/onethreeeseven/supertonic.swift/releases/latest) [![Swift 6.0+](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white)](Package.swift) [![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Linux-454545)](#platforms) [![Code license: MIT](https://img.shields.io/badge/code_license-MIT-blue)](LICENSE)

Run [Supertonic 3](https://huggingface.co/supertone-oss-archive/supertonic-3) text-to-speech directly in Swift. Generate speech locally on macOS, iOS, and Linux with 31 languages, ten voices, and language-agnostic `na` mode.

- CPU inference with audio returned as Float32 samples or a ready-to-save WAV.
- Zero Swift package dependencies. ONNX Runtime is included through a binary artifact on Apple platforms and bundled libraries on Linux.
- Automatic model download and caching, plus direct loading of bundled models for fully offline apps.
- An actor-based API that reuses model sessions and serializes synthesis safely.

The first `Supertonic.load()` downloads approximately 400 MB of model assets. Subsequent loads reuse the cache. Speech synthesis runs on the device; text stays local.

## Quick start

Requires Swift 6.0 or later. Add the package and its library product to `Package.swift`:

```swift
.package(
    url: "https://github.com/onethreeeseven/supertonic.swift.git",
    from: "0.1.1"
)
```

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "Supertonic", package: "supertonic.swift")
    ]
)
```

Then generate a WAV:

```swift
import Foundation
import Supertonic

let synthesizer = try await Supertonic.load()
let audio = try await synthesizer.synthesize(
    "Hello world.",
    language: .english
)

try audio.write(to: URL(fileURLWithPath: "hello.wav"))
```

Keep the synthesizer around for later requests. `audio.samples`, `audio.sampleRate`, and `audio.duration` are available for custom playback or processing. WAV output is mono, 16-bit PCM at the model's sample rate, 44,100 Hz.

## Languages and `na` mode

Use an explicit language when you know it:

```swift
let audio = try await synthesizer.synthesize(
    "안녕하세요.",
    language: .korean
)
```

Omitting the language uses `.unspecified`, which sends the model's `na` tag:

```swift
let audio = try await synthesizer.synthesize("안녕하세요. Hello world.")
```

`na` lets the model process text without an explicit language selection. Pronunciation quality outside its training coverage is not guaranteed.

Parse a BCP 47 code and choose a fallback explicitly:

```swift
let language = SynthesisLanguage(languageCode: "ko-KR") ?? .unspecified
let audio = try await synthesizer.synthesize("안녕하세요.", language: language)
```

Unknown codes return `nil`. Empty codes and `na` resolve to `.unspecified`.

| Code | Language | Code | Language |
| --- | --- | --- | --- |
| `en` | English | `ko` | Korean |
| `ja` | Japanese | `ar` | Arabic |
| `bg` | Bulgarian | `cs` | Czech |
| `da` | Danish | `de` | German |
| `el` | Greek | `es` | Spanish |
| `et` | Estonian | `fi` | Finnish |
| `fr` | French | `hi` | Hindi |
| `hr` | Croatian | `hu` | Hungarian |
| `id` | Indonesian | `it` | Italian |
| `lt` | Lithuanian | `lv` | Latvian |
| `nl` | Dutch | `pl` | Polish |
| `pt` | Portuguese | `ro` | Romanian |
| `ru` | Russian | `sk` | Slovak |
| `sl` | Slovenian | `sv` | Swedish |
| `tr` | Turkish | `uk` | Ukrainian |
| `vi` | Vietnamese | | |

## Voices and generation controls

Choose from `.female1` through `.female5` or `.male1` through `.male5`. These correspond to the model's F1–F5 and M1–M5 voice styles; `Voice.allCases` lists all ten. The default is `.female1`.

```swift
let audio = try await synthesizer.synthesize(
    "Welcome back.",
    language: .english,
    voice: .male1,
    options: SynthesisOptions(
        quality: .high,
        speed: 1.1,
        seed: 42
    )
)
```

| Option | Default | Behavior |
| --- | --- | --- |
| `quality` | `.balanced` | `.fast`: 4 denoising steps; `.balanced`: 8; `.high`: 16 |
| `speed` | `1.05` | Higher values speak faster; bounded to 0.5–2.0 |
| `seed` | Random | A fixed seed reproduces the initial noise for repeatable generation |

Non-finite speeds use the default. Empty text produces empty audio. Long text is split into chunks with silence between them. Cancelling the calling task stops synthesis between chunks and denoising steps; an individual ONNX operation finishes before cancellation is checked.

## Model downloads and offline apps

Choose a persistent model directory when your app should retain downloaded assets outside the operating system's cache:

```swift
let synthesizer = try await Supertonic.load(from: modelDirectory)
```

You can also download assets ahead of the first speech request:

```swift
let assets = try await ModelAssets.download(to: modelDirectory)
let synthesizer = try Supertonic(assets: assets)
```

For an app bundle or an installation with no network access, distribute the model's `onnx/` and `voice_styles/` directories together with its license. Load those files directly:

```swift
let assets = ModelAssets(directory: bundledModelDirectory)
let synthesizer = try Supertonic(assets: assets)
```

This initializer performs no network access. The directory should contain:

```text
models/
├── LICENSE
├── onnx/
│   ├── tts.json
│   ├── unicode_indexer.json
│   ├── duration_predictor.onnx
│   ├── text_encoder.onnx
│   ├── vector_estimator.onnx
│   └── vocoder.onnx
└── voice_styles/
    ├── F1.json … F5.json
    └── M1.json … M5.json
```

Downloads use revision [`aafc6e32416a594460b32413efc49d7fe4ce6d46`](https://huggingface.co/supertone-oss-archive/supertonic-3/tree/aafc6e32416a594460b32413efc49d7fe4ce6d46). Concurrent requests within one process share a download, and retries reuse completed files. Each file is staged before installation. Validation checks HTTP status and expected file size; it does not verify cryptographic content hashes.

## Platforms

| Platform | Minimum | ONNX Runtime delivery |
| --- | --- | --- |
| macOS | 14; Apple Silicon or Intel | Official XCFramework fetched by SwiftPM |
| iOS | 15; device and simulator | Official XCFramework linked into the app |
| Linux | x86_64 or ARM64; glibc 2.27+ | Shared libraries included as package resources |

The inference runtime is ONNX Runtime 1.24.2. Apple builds link the system C++ and CoreML libraries. Linux builds load the bundled CPU runtime and require a glibc distribution. Both Linux architectures together add approximately 39 MB to a source checkout; Apple builds exclude those resources.

Using the package requires no Python environment, package manager setup, or separately installed ONNX Runtime. Model weights are distributed separately from the source repository.

## Command line

From a checkout of this repository:

```sh
swift run supertonic "Hello world." hello.wav en F1
swift run supertonic "안녕하세요." hello.wav na M1 /path/to/models
```

```text
supertonic <text> <output.wav> [language=na] [voice=F1] [model-directory]
```

## Verification

```sh
swift test
SUPERTONIC_TEST_MODELS=/path/to/models swift test
```

The model-enabled tests synthesize speech for every language tag, including `na`, and check for finite, non-silent audio. [CI](https://github.com/onethreeeseven/supertonic.swift/actions/workflows/swift.yml) runs unit tests, first-download generation, and model-enabled tests on macOS and Linux x86_64/ARM64. It also compiles the library for an iOS device target.

## Licenses and acknowledgments

| Component | License |
| --- | --- |
| Swift code and inference adaptation | [MIT](LICENSE) |
| ONNX Runtime | [MIT](ONNX-LICENSE), with [third-party notices](ONNX-ThirdPartyNotices.txt) |
| Supertonic 3 model weights | [OpenRAIL-M](MODEL-LICENSE) |

Text preprocessing and the inference contract follow [Supertone's reference implementation](https://github.com/supertone-oss-archive/supertonic). Its copyright notice is retained. The model license is included in this repository and downloaded with the model assets.
