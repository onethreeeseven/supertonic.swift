# supertonic.swift

[![CI](https://github.com/onethreeeseven/supertonic.swift/actions/workflows/swift.yml/badge.svg?branch=main)](https://github.com/onethreeeseven/supertonic.swift/actions/workflows/swift.yml) [![Release](https://img.shields.io/github/v/release/onethreeeseven/supertonic.swift)](https://github.com/onethreeeseven/supertonic.swift/releases/latest) [![Swift 6.0+](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white)](Package.swift) [![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Android%20%7C%20Linux-454545)](#platforms) [![Code license: MIT](https://img.shields.io/badge/code_license-MIT-blue)](LICENSE)

Run [Supertonic 3](https://huggingface.co/supertone-oss-archive/supertonic-3) text-to-speech directly in Swift. Generate speech locally on macOS, iOS, Android, and Linux with 31 languages, ten voices, and language-agnostic `na` mode.

- CPU inference with audio returned as Float32 samples or a ready-to-save WAV.
- Zero Swift package dependencies. ONNX Runtime is included through a binary artifact on Apple platforms and bundled libraries on Linux.
- Automatic model download and caching, plus direct loading of bundled models for fully offline apps.
- An actor-based API that reuses model sessions and serializes synthesis safely.

[Listen to the language samples](#audio-samples).

The first `Supertonic.load()` downloads approximately 400 MB of model assets. Subsequent loads reuse the cache. Speech synthesis runs on the device; text stays local.

Apps can download the voices before the first playback and display byte progress:

```swift
let assets = try await ModelAssets.download { progress in
    print("\(progress.downloadedBytes) / \(progress.totalBytes) bytes")
}
let synthesizer = try Supertonic(assets: assets)
```

Cancel the calling task to stop the download. Completed files are retained and reused on retry; an interrupted file is downloaded again. `ModelAssets.totalDownloadBytes`, `assets.downloadedBytes`, and `assets.isComplete` let an app check the download size and local availability without making network requests. The progress callback can run off the main actor; dispatch UI updates to the main actor.


## Quick start

Requires Swift 6.0 or later. Add the package and its library product to `Package.swift`:

```swift
.package(
    url: "https://github.com/onethreeeseven/supertonic.swift.git",
    from: "0.6.1"
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

Speak without saving an audio file:

```swift
import Supertonic

let synthesizer = try await Supertonic.load()
try await synthesizer.speak("안녕하세요.", in: .korean)
```

`speak` synthesizes in memory, waits until playback finishes, and releases the audio. It accepts the same language, voice, and options as `synthesize`. A new playback on the same synthesizer replaces the previous one. Use `await synthesizer.stop()` to stop playback, or cancel the calling task to interrupt synthesis and playback. Playback interruption throws `CancellationError`.

On iOS, configure your app's `AVAudioSession` for its intended playback behavior. On Linux, playback uses the system ALSA library (`libasound.so.2`) and its default output device; synthesis itself does not require ALSA.

To save a WAV:

```swift
import Foundation
import Supertonic

let synthesizer = try await Supertonic.load()
let audio = try await synthesizer.synthesize(
    "Hello world.",
    in: .english
)

try audio.write(to: URL(fileURLWithPath: "hello.wav"))
```

Keep the synthesizer around for later requests. `audio.samples`, `audio.sampleRate`, and `audio.duration` are available for custom playback or processing. WAV output is mono, 16-bit PCM at the model's sample rate, 44,100 Hz.

## Audio samples

Each recording below is synthesized in one continuous model invocation. The supplied sentences fit in one chunk, as checked by the library's tests, so these samples contain no concatenation or inserted inter-chunk silence. Names, time notation, percentages, technical vocabulary, and punctuation test the model's pronunciation. Model output is used without pronunciation repairs.

The inline players use audio-only MP4 files with AAC audio. [Download the MP4 samples and original WAV files](https://github.com/onethreeeseven/supertonic.swift/releases/tag/audio-samples-0.2.2), or [reproduce the samples and inspect measurements](Examples/AudioSamples). All samples use F1, high quality (16 steps), speed 1.05, and seed 42. Expand a transcript to read the exact input. If playback starts muted, use the player's speaker control.

#### English · `en` · 10.7 seconds

https://github.com/user-attachments/assets/22257150-e5fa-41c5-af8a-b78fad63ebf5

<details>
<summary>Transcript</summary>

At 14:35, Elena Rossi said a 3.7% rise in Zürich's 2025 humidity readings does not prove causation.

</details>

#### Korean · 한국어 · `ko` · 12.8 seconds

https://github.com/user-attachments/assets/a7176eef-c74f-44eb-8a17-c0b9a17ebcb1

<details>
<summary>Transcript</summary>

14시 35분, 엘레나 로시 박사는 취리히의 2025년 습도 측정값이 3.7% 올랐지만 인과관계가 입증된 것은 아니라고 설명했습니다.

</details>

#### Japanese · 日本語 · `ja` · 12.6 seconds

https://github.com/user-attachments/assets/4a21ded7-4d1e-49fc-94a6-29152e8e2266

<details>
<summary>Transcript</summary>

14時35分、エレナ・ロッシ博士は、チューリヒの2025年の湿度が3.7％上昇しても因果関係の証明にはならないと説明しました。

</details>

#### Arabic · العربية · `ar` · 13.5 seconds

https://github.com/user-attachments/assets/a7898563-11ec-46d4-85da-4d97656068be

<details>
<summary>Transcript</summary>

عند الساعة 14:35، أوضحت إلينا روسي أن ارتفاع الرطوبة بنسبة 3.7% في زيورخ عام 2025 لا يثبت علاقة سببية.

</details>

#### Bulgarian · Български · `bg` · 13.4 seconds

https://github.com/user-attachments/assets/fa2e2c85-aa02-4cf5-8515-ff930ef4548a

<details>
<summary>Transcript</summary>

В 14:35 Елена Роси каза, че ръстът на влажността с 3,7% в Цюрих през 2025 година не доказва причинност.

</details>

#### Czech · Čeština · `cs` · 13.6 seconds

https://github.com/user-attachments/assets/997fd621-7a5e-4172-aa1c-791d3690ad01

<details>
<summary>Transcript</summary>

Ve 14:35 Elena Rossi uvedla, že růst vlhkosti o 3,7% v Curychu v roce 2025 neprokazuje příčinnou souvislost.

</details>

#### Danish · Dansk · `da` · 11.9 seconds

https://github.com/user-attachments/assets/08a7713c-b974-4670-b286-e6e70040090e

<details>
<summary>Transcript</summary>

Klokken 14:35 sagde Elena Rossi, at 3,7% højere luftfugtighed i Zürich i 2025 ikke beviser årsagssammenhæng.

</details>

#### German · Deutsch · `de` · 11.9 seconds

https://github.com/user-attachments/assets/ba29e717-e2d5-4a7e-9a3f-272eec248814

<details>
<summary>Transcript</summary>

Um 14:35 erklärte Elena Rossi, dass 3,7% mehr Feuchtigkeit in Zürich im Jahr 2025 keine Kausalität beweisen.

</details>

#### Greek · Ελληνικά · `el` · 12.4 seconds

https://github.com/user-attachments/assets/f3521dd1-fd52-4827-8883-cbd91f4439dc

<details>
<summary>Transcript</summary>

Στις 14:35 η Έλενα Ρόσι είπε ότι η αύξηση υγρασίας κατά 3,7% στη Ζυρίχη το 2025 δεν αποδεικνύει αιτιότητα.

</details>

#### Spanish · Español · `es` · 10.5 seconds

https://github.com/user-attachments/assets/c02fe26d-415f-42e8-8b00-2e6ac315ae70

<details>
<summary>Transcript</summary>

A las 14:35, Elena Rossi dijo que un aumento del 3,7% de humedad en Zúrich en 2025 no prueba causalidad.

</details>

#### Estonian · Eesti · `et` · 13.9 seconds

https://github.com/user-attachments/assets/538a91e6-e380-4bc3-b646-f356d8243faf

<details>
<summary>Transcript</summary>

Kell 14:35 ütles Elena Rossi, et Zürichi niiskuse 3,7% kasv aastal 2025 ei tõesta põhjuslikku seost.

</details>

#### Finnish · Suomi · `fi` · 12.8 seconds

https://github.com/user-attachments/assets/78a34ef8-0e52-419c-808c-6a80ccbd394d

<details>
<summary>Transcript</summary>

Kello 14:35 Elena Rossi sanoi, ettei Zürichin kosteuden 3,7% nousu vuonna 2025 todista syy-yhteyttä.

</details>

#### French · Français · `fr` · 11.0 seconds

https://github.com/user-attachments/assets/82e62537-2fbc-4b23-b2fc-c9fb64af31a2

<details>
<summary>Transcript</summary>

À 14:35, Elena Rossi a expliqué qu'une hausse de 3,7% de l'humidité à Zurich en 2025 ne prouve aucune causalité.

</details>

#### Hindi · हिन्दी · `hi` · 11.8 seconds

https://github.com/user-attachments/assets/e4c6b8f3-adc6-4b40-a0cb-46138767f534

<details>
<summary>Transcript</summary>

14:35 बजे एलेना रोसी ने कहा कि ज़्यूरिख में 2025 में नमी की 3.7% वृद्धि कारण और परिणाम का संबंध सिद्ध नहीं करती।

</details>

#### Croatian · Hrvatski · `hr` · 12.2 seconds

https://github.com/user-attachments/assets/13de8def-6e17-4fc4-a238-a0ac6ebe8296

<details>
<summary>Transcript</summary>

U 14:35 Elena Rossi rekla je da porast vlage od 3,7% u Zürichu ne dokazuje uzročno-posljedičnu vezu.

</details>

#### Hungarian · Magyar · `hu` · 13.9 seconds

https://github.com/user-attachments/assets/bce4c07b-f78e-4363-9e64-688a4c6984b3

<details>
<summary>Transcript</summary>

14:35-kor Elena Rossi szerint a zürichi páratartalom 2025-ös, 3,7%-os emelkedése nem bizonyít oksági kapcsolatot.

</details>

#### Indonesian · Bahasa Indonesia · `id` · 11.9 seconds

https://github.com/user-attachments/assets/8a32865e-3cd8-40a0-88fe-79fac3e72177

<details>
<summary>Transcript</summary>

Pukul 14:35, Elena Rossi mengatakan kenaikan kelembapan 3,7% di Zürich pada 2025 tidak membuktikan sebab akibat.

</details>

#### Italian · Italiano · `it` · 12.8 seconds

https://github.com/user-attachments/assets/fa7b4f6a-6194-411e-a205-8390c52cbdef

<details>
<summary>Transcript</summary>

Alle 14:35, Elena Rossi ha spiegato che l'aumento del 3,7% di umidità a Zurigo nel 2025 non prova causalità.

</details>

#### Lithuanian · Lietuvių · `lt` · 14.4 seconds

https://github.com/user-attachments/assets/35bacd4f-0331-4c17-82ee-5b7250514c51

<details>
<summary>Transcript</summary>

14:35 Elena Rossi sakė, kad drėgmės padidėjimas 3,7% Ciuriche 2025 metais neįrodo priežastinio ryšio.

</details>

#### Latvian · Latviešu · `lv` · 11.3 seconds

https://github.com/user-attachments/assets/a302379f-bae4-4f3e-9f5b-12eaa91bceed

<details>
<summary>Transcript</summary>

Pulksten 14:35 Elena Rosi sacīja, ka mitruma pieaugums par 3,7% Cīrihē nepierāda cēloņsakarību.

</details>

#### Dutch · Nederlands · `nl` · 12.0 seconds

https://github.com/user-attachments/assets/58973779-38d7-4e11-8120-8b2d26b0f635

<details>
<summary>Transcript</summary>

Om 14:35 zei Elena Rossi dat 3,7% meer luchtvochtigheid in Zürich in 2025 geen oorzakelijk verband bewijst.

</details>

#### Polish · Polski · `pl` · 12.2 seconds

https://github.com/user-attachments/assets/75c127ce-1181-4e3c-9ed3-c9d884275c98

<details>
<summary>Transcript</summary>

O 14:35 Elena Rossi powiedziała, że wzrost wilgotności o 3,7% w Zurychu w 2025 roku nie dowodzi przyczynowości.

</details>

#### Portuguese · Português · `pt` · 11.6 seconds

https://github.com/user-attachments/assets/d0c69fdd-1d03-4820-b25a-027a8f10fd04

<details>
<summary>Transcript</summary>

Às 14:35, Elena Rossi disse que o aumento de 3,7% da humidade em Zurique em 2025 não prova causalidade.

</details>

#### Romanian · Română · `ro` · 13.1 seconds

https://github.com/user-attachments/assets/5659cf0a-2b70-4c57-9629-ec31ff9cd06d

<details>
<summary>Transcript</summary>

La 14:35, Elena Rossi a spus că o creștere a umidității cu 3,7% la Zürich în 2025 nu dovedește cauzalitate.

</details>

#### Russian · Русский · `ru` · 11.4 seconds

https://github.com/user-attachments/assets/66f98de8-9ea4-4832-9dce-ad8a935305b2

<details>
<summary>Transcript</summary>

В 14:35 Елена Росси сказала, что рост влажности на 3,7% в Цюрихе за 2025 год не доказывает причинность.

</details>

#### Slovak · Slovenčina · `sk` · 13.8 seconds

https://github.com/user-attachments/assets/97435d1f-75d4-4626-9780-eced2a4fe695

<details>
<summary>Transcript</summary>

O 14:35 Elena Rossi povedala, že nárast vlhkosti o 3,7% v Zürichu v roku 2025 nedokazuje príčinnú súvislosť.

</details>

#### Slovenian · Slovenščina · `sl` · 13.1 seconds

https://github.com/user-attachments/assets/3bc3aa29-6571-43ce-9a46-1f86904dde34

<details>
<summary>Transcript</summary>

Ob 14:35 je Elena Rossi dejala, da 3,7% več vlage v Zürichu leta 2025 ne dokazuje vzročne povezave.

</details>

#### Swedish · Svenska · `sv` · 12.9 seconds

https://github.com/user-attachments/assets/0260d9b5-89fb-40d3-bde3-618ff1f3c23d

<details>
<summary>Transcript</summary>

Klockan 14:35 sade Elena Rossi att 3,7% högre luftfuktighet i Zürich år 2025 inte bevisar ett orsakssamband.

</details>

#### Turkish · Türkçe · `tr` · 11.2 seconds

https://github.com/user-attachments/assets/2482b497-3d9d-4731-b657-b6e380a04fb5

<details>
<summary>Transcript</summary>

Saat 14:35'te Elena Rossi, Zürih'te 2025 yılında nemin %3,7 artmasının nedenselliği kanıtlamadığını söyledi.

</details>

#### Ukrainian · Українська · `uk` · 12.1 seconds

https://github.com/user-attachments/assets/c0d5fa1d-5d08-4237-8d01-249a37a85b7b

<details>
<summary>Transcript</summary>

О 14:35 Елена Россі сказала, що зростання вологості на 3,7% у Цюриху за 2025 рік не доводить причинності.

</details>

#### Vietnamese · Tiếng Việt · `vi` · 12.4 seconds

https://github.com/user-attachments/assets/9de300fa-11d6-49ff-8fa6-137d92d65346

<details>
<summary>Transcript</summary>

Lúc 14:35, Elena Rossi nói độ ẩm tăng 3,7% ở Zürich năm 2025 không chứng minh quan hệ nhân quả.

</details>

#### Language-agnostic · 한국어 + English · `na` · 13.3 seconds

https://github.com/user-attachments/assets/cfd7be5a-9c3f-40b8-b152-13413fa81c1b

<details>
<summary>Transcript</summary>

14시 35분, 엘레나 로시 박사는 취리히의 습도가 3.7% 올랐다고 설명하며, a rise in humidity does not prove causation이라고 덧붙였습니다.

</details>

### Explicit language versus `na`

The same single-chunk English, Korean, and Japanese sentences were generated with an explicit tag and with `na`. Each generation time is the median of three runs on an Apple M4 Pro CPU with two inference threads after model warmup, excluding model loading and file encoding. These timings measure generation speed; listen to the recordings to compare pronunciation.

| Input | Explicit tag: generation / audio | `na`: generation / audio |
| --- | --- | --- |
| English | 3.30s / 10.71s | 3.57s / 11.58s |
| Korean | 3.89s / 12.78s | 3.97s / 13.14s |
| Japanese | 4.04s / 12.63s | 3.63s / 12.06s |

#### English with `na`

https://github.com/user-attachments/assets/4cf9963d-51c9-4615-959e-87f27eaab710

<details>
<summary>Transcript</summary>

At 14:35, Elena Rossi said a 3.7% rise in Zürich's 2025 humidity readings does not prove causation.

</details>

#### Korean with `na`

https://github.com/user-attachments/assets/caab1ada-65d0-459c-a7a4-7729002e0ea5

<details>
<summary>Transcript</summary>

14시 35분, 엘레나 로시 박사는 취리히의 2025년 습도 측정값이 3.7% 올랐지만 인과관계가 입증된 것은 아니라고 설명했습니다.

</details>

#### Japanese with `na`

https://github.com/user-attachments/assets/4ad4af58-2d9b-4be1-9d32-0173f3fcda5a

<details>
<summary>Transcript</summary>

14時35分、エレナ・ロッシ博士は、チューリヒの2025年の湿度が3.7％上昇しても因果関係の証明にはならないと説明しました。

</details>

## Languages and `na` mode

Use an explicit language when you know it:

```swift
let audio = try await synthesizer.synthesize(
    "안녕하세요.",
    in: .korean
)
```

The language argument is required. When the language is unknown, pass `.unspecified` explicitly to send the model's `na` tag:

```swift
let audio = try await synthesizer.synthesize("안녕하세요. Hello world.", in: .unspecified)
```

`na` lets the model process text without an explicit language selection. Pronunciation quality outside its training coverage is not guaranteed.

Parse a BCP 47 code and choose a fallback explicitly:

```swift
let language = SynthesisLanguage(languageCode: "ko-KR") ?? .unspecified
let audio = try await synthesizer.synthesize("안녕하세요.", in: language)
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
    in: .english,
    with: .male1,
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

Non-finite speeds use the default. Empty text produces empty audio. Long text is grouped at sentence boundaries, with Korean and Japanese targeting 120 characters and other language tags targeting 300, as in the reference implementation. Sentences exceeding that target are split at whitespace; words, numbers, and unspaced runs stay intact. Separate chunks have a 0.3-second gap. Cancelling the calling task stops synthesis between chunks and denoising steps; an individual ONNX operation finishes before cancellation is checked.

### Custom voices

Load a Supertonic 3 voice-style JSON once, then pass the voice to either `speak` or `synthesize`:

```swift
let voice = try CustomVoice(contentsOf: voiceURL)
try await synthesizer.speak("안녕하세요.", in: .korean, with: voice)
let audio = try await synthesizer.synthesize("Welcome back.", in: .english, with: voice)
```

Use `CustomVoice(data: jsonData)` for data from a download or app resource. The initializer validates the tensor shapes, nested data, and finite values. The loaded voice owns its data, so the source file can be removed after loading. No extra model or dependency is needed.

Use a JSON exported for Supertonic 3, or one of its bundled `voice_styles/*.json` files. The JSON contains numeric voice features; it does not accept a recording or a natural-language voice description. Importing a profile enables local synthesis with that voice; creating a profile from a recording requires a separate voice-cloning pipeline.

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

Downloads first use Hugging Face and automatically fall back to our [preserved model release](https://github.com/onethreeeseven/supertonic.swift/releases/tag/models-supertonic-3-aafc6e32416a) on network errors, unavailable files, or invalid download sizes. Both sources contain revision [`aafc6e32416a594460b32413efc49d7fe4ce6d46`](https://huggingface.co/supertone-oss-archive/supertonic-3/tree/aafc6e32416a594460b32413efc49d7fe4ce6d46). The preserved release includes the original license, a [source manifest](Models/supertonic-3.json), SHA-256 checksums, and `supertonic-3-aafc6e32416a.tar.gz` for offline installation. Extract the archive and pass its `models/` directory to `ModelAssets(directory:)`.

Concurrent requests within one process share a download, and retries reuse completed files. Each file is staged before installation. Validation checks HTTP status and expected file size; it does not verify cryptographic content hashes.

## Platforms

| Platform | Minimum | ONNX Runtime delivery |
| --- | --- | --- |
| macOS | 14; Apple Silicon or Intel | Official XCFramework fetched by SwiftPM |
| iOS | 15; device and simulator | Official XCFramework linked into the app |
| Linux | x86_64 or ARM64; glibc 2.27+ | Shared libraries included as package resources |
| Android | API 28+ with the Swift Android SDK | Official ONNX Runtime Android AAR packaged in the app |

The inference runtime is ONNX Runtime 1.24.2. Apple builds link the system C++ and CoreML libraries. Linux builds load the bundled CPU runtime and require a glibc distribution. Both Linux architectures together add approximately 39 MB to a source checkout; Apple builds exclude those resources.

On Apple platforms and Linux, using the package requires no Python environment or separately installed ONNX Runtime. Model weights are distributed separately from the source repository.

### Android apps

Add the library to your Swift Android target and package ONNX Runtime in your Android app:

```kotlin
dependencies {
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.24.2")
}
```

The AAR supplies `libonnxruntime.so` for the device ABI. The Swift library loads it from the app's native library search path. `speak` uses Android's AAudio output directly and releases its audio stream when playback finishes or is cancelled. Synthesis and playback use the same Swift API as Apple platforms and Linux.

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

## Contributing and support

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, and pull request guidelines. Use the [issue forms](https://github.com/onethreeeseven/supertonic.swift/issues/new/choose) to report a bug or propose a feature.

Support maintenance, platform testing, and model preservation through [GitHub Sponsors](https://github.com/sponsors/onethreeeseven).

## Licenses and acknowledgments

| Component | License |
| --- | --- |
| Swift code and inference adaptation | [MIT](LICENSE) |
| ONNX Runtime | [MIT](ONNX-LICENSE), with [third-party notices](ONNX-ThirdPartyNotices.txt) |
| Supertonic 3 model weights | [OpenRAIL-M](MODEL-LICENSE) |

Text preprocessing and the inference contract follow [Supertone's reference implementation](https://github.com/supertone-oss-archive/supertonic). Its copyright notice is retained. The model license is included in this repository and downloaded with the model assets.
