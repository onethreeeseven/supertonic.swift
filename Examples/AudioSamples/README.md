# Audio samples

Generate the README samples with the library itself:

```sh
swift run --package-path Examples/AudioSamples -c release GenerateSamples \
  /path/to/models Examples/AudioSamples/passages.json /tmp/supertonic-audio "Your CPU"
```

The generator uses F1, high quality (16 steps), speed 1.05, seed 42, and two inference threads. It warms the model before recording, writes one WAV per language and `na`, and compares explicit language tags with `na` for English, Korean, and Japanese over three repetitions. `samples.json` records the exact input, generation times, durations, peak amplitudes, and waveforms. Timings exclude model loading and WAV encoding.

The supplied sentences test times, percentages, names, technical vocabulary, and punctuation. The library tests verify that every exact input fits in one chunk; each recording uses one model invocation without concatenation or inserted inter-chunk silence. They are demonstration inputs, not a validated pronunciation benchmark.

For GitHub's inline attachment player, encode each WAV as an audio-only MP4 and upload it as a GitHub media attachment. FFmpeg is only a sample publishing tool; the Swift library does not depend on it.

```sh
ffmpeg -i ko.wav -vn -c:a aac -b:a 160k -movflags +faststart ko.mp4
```

The [sample release](https://github.com/onethreeeseven/supertonic.swift/releases/tag/audio-samples-0.2.2) preserves original WAVs, encoded attachments, the inputs, measurements, and SHA-256 checksums. Nothing in the generated audio is edited after synthesis; the MP4 copies apply lossy AAC encoding.

`attachments.json` maps each recording to its permanent GitHub media URL. The README embeds these URLs as standalone paragraphs, which GitHub renders as players.
