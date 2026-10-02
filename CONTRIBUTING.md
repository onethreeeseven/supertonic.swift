# Contributing to Supertonic.swift

Bug reports, documentation fixes, platform improvements, and code contributions are welcome.
For a larger API or dependency change, open an issue before starting implementation so we can agree on the scope.

## Development setup

Use Swift 6.0 or later on macOS or Linux. iOS builds require Xcode and the iOS SDK.
The package includes its ONNX Runtime integration; no separate runtime installation is needed.

```bash
git clone https://github.com/onethreeeseven/supertonic.swift.git
cd supertonic.swift
swift test
```

## Testing with the model

Run a short synthesis to download the pinned model assets, then enable the integration tests:

```bash
swift run supertonic "Hello world." sample.wav en F1 /tmp/supertonic-models
SUPERTONIC_TEST_MODELS=/tmp/supertonic-models swift test
```

These tests exercise all 31 explicit language tags and `na`, and verify download fallback against the preserved model release. Use a fixed seed when comparing generated audio before and after a change.
The first download requires approximately 400 MB of storage and network access.

CI tests macOS and Linux x86_64/ARM64, including model downloads and inference. It also compiles the library for iOS.
To check an iOS build locally:

```bash
swift build --target Supertonic \
  --triple arm64-apple-ios15.0 \
  --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
```

## Code conventions

- Keep functions focused and use descriptive names.
- Prefer immutable values and concrete types. Use reference types for runtime resource ownership.
- Keep mutable synthesis state isolated to the `Supertonic` actor.
- Validate model data and external responses at their boundaries.
- Preserve cancellation and resource cleanup when changing asynchronous code or C interoperability.
- Keep public APIs usable across supported platforms and minimize dependencies.
- Add tests for changed behavior, and update the README when examples or requirements change.

## Issues and pull requests

Use the bug report or feature request form. A useful bug report includes a minimal reproduction, package and Swift versions, platform, architecture, and the exact error message.
For synthesis issues, include a short text sample and the language tag, voice, quality, speed, and seed.

Keep each pull request focused on one problem. Explain the behavior before and after the change, summarize your validation, and identify any compatibility impact.
Use conventional commit prefixes such as `feat:`, `fix:`, `refactor:`, `docs:`, or `chore:`.

## Model assets and redistribution

Model weights are distributed under [OpenRAIL-M](MODEL-LICENSE). Library code is distributed under [MIT](LICENSE); ONNX Runtime has its own [license](ONNX-LICENSE) and [third-party notices](ONNX-ThirdPartyNotices.txt).
Retain these notices when redistributing the relevant components. Model recipients must receive the model license and its use restrictions.

The [preserved model release](https://github.com/onethreeeseven/supertonic.swift/releases/tag/models-supertonic-3-aafc6e32416a) contains unchanged assets from the pinned upstream revision. [Models/supertonic-3.json](Models/supertonic-3.json) records their source paths, sizes, and SHA-256 hashes.

When proposing a model revision update:

1. Identify the upstream revision and review its license and redistribution requirements.
2. Preserve the complete inference assets, all voice styles, the license, and source provenance in a new model release.
3. Verify uploaded files against the original SHA-256 hashes.
4. Update the asset manifest, expected file sizes, source URLs, and documentation together.
5. Run inference for every supported language tag and verify both download sources on supported platforms.

Keep published model release tags and assets unchanged so existing package versions remain reproducible.

## Sponsorship

You can support maintenance, platform testing, and model preservation through [GitHub Sponsors](https://github.com/sponsors/onethreeeseven).
