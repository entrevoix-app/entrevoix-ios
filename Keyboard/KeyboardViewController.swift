import UIKit

final class KeyboardViewController: UIInputViewController {
    private let statusLabel = UILabel()
    private let microphoneButton = UIButton(type: .system)
    private let modeButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)
    private let manualKeyboardStack = UIStackView()

    private var isShowingManualKeyboard = false {
        didSet { updateVisibleMode() }
    }
    private var activeRequestID: UUID?
    private var resultPollingTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        updateVisibleMode()
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
        view.backgroundColor = .secondarySystemBackground

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.adjustsFontForContentSizeCategory = true

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

        modeButton.configuration = .bordered()
        modeButton.addTarget(self, action: #selector(toggleInputMode), for: .touchUpInside)

        var nextKeyboardConfiguration = UIButton.Configuration.bordered()
        nextKeyboardConfiguration.image = UIImage(systemName: "globe")
        nextKeyboardButton.configuration = nextKeyboardConfiguration
        nextKeyboardButton.addTarget(self, action: #selector(selectNextKeyboard), for: .touchUpInside)
        nextKeyboardButton.accessibilityLabel = "Next keyboard"

        manualKeyboardStack.axis = .vertical
        manualKeyboardStack.spacing = 6
        manualKeyboardStack.distribution = .fillEqually
        manualKeyboardStack.addArrangedSubview(keyRow("QWERTYUIOP"))
        manualKeyboardStack.addArrangedSubview(keyRow("ASDFGHJKL"))
        manualKeyboardStack.addArrangedSubview(keyRow("ZXCVBNM"))
        manualKeyboardStack.addArrangedSubview(bottomKeyRow())

        let rootStack = UIStackView(arrangedSubviews: [
            statusLabel,
            microphoneButton,
            manualKeyboardStack,
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
            microphoneButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            manualKeyboardStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 176)
        ])
    }

    private func controlsRow() -> UIStackView {
        let spacer = UIView()
        let row = UIStackView(arrangedSubviews: [modeButton, spacer, nextKeyboardButton])
        row.axis = .horizontal
        row.spacing = 8
        NSLayoutConstraint.activate([
            modeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            nextKeyboardButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            nextKeyboardButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        return row
    }

    private func keyRow(_ characters: String) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 6
        row.distribution = .fillEqually
        characters.forEach { character in
            row.addArrangedSubview(keyButton(String(character)))
        }
        return row
    }

    private func bottomKeyRow() -> UIStackView {
        let deleteButton = keyButton("⌫", insertsCharacter: false)
        deleteButton.addTarget(self, action: #selector(deleteBackward), for: .touchUpInside)
        deleteButton.accessibilityLabel = "Delete"

        let spaceButton = keyButton("space", insertsCharacter: false)
        spaceButton.addTarget(self, action: #selector(insertSpace), for: .touchUpInside)

        let returnButton = keyButton("return", insertsCharacter: false)
        returnButton.addTarget(self, action: #selector(insertReturn), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [deleteButton, spaceButton, returnButton])
        row.axis = .horizontal
        row.spacing = 6
        row.distribution = .fillProportionally
        return row
    }

    private func keyButton(_ title: String, insertsCharacter: Bool = true) -> UIButton {
        var configuration = UIButton.Configuration.gray()
        configuration.title = title
        configuration.cornerStyle = .medium
        let button = UIButton(type: .system)
        button.configuration = configuration
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        if insertsCharacter {
            button.addTarget(self, action: #selector(insertCharacter(_:)), for: .touchUpInside)
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return button
    }

    private func updateVisibleMode() {
        manualKeyboardStack.isHidden = !isShowingManualKeyboard
        microphoneButton.isHidden = isShowingManualKeyboard
        statusLabel.text = activeRequestID == nil
            ? "Tap Dictate to speak"
            : "Waiting for Entrevoix"
        modeButton.configuration?.title = isShowingManualKeyboard ? "Dictate" : "ABC"
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

    @objc private func toggleInputMode() {
        isShowingManualKeyboard.toggle()
    }

    @objc private func insertCharacter(_ sender: UIButton) {
        guard let character = sender.configuration?.title, character.count == 1 else { return }
        textDocumentProxy.insertText(character.lowercased())
    }

    @objc private func insertSpace() {
        textDocumentProxy.insertText(" ")
    }

    @objc private func insertReturn() {
        textDocumentProxy.insertText("\n")
    }

    @objc private func deleteBackward() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func selectNextKeyboard() {
        advanceToNextInputMode()
    }
}
