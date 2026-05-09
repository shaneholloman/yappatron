import AVFoundation
import Foundation

/// Microphone-only capture using AVAudioEngine. Behavioral parity with
/// Yappatron's original audio path. Output is always 16kHz mono Float32.
final class MicAudioSource: AudioCaptureSource, @unchecked Sendable {

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    private(set) var isRunning: Bool = false

    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws {
        if isRunning { return }
        self.onBuffer = onBuffer

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard let processingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "MicAudioSource", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not build 16k mono format"])
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            if let converted = MicAudioSource.convert(buffer, from: inputFormat, to: processingFormat) {
                self.onBuffer?(converted)
            }
        }

        engine.prepare()
        try engine.start()

        self.audioEngine = engine
        self.inputNode = input
        self.isRunning = true
    }

    func stop() {
        if !isRunning { return }
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
        onBuffer = nil
        isRunning = false
    }

    static func convert(_ buffer: AVAudioPCMBuffer, from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return nil }
        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount) else { return nil }
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil else { return nil }
        return outputBuffer
    }
}
