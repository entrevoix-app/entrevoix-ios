import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
private final class KeyboardDictationViewModel {
    var statusMessage = "Tap Dictate to speak"
    var needsInputModeSwitchKey = false

    var requestDictation: (() -> Void)?
    var selectNextKeyboard: (() -> Void)?
}

private struct KeyboardDictationView: View {
    @Bindable var model: KeyboardDictationViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text(model.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)

            Button(action: { model.requestDictation?() }) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Start dictation")
            .accessibilityHint("Requests dictation from the Entrevoix app")

            Spacer(minLength: 0)

            HStack {
                Spacer()

                if model.needsInputModeSwitchKey {
                    Button(action: { model.selectNextKeyboard?() }) {
                        Image(systemName: "globe")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Next keyboard")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .background(.clear)
    }
}

final class KeyboardViewController: UIInputViewController {
    private let model = KeyboardDictationViewModel()
    private var hostingController: UIHostingController<KeyboardDictationView>?

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
        model.needsInputModeSwitchKey = needsInputModeSwitchKey
    }

    private func configureView() {
        view.backgroundColor = .clear
        view.isOpaque = false

        model.requestDictation = { [weak self] in
            self?.requestDictation()
        }
        model.selectNextKeyboard = { [weak self] in
            self?.advanceToNextInputMode()
        }

        let hostingController = UIHostingController(rootView: KeyboardDictationView(model: model))
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
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
            model.statusMessage = "Enable Full Access for Entrevoix in Keyboard Settings to dictate."
            return
        }

        let request = KeyboardDictationRequest()
        activeRequestID = request.id
        KeyboardHandoffStore.clearResult(for: request.id)
        KeyboardHandoffStore.writeRequest(request)
        model.statusMessage = "Waiting for Entrevoix"
    }

    @objc private func refreshResult() {
        guard let activeRequestID,
              let result = KeyboardHandoffStore.readResult(),
              result.requestID == activeRequestID
        else { return }

        switch result.state {
        case .requested:
            model.statusMessage = "Waiting for Entrevoix"
        case .recording:
            model.statusMessage = "Listening…"
        case .transcribing:
            model.statusMessage = "Transcribing…"
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
        model.statusMessage = message
    }
}
