import Foundation
import UIKit

@MainActor
final class DictationViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case connecting
        case listening
        case finishing
        case failed(String)

        var label: String {
            switch self {
            case .idle:
                return "Ready"
            case .connecting:
                return "Connecting"
            case .listening:
                return "Listening"
            case .finishing:
                return "Finishing"
            case .failed:
                return "Needs attention"
            }
        }
    }

    @Published var apiKey: String
    @Published private(set) var transcript = ""
    @Published private(set) var status: Status = .idle
    @Published var autoInsertOnKeyboardOpen: Bool {
        didSet {
            sharedStore.autoInsertOnKeyboardOpen = autoInsertOnKeyboardOpen
        }
    }
    @Published var copiedConfirmationVisible = false

    var isRecording: Bool {
        status == .connecting || status == .listening || status == .finishing
    }

    var canShareTranscript: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let audioCapture = AudioCaptureManager()
    private let sharedStore = SharedTranscriptStore.shared

    private var deepgramClient: DeepgramStreamingClient?
    private var audioContinuation: AsyncStream<Data>.Continuation?
    private var audioSendTask: Task<Void, Never>?

    init() {
        apiKey = KeychainStore.loadAPIKey()
        autoInsertOnKeyboardOpen = sharedStore.autoInsertOnKeyboardOpen
        transcript = sharedStore.latestTranscript().text
    }

    func saveAPIKey() {
        do {
            try KeychainStore.saveAPIKey(apiKey)
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func toggleRecording() {
        if isRecording {
            Task {
                await stopRecording()
            }
        } else {
            Task {
                await startRecording()
            }
        }
    }

    func startRecording() async {
        guard !isRecording else {
            return
        }

        do {
            try KeychainStore.saveAPIKey(apiKey)
            transcript = ""
            sharedStore.clearTranscript(removePasteboard: false)

            status = .connecting

            let client = DeepgramStreamingClient(apiKey: apiKey)
            client.onTranscript = { [weak self] text, _ in
                Task { @MainActor in
                    self?.receiveTranscript(text)
                }
            }
            client.onError = { [weak self] message in
                Task { @MainActor in
                    self?.status = .failed(message)
                }
            }

            try await client.connect()
            deepgramClient = client

            let stream = AsyncStream<Data>.makeStream()
            audioContinuation = stream.continuation

            audioSendTask = Task { [weak client] in
                for await chunk in stream.stream {
                    guard !Task.isCancelled else {
                        break
                    }

                    do {
                        try await client?.sendAudio(chunk)
                    } catch {
                        await MainActor.run { [weak self] in
                            self?.status = .failed(error.localizedDescription)
                        }
                        break
                    }
                }
            }

            let audioContinuation = stream.continuation
            try await audioCapture.start { data in
                audioContinuation.yield(data)
            }

            status = .listening
        } catch {
            audioCapture.stop()
            audioContinuation?.finish()
            audioContinuation = nil
            audioSendTask?.cancel()
            audioSendTask = nil
            await deepgramClient?.disconnect()
            deepgramClient = nil
            status = .failed(error.localizedDescription)
        }
    }

    func stopRecording() async {
        guard isRecording else {
            return
        }

        status = .finishing
        audioCapture.stop()
        audioContinuation?.finish()
        audioContinuation = nil

        try? await Task.sleep(nanoseconds: 250_000_000)
        await audioSendTask?.value

        let finalText = (try? await deepgramClient?.finish()) ?? transcript
        receiveTranscript(finalText)

        audioSendTask = nil
        await deepgramClient?.disconnect()
        deepgramClient = nil

        status = .idle
    }

    func copyTranscript() {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            return
        }

        sharedStore.saveTranscript(trimmedTranscript)
        copiedConfirmationVisible = true

        Task {
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            await MainActor.run {
                copiedConfirmationVisible = false
            }
        }
    }

    func clearTranscript() {
        transcript = ""
        sharedStore.clearTranscript(removePasteboard: true)
    }

    private func receiveTranscript(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = trimmedText
        sharedStore.saveTranscript(trimmedText)
    }
}
