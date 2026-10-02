import Foundation
import Testing
@testable import Supertonic

struct PlaybackTests {
    @Test func emptyAudioDoesNotOpenAnOutputDevice() async throws {
        let playback = AudioPlayback()
        try await playback.play(Audio(samples: [], sampleRate: 44100))
        #expect(await playback.isPlaying == false)
    }

    @Test func cancellationBeforePlaybackDoesNotRetainAudio() async throws {
        let playback = AudioPlayback()
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            try await playback.play(Audio(samples: [0], sampleRate: 44100))
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await playback.isPlaying == false)
    }

    @Test func playbackCompletesAndReleasesItsDevice() async throws {
        guard ProcessInfo.processInfo.environment["SUPERTONIC_TEST_PLAYBACK"] == "1" else { return }
        #if os(Linux)
            let playback = AudioPlayback(deviceName: "null")
        #else
            let playback = AudioPlayback()
        #endif
        try await playback.play(Audio(samples: Array(repeating: 0, count: 4410), sampleRate: 44100))
        #expect(await playback.isPlaying == false)
    }

    @Test func stoppingPlaybackReleasesItsDevice() async throws {
        guard ProcessInfo.processInfo.environment["SUPERTONIC_TEST_PLAYBACK"] == "1" else { return }
        #if os(Linux)
            let playback = AudioPlayback(deviceName: "null")
        #else
            let playback = AudioPlayback()
        #endif
        let task = Task {
            try await playback.play(Audio(samples: Array(repeating: 0, count: 441000), sampleRate: 44100))
        }
        let deadline = ContinuousClock.now + .seconds(2)
        while await !playback.isPlaying && ContinuousClock.now < deadline { await Task.yield() }
        guard await playback.isPlaying else {
            task.cancel()
            _ = try? await task.value
            Issue.record("Playback did not become observable before the deadline")
            return
        }
        await playback.stop()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await playback.isPlaying == false)
    }
}
