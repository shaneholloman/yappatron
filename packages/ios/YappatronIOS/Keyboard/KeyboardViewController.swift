import UIKit

final class KeyboardViewController: UIInputViewController {
    private let transcriptStore = SharedTranscriptStore.shared
    private let localDefaults = UserDefaults.standard

    private let transcriptLabel = UILabel()
    private let insertButton = UIButton(type: .system)
    private let refreshButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)

    private var latestTranscript = SharedTranscript(text: "", updatedAt: 0, autoInsertOnKeyboardOpen: false)

    private enum LocalKeys {
        static let lastAutoInsertedUpdatedAt = "lastAutoInsertedUpdatedAt"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        refreshTranscript()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshTranscript()
        autoInsertIfNeeded()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshTranscript()
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        transcriptLabel.font = .preferredFont(forTextStyle: .callout)
        transcriptLabel.numberOfLines = 3
        transcriptLabel.lineBreakMode = .byTruncatingTail
        transcriptLabel.textColor = .label
        transcriptLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        insertButton.configuration = .filled()
        insertButton.configuration?.image = UIImage(systemName: "text.insert")
        insertButton.configuration?.imagePadding = 8
        insertButton.configuration?.title = "Insert"
        insertButton.addTarget(self, action: #selector(insertLatestTranscript), for: .touchUpInside)

        refreshButton.configuration = .tinted()
        refreshButton.configuration?.image = UIImage(systemName: "arrow.clockwise")
        refreshButton.addTarget(self, action: #selector(refreshButtonTapped), for: .touchUpInside)
        refreshButton.accessibilityLabel = "Refresh latest transcript"

        nextKeyboardButton.configuration = .plain()
        nextKeyboardButton.configuration?.image = UIImage(systemName: "globe")
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        nextKeyboardButton.accessibilityLabel = "Next keyboard"

        let buttonRow = UIStackView(arrangedSubviews: [nextKeyboardButton, refreshButton, insertButton])
        buttonRow.axis = .horizontal
        buttonRow.alignment = .fill
        buttonRow.distribution = .fill
        buttonRow.spacing = 10

        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        refreshButton.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let stack = UIStackView(arrangedSubviews: [transcriptLabel, buttonRow])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: -8),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 172)
        ])
    }

    private func refreshTranscript() {
        latestTranscript = transcriptStore.latestTranscriptForKeyboard()
        let text = latestTranscript.text.trimmingCharacters(in: .whitespacesAndNewlines)

        transcriptLabel.text = text.isEmpty ? "Open Yappatron to record." : text
        transcriptLabel.textColor = text.isEmpty ? .secondaryLabel : .label
        insertButton.isEnabled = !text.isEmpty
    }

    private func autoInsertIfNeeded() {
        guard latestTranscript.autoInsertOnKeyboardOpen,
              latestTranscript.updatedAt > 0,
              latestTranscript.updatedAt != localDefaults.double(forKey: LocalKeys.lastAutoInsertedUpdatedAt) else {
            return
        }

        insertLatestTranscript()
        localDefaults.set(latestTranscript.updatedAt, forKey: LocalKeys.lastAutoInsertedUpdatedAt)
    }

    @objc private func insertLatestTranscript() {
        let text = latestTranscript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        textDocumentProxy.insertText(text)
    }

    @objc private func refreshButtonTapped() {
        refreshTranscript()
    }
}
