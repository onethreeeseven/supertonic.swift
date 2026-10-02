# Audio samples

Generate the README samples with the library itself:

```sh
swift run --package-path Examples/AudioSamples -c release GenerateSamples \
  /path/to/models Examples/AudioSamples/passages.json /tmp/supertonic-audio "Your CPU"
```

The generator uses F1, high quality (16 steps), speed 1.05, seed 42, and two inference threads. It warms the model before recording, writes one WAV per language and `na`, and compares explicit language tags with `na` for English, Korean, and Japanese over three repetitions. `samples.json` records the exact input, generation times, durations, peak amplitudes, and waveforms. Timings exclude model loading and WAV encoding.

The passages test dates, times, decimals, names, technical vocabulary, punctuation, and sentence transitions. They are demonstration inputs, not a validated pronunciation benchmark.

For GitHub's inline attachment player, encode each WAV as an audio-only MP4 and upload it through the Markdown editor. FFmpeg is only a sample publishing tool; the Swift library does not depend on it.

```sh
ffmpeg -i ko.wav -vn -c:a aac -b:a 160k -movflags +faststart ko.mp4
```

The [sample release](https://github.com/onethreeeseven/supertonic.swift/releases/tag/audio-samples-0.2.0) preserves original WAVs, encoded attachments, the inputs, measurements, and SHA-256 checksums. Nothing in the generated audio is edited after synthesis; the MP4 copies apply lossy AAC encoding.
