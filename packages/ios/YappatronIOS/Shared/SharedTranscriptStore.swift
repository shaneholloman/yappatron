import Foundation

enum YappatronShared {
    static let appGroupIdentifier = "group.com.yappatron.shared"
}

struct SharedTranscript: Equatable {
    let text: String
    let updatedAt: TimeInterval
    let autoInsertOnKeyboardOpen: Bool
}

final class SharedTranscriptStore {
    static let shared = SharedTranscriptStore()

    private enum Keys {
        static let latestTranscript = "latestTranscript"
        static let latestTranscriptUpdatedAt = "latestTranscriptUpdatedAt"
        static let autoInsertOnKeyboardOpen = "autoInsertOnKeyboardOpen"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = UserDefaults(suiteName: YappatronShared.appGroupIdentifier)) {
        self.defaults = defaults ?? .standard
    }

    var autoInsertOnKeyboardOpen: Bool {
        get {
            defaults.bool(forKey: Keys.autoInsertOnKeyboardOpen)
        }
        set {
            defaults.set(newValue, forKey: Keys.autoInsertOnKeyboardOpen)
        }
    }

    func saveTranscript(_ text: String, updatedAt: Date = Date()) {
        defaults.set(text, forKey: Keys.latestTranscript)
        defaults.set(updatedAt.timeIntervalSince1970, forKey: Keys.latestTranscriptUpdatedAt)
    }

    func latestTranscript() -> SharedTranscript {
        SharedTranscript(
            text: defaults.string(forKey: Keys.latestTranscript) ?? "",
            updatedAt: defaults.double(forKey: Keys.latestTranscriptUpdatedAt),
            autoInsertOnKeyboardOpen: autoInsertOnKeyboardOpen
        )
    }
}
