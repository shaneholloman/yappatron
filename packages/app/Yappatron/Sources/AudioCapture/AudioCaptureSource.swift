import AVFoundation
import Foundation

/// A source of 16kHz mono Float32 PCM audio buffers. The TranscriptionEngine is
/// agnostic to where these come from — they could be the mic, system audio,
/// or a mix of both.
protocol AudioCaptureSource: AnyObject {
    /// Begin capturing. Each captured chunk is delivered via `onBuffer` on an
    /// arbitrary thread. The buffer is 16kHz mono Float32 PCM.
    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws

    /// Stop capturing. Idempotent.
    func stop()

    var isRunning: Bool { get }
}
