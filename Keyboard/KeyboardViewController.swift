import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
private final class KeyboardDictationViewModel {
    var statusMessage = String(localized: "Tap to start dictating")
    var isDictationActive = false
    var isReadyToStop = false
    var needsInputModeSwitchKey = false

    var requestDictation: (() -> Void)?
    var stopDictation: (() -> Void)?
    var selectNextKeyboard: (() -> Void)?
}

private struct KeyboardDictationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: KeyboardDictationViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text(model.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)

            dictationControl

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

    @ViewBuilder
    private var dictationControl: some View {
        if model.isDictationActive {
            Button(action: { model.stopDictation?() }) { dictationIcon }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(.red)
                .disabled(!model.isReadyToStop)
                .accessibilityLabel("Stop dictation")
                .accessibilityHint("Finishes recording and starts transcription")
        } else {
            Link(destination: URL(string: "entrevoix://dictation/start")!) { dictationIcon }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(.blue)
                .simultaneousGesture(TapGesture().onEnded { model.requestDictation?() })
                .accessibilityLabel("Start dictation")
                .accessibilityHint("Opens Entrevoix to start recording")
        }
    }

    private var dictationIcon: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 32, weight: .medium))
            .frame(width: 80, height: 80)
            .animation(
                reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2),
                value: model.isDictationActive
            )
            .padding(.top, 16)
    }
}

final class KeyboardViewController: UIInputViewController {
    private static let microphonePreparationTimeout: TimeInterval = 10

    private let model = KeyboardDictationViewModel()
    private var hostingController: UIHostingController<KeyboardDictationView>?

    private var activeRequestID: UUID?
    private var resultPollingTimer: Timer?
    private var handoffTimeoutTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        hasDictationKey = true
        configureView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        recoverActiveRequestIfNeeded()
        refreshResult()
        startResultPolling()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resultPollingTimer?.invalidate()
        resultPollingTimer = nil
        handoffTimeoutTimer?.invalidate()
        handoffTimeoutTimer = nil
        model.isDictationActive = false
        model.isReadyToStop = false
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
        model.stopDictation = { [weak self] in
            self?.stopDictation()
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

    /// Keyboard extensions can be terminated while the containing app is in
    /// front. Reconstruct the in-flight session from the durable handoff when
    /// iOS creates a new extension instance on the way back.
    private func recoverActiveRequestIfNeeded() {
        guard activeRequestID == nil,
              let request = KeyboardHandoffStore.readRequest(),
              request.isSupported,
              request.command != .cancel,
              Date.now.timeIntervalSince(request.createdAt) < 5 * 60
        else { return }

        if isMicrophonePreparationExpired(for: request) {
            abandonMicrophonePreparation(requestID: request.id, showFeedback: false)
            return
        }

        activeRequestID = request.id
        if KeyboardHandoffStore.readResult()?.requestID != request.id {
            model.isDictationActive = true
            model.isReadyToStop = false
            model.statusMessage = String(localized: "Reconnecting to Entrevoix…")
        }
    }

    @objc private func requestDictation() {
        guard hasFullAccess else {
            model.isDictationActive = false
            model.statusMessage = String(localized: "Enable Full Access for Entrevoix in Keyboard Settings to dictate.")
            return
        }

        let request = KeyboardDictationRequest(command: .start)
        activeRequestID = request.id
        KeyboardHandoffStore.clearHandoff(for: request.id)
        KeyboardHandoffStore.writeRequest(request)
        KeyboardHandoffStore.notifyCommand()
        model.isDictationActive = true
        model.isReadyToStop = false
        model.statusMessage = String(localized: "Opening Entrevoix…")
        handoffTimeoutTimer?.invalidate()
        handoffTimeoutTimer = Timer.scheduledTimer(withTimeInterval: Self.microphonePreparationTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let requestID = self.activeRequestID else { return }
                let result = KeyboardHandoffStore.readResult()
                guard result?.requestID != requestID || result?.state == .requested else { return }
                self.abandonMicrophonePreparation(requestID: requestID, showFeedback: true)
            }
        }
    }

    @objc private func stopDictation() {
        guard let activeRequestID else { return }
        handoffTimeoutTimer?.invalidate()
        handoffTimeoutTimer = nil
        KeyboardHandoffStore.writeRequest(KeyboardDictationRequest(id: activeRequestID, command: .stop))
        KeyboardHandoffStore.notifyCommand()
        model.isDictationActive = true
        model.isReadyToStop = false
        model.statusMessage = String(localized: "Finishing…")
    }

    @objc private func refreshResult() {
        guard let activeRequestID,
              let result = KeyboardHandoffStore.readResult(),
              result.requestID == activeRequestID
        else { return }

        switch result.state {
        case .requested:
            if isMicrophonePreparationExpired(for: activeRequestID) {
                abandonMicrophonePreparation(requestID: activeRequestID, showFeedback: true)
                return
            }
            model.isDictationActive = true
            model.isReadyToStop = false
            model.statusMessage = String(localized: "Entrevoix is preparing microphone access…")
        case .recording:
            model.isDictationActive = true
            model.isReadyToStop = true
            model.statusMessage = String(localized: "Listening…")
        case .transcribing:
            model.isDictationActive = false
            model.isReadyToStop = false
            model.statusMessage = String(localized: "Transcribing…")
        case .completed:
            if let transcript = result.transcript, !transcript.isEmpty {
                textDocumentProxy.insertText(transcript)
            }
            finish(requestID: activeRequestID, message: String(localized: "Ready"))
        case .failed:
            finish(requestID: activeRequestID, message: result.message ?? String(localized: "Dictation failed"))
        case .cancelled:
            finish(requestID: activeRequestID, message: String(localized: "Dictation cancelled"))
        }
    }

    private func isMicrophonePreparationExpired(for requestID: UUID) -> Bool {
        guard let request = KeyboardHandoffStore.readRequest(), request.id == requestID else { return false }
        return isMicrophonePreparationExpired(for: request)
    }

    private func isMicrophonePreparationExpired(for request: KeyboardDictationRequest) -> Bool {
        guard request.command == .start,
              KeyboardHandoffStore.readResult()?.requestID == request.id,
              KeyboardHandoffStore.readResult()?.state == .requested
        else { return false }

        return Date.now.timeIntervalSince(request.createdAt) >= Self.microphonePreparationTimeout
    }

    private func abandonMicrophonePreparation(requestID: UUID, showFeedback: Bool) {
        handoffTimeoutTimer?.invalidate()
        handoffTimeoutTimer = nil
        KeyboardHandoffStore.writeRequest(KeyboardDictationRequest(id: requestID, command: .cancel))
        KeyboardHandoffStore.notifyCommand()
        activeRequestID = nil
        model.isDictationActive = false
        model.isReadyToStop = false
        model.statusMessage = showFeedback
            ? String(localized: "Microphone preparation took too long. Open Entrevoix, then try again.")
            : String(localized: "Tap to start dictating")
    }

    private func finish(requestID: UUID, message: String) {
        handoffTimeoutTimer?.invalidate()
        handoffTimeoutTimer = nil
        KeyboardHandoffStore.clearHandoff(for: requestID)
        activeRequestID = nil
        model.isDictationActive = false
        model.isReadyToStop = false
        model.statusMessage = message
    }
}
