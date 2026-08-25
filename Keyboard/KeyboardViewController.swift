import UIKit

final class KeyboardViewController: UIInputViewController {
    private let statusLabel = UILabel()
    private let microphoneButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)

    private var activeRequestID: UUID?
    private var resultPollingTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshResult()
        startResultPolling()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resultPollingTimer?.invalidate()
        resultPollingTimer = nil
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        nextKeyboardButton.isHidden = !needsInputModeSwitchKey
    }

    private func configureView() {
        view.backgroundColor = .clear
        view.isOpaque = false

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.text = "Tap Dictate to speak"

        var microphoneConfiguration = UIButton.Configuration.filled()
        microphoneConfiguration.title = "Dictate"
        microphoneConfiguration.image = UIImage(systemName: "mic.fill")
        microphoneConfiguration.imagePadding = 8
        microphoneConfiguration.cornerStyle = .large
        microphoneButton.configuration = microphoneConfiguration
        microphoneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        microphoneButton.addTarget(self, action: #selector(requestDictation), for: .touchUpInside)
        microphoneButton.accessibilityLabel = "Start dictation"
        microphoneButton.accessibilityHint = "Requests dictation from the Entrevoix app"

        var nextKeyboardConfiguration = UIButton.Configuration.bordered()
        nextKeyboardConfiguration.image = UIImage(systemName: "globe")
        nextKeyboardButton.configuration = nextKeyboardConfiguration
        nextKeyboardButton.addTarget(self, action: #selector(selectNextKeyboard), for: .touchUpInside)
        nextKeyboardButton.accessibilityLabel = "Next keyboard"

        let rootStack = UIStackView(arrangedSubviews: [
            statusLabel,
            microphoneButton,
            controlsRow()
        ])
        rootStack.axis = .vertical
        rootStack.spacing = 8
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            microphoneButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }

    private func controlsRow() -> UIStackView {
        let spacer = UIView()
        let row = UIStackView(arrangedSubviews: [spacer, nextKeyboardButton])
        row.axis = .horizontal
        row.spacing = 8
        NSLayoutConstraint.activate([
            nextKeyboardButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            nextKeyboardButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        return row
    }

    private func startResultPolling() {
        resultPollingTimer?.invalidate()
        resultPollingTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(refreshResult),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func requestDictation() {
        guard hasFullAccess else {
            statusLabel.text = "Enable Full Access for Entrevoix in Keyboard Settings to dictate."
            return
        }

        let request = KeyboardDictationRequest()
        activeRequestID = request.id
        KeyboardHandoffStore.clearResult(for: request.id)
        KeyboardHandoffStore.writeRequest(request)
        statusLabel.text = "Waiting for Entrevoix"
    }

    @objc private func refreshResult() {
        guard let activeRequestID,
              let result = KeyboardHandoffStore.readResult(),
              result.requestID == activeRequestID
        else { return }

        switch result.state {
        case .requested:
            statusLabel.text = "Waiting for Entrevoix"
        case .recording:
            statusLabel.text = "Listening…"
        case .transcribing:
            statusLabel.text = "Transcribing…"
        case .completed:
            if let transcript = result.transcript, !transcript.isEmpty {
                textDocumentProxy.insertText(transcript)
            }
            finish(requestID: activeRequestID, message: "Ready")
        case .failed:
            finish(requestID: activeRequestID, message: result.message ?? "Dictation failed")
        case .cancelled:
            finish(requestID: activeRequestID, message: "Dictation cancelled")
        }
    }

    private func finish(requestID: UUID, message: String) {
        KeyboardHandoffStore.clearResult(for: requestID)
        activeRequestID = nil
        statusLabel.text = message
    }

    @objc private func selectNextKeyboard() {
        advanceToNextInputMode()
    }
}
