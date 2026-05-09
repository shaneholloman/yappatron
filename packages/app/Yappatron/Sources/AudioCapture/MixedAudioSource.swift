import AVFoundation
import Foundation

/// Combines a mic source and a system-audio source into a single stream of
/// 16kHz mono Float32 buffers. Both inputs are 16kHz mono already by the time
/// they reach us; we just need to time-align and sum them sample-wise.
///
/// Strategy: each side feeds a small ring of pending samples. A periodic flush
/// task emits a fixed-size mixed chunk (160 frames = 10ms at 16kHz). If one
/// side is starved, we zero-pad it for that chunk — the other side still gets
/// through, which is exactly what we want for "system audio is playing while
/// the mic is silent" or vice versa.
final class MixedAudioSource: AudioCaptureSource, @unchecked Sendable {

    private let mic: AudioCaptureSource
    private let system: AudioCaptureSource
    private var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    private(set) var isRunning: Bool = false

    private let lock = NSLock()
    private var micPending: [Float] = []
    private var systemPending: [Float] = []

    private let sampleRate: Double = 16000
    private let chunkFrames: Int = 160  // 10ms at 16kHz
    private var flushTask: Task<Void, Never>?

    private let targetFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
    }()

    init(mic: AudioCaptureSource, system: AudioCaptureSource) {
        self.mic = mic
        self.system = system
    }

    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws {
        if isRunning { return }
        self.onBuffer = onBuffer

        try await mic.start { [weak self] buf in self?.appendMic(buf) }
        do {
            try await system.start { [weak self] buf in self?.appendSystem(buf) }
        } catch {
            mic.stop()
            throw error
        }

        isRunning = true
        startFlushLoop()
    }

    func stop() {
        if !isRunning { return }
        isRunning = false
        flushTask?.cancel()
        flushTask = nil
        mic.stop()
        system.stop()
        lock.lock()
        micPending.removeAll()
        systemPending.removeAll()
        lock.unlock()
    }

    // MARK: - Sample accumulation

    private func appendMic(_ buffer: AVAudioPCMBuffer) {
        guard let samples = floatSamples(from: buffer) else { return }
        lock.lock()
        micPending.append(contentsOf: samples)
        // Cap to ~1s to bound memory if one side is misbehaving.
        if micPending.count > 16000 { micPending.removeFirst(micPending.count - 16000) }
        lock.unlock()
    }

    private func appendSystem(_ buffer: AVAudioPCMBuffer) {
        guard let samples = floatSamples(from: buffer) else { return }
        lock.lock()
        systemPending.append(contentsOf: samples)
        if systemPending.count > 16000 { systemPending.removeFirst(systemPending.count - 16000) }
        lock.unlock()
    }

    private func floatSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return nil }
        return Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
    }

    // MARK: - Periodic flush + mix

    private func startFlushLoop() {
        flushTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                self?.flushOnce()
            }
        }
    }

    private func flushOnce() {
        // Mix as many full chunks as both sides can supply (up to a cap to
        // prevent runaway latency if one side gets ahead).
        let maxChunksPerFlush = 4

        for _ in 0..<maxChunksPerFlush {
            lock.lock()
            // Decide how many frames to emit this iteration. We emit at the
            // pace of *whichever side has data* — if mic has 320 samples and
            // system has 0, we still emit a chunk with mic + zero-padded system.
            // This avoids stalling on a quiet system or quiet mic.
            let micCount = micPending.count
            let sysCount = systemPending.count
            let available = max(micCount, sysCount)
            if available < chunkFrames {
                lock.unlock()
                return
            }

            var micChunk = [Float](repeating: 0, count: chunkFrames)
            var sysChunk = [Float](repeating: 0, count: chunkFrames)

            let micTake = min(chunkFrames, micCount)
            if micTake > 0 {
                micChunk.replaceSubrange(0..<micTake, with: micPending.prefix(micTake))
                micPending.removeFirst(micTake)
            }
            let sysTake = min(chunkFrames, sysCount)
            if sysTake > 0 {
                sysChunk.replaceSubrange(0..<sysTake, with: systemPending.prefix(sysTake))
                systemPending.removeFirst(sysTake)
            }
            lock.unlock()

            // Sum and clamp. Using a 0.7 scaling on each side gives us headroom
            // — two simultaneous 0dBFS inputs can otherwise saturate.
            var mixed = [Float](repeating: 0, count: chunkFrames)
            let micGain: Float = 0.8
            let sysGain: Float = 0.8
            for i in 0..<chunkFrames {
                var v = micChunk[i] * micGain + sysChunk[i] * sysGain
                if v > 1.0 { v = 1.0 } else if v < -1.0 { v = -1.0 }
                mixed[i] = v
            }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(chunkFrames)) else {
                return
            }
            buffer.frameLength = AVAudioFrameCount(chunkFrames)
            if let dst = buffer.floatChannelData {
                mixed.withUnsafeBufferPointer { src in
                    if let base = src.baseAddress {
                        memcpy(dst[0], base, chunkFrames * MemoryLayout<Float>.size)
                    }
                }
            }
            onBuffer?(buffer)
        }
    }
}
