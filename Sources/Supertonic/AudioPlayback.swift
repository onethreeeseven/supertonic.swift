import Foundation

#if canImport(AVFoundation)
    import AVFoundation

    @MainActor
    final class AudioPlayback {
        private var player: AVAudioPlayer?

        nonisolated init() {}

        var isPlaying: Bool { player != nil }

        func play(_ audio: Audio) async throws {
            try Task.checkCancellation()
            stop()
            guard !audio.samples.isEmpty else { return }
            let player = try AVAudioPlayer(data: audio.wavData)
            self.player = player
            defer {
                player.stop()
                if self.player === player { self.player = nil }
            }
            guard player.play() else { throw SupertonicError.playback("Audio output could not start") }
            while true {
                try Task.checkCancellation()
                guard self.player === player else { throw CancellationError() }
                guard player.isPlaying else { return }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
        }

        func stop() {
            player?.stop()
            player = nil
        }
    }
#elseif os(Linux)
    import CSupertonic

    actor AudioPlayback {
        private let deviceName: String
        private var device: PlaybackDevice?

        init(deviceName: String = "default") { self.deviceName = deviceName }

        var isPlaying: Bool { device != nil }

        func play(_ audio: Audio) async throws {
            try Task.checkCancellation()
            stop()
            guard !audio.samples.isEmpty else { return }
            let device = try PlaybackDevice(name: deviceName, sampleRate: audio.sampleRate)
            self.device = device
            defer {
                device.stop()
                if self.device === device { self.device = nil }
            }
            let samples = audio.samples.map { $0.isFinite ? min(1, max(-1, $0)) : 0 }
            var offset = 0
            while offset < samples.count {
                try Task.checkCancellation()
                guard self.device === device else { throw CancellationError() }
                offset += try device.write(samples, from: offset, count: min(2048, samples.count - offset))
                await Task.yield()
            }
            try Task.checkCancellation()
            guard self.device === device else { throw CancellationError() }
            while try !device.finish() {
                try Task.checkCancellation()
                guard self.device === device else { throw CancellationError() }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
        }

        func stop() {
            device?.stop()
            device = nil
        }
    }

    private final class PlaybackDevice {
        private let handle: OpaquePointer

        init(name: String, sampleRate: Int) throws {
            var error: UnsafeMutablePointer<CChar>?
            let result = supertonic_playback_create(name, UInt32(sampleRate), &error)
            defer { supertonic_error_release(error) }
            guard let result else { throw Self.failure(error) }
            handle = result
        }

        func write(_ samples: [Float], from offset: Int, count: Int) throws -> Int {
            var error: UnsafeMutablePointer<CChar>?
            let written = samples.withUnsafeBufferPointer {
                supertonic_playback_write(handle, $0.baseAddress?.advanced(by: offset), UInt(count), &error)
            }
            defer { supertonic_error_release(error) }
            guard written > 0 else { throw Self.failure(error) }
            return written
        }

        func finish() throws -> Bool {
            var error: UnsafeMutablePointer<CChar>?
            let result = supertonic_playback_finish(handle, &error)
            defer { supertonic_error_release(error) }
            guard result >= 0 else { throw Self.failure(error) }
            return result == 1
        }

        func stop() { supertonic_playback_stop(handle) }

        private static func failure(_ error: UnsafeMutablePointer<CChar>?) -> SupertonicError {
            .playback(error.map { String(cString: $0) } ?? "Audio playback failed")
        }

        deinit { supertonic_playback_release(handle) }
    }
#endif
