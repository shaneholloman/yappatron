import AppKit
import Foundation
import SwiftUI

/// Floating window that records 10s of audio, runs embedding extraction, and
/// upserts the result into SpeakerRegistry under the given name. The caller
/// is expected to pause the active TranscriptionEngine before invoking.
@MainActor
final class EnrollSpeakerCoordinator {

    private var window: NSWindow?

    func enroll(suggestedName: String, embedder: SpeakerEmbedder, onDone: @escaping (Result<EnrolledSpeaker, Error>) -> Void) {
        // Prompt for a name first.
        let alert = NSAlert()
        alert.messageText = "Enroll a speaker"
        alert.informativeText = "Speak naturally for 10 seconds after pressing Start. We'll capture your voiceprint locally."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.stringValue = suggestedName
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        showRecordingWindow(name: name)

        Task {
            do {
                try await embedder.loadIfNeeded()
                let recorder = EnrollmentRecorder()
                let samples = try await recorder.record(for: EnrollmentRecorder.defaultDuration)
                guard let embedding = await embedder.embedding(for: samples) else {
                    self.closeRecordingWindow()
                    onDone(.failure(NSError(domain: "Enrollment", code: 1, userInfo: [NSLocalizedDescriptionKey: "Embedding extraction failed"])))
                    return
                }
                let speaker = EnrolledSpeaker(
                    id: UUID().uuidString,
                    name: name,
                    embedding: embedding,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try SpeakerRegistry.upsert(speaker)
                self.closeRecordingWindow()
                onDone(.success(speaker))
            } catch {
                self.closeRecordingWindow()
                onDone(.failure(error))
            }
        }
    }

    private func showRecordingWindow(name: String) {
        let view = RecordingView(name: name, totalDuration: EnrollmentRecorder.defaultDuration)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled]
        window.title = "Enrolling \(name)…"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.setContentSize(NSSize(width: 320, height: 100))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func closeRecordingWindow() {
        window?.close()
        window = nil
    }
}

private struct RecordingView: View {
    let name: String
    let totalDuration: TimeInterval
    @State private var progress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recording \(name)")
                .font(.headline)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
            Text("Speak naturally for \(Int(totalDuration)) seconds…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            Task {
                let steps = 100
                for i in 0...steps {
                    try? await Task.sleep(nanoseconds: UInt64(totalDuration * 1_000_000_000) / UInt64(steps))
                    await MainActor.run { progress = Double(i) / Double(steps) }
                }
            }
        }
    }
}
