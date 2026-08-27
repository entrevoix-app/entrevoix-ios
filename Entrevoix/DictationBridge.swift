import AVFoundation
import EntrevoixAppleAdapters
import EntrevoixCore
import EntrevoixOpenAIAdapters
import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class DictationBridge {
    enum State: Equatable {
        case idle
        case requestingPermission
        case recording
        case transcribing
        case failed(String)
    }

    var state: State = .idle
    var isPresented = false

    private let preferences: PreferencesModel
    private let audioRecorder = KeyboardAudioRecorder()
    private let microphonePermission = KeyboardMicrophonePermission()
    private let textDelivery = KeyboardTextDelivery()
    private let logger = KeyboardDictationLogger()
    private var activeRequest: KeyboardDictationRequest?
    private var activeDictationRequest: DictationRequest?
    private var lastCommandDate: Date?
    private var lastCoordinatorState: DictationState = .idle
    @ObservationIgnored private var transcriptionBackgroundTask = UIBackgroundTaskIdentifier.invalid
    @ObservationIgnored private let commandObserver: KeyboardHandoffCommandObserver

    @ObservationIgnored private lazy var coordinator: DictationCoordinator = {
        let coordinator = DictationCoordinator(
            dependencies: DictationDependencies(
                audioRecorder: audioRecorder,
                audioCaptureTrimmer: AppleSpeechAudioCaptureTrimmer(),
                microphonePermission: microphonePermission,
                textDelivery: textDelivery,
                transcriber: KeyboardSpeechTranscriber(),
                cleaner: KeyboardTextCleaner(),
                logger: logger
            )
        )
        coordinator.onSnapshot = { [weak self] snapshot in
            self?.consume(snapshot: snapshot)
        }
        return coordinator
    }()

    init(preferences: PreferencesModel) {
        self.preferences = preferences
        commandObserver = KeyboardHandoffStore.observeCommands {}
        _ = coordinator
        commandObserver.replaceHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.consumeLatestCommand()
            }
        }
    }

    func handle(url: URL) {
        guard url.scheme == "entrevoix",
              url.host == "dictation",
              url.path == "/start"
        else { return }

        guard let request = KeyboardHandoffStore.readRequest(), request.command == .start else {
            return
        }
        guard request.isSupported else {
            KeyboardHandoffStore.writeResult(
                KeyboardDictationResult(
                    requestID: request.id,
                    state: .failed,
                    message: String(localized: "This keyboard request is from an incompatible version of Entrevoix.")
                )
            )
            return
        }
        guard Date.now.timeIntervalSince(request.createdAt) < 30 else {
            KeyboardHandoffStore.writeResult(
                KeyboardDictationResult(
                    requestID: request.id,
                    state: .failed,
                    message: String(localized: "The dictation request expired. Return to your app and try again.")
                )
            )
            return
        }

        begin(request)
    }

    func cancelFromApp() {
        guard activeRequest != nil else {
            isPresented = false
            return
        }
        coordinator.cancelRecording()
    }

    private func begin(_ request: KeyboardDictationRequest) {
        guard activeRequest == nil else { return }
        activeRequest = request
        lastCommandDate = request.createdAt
        isPresented = true
        state = .requestingPermission
        KeyboardHandoffStore.writeResult(KeyboardDictationResult(requestID: request.id, state: .requested))

        do {
            let dictationRequest = try preferences.makeKeyboardDictationRequest()
            activeDictationRequest = dictationRequest
            coordinator.startRecording(
                request: dictationRequest,
                audioInput: preferences.preferences.audioInputSelection,
                trimLeadingAndTrailingSilence: preferences.preferences.trimLeadingAndTrailingSilence,
                reduceLongInternalPauses: preferences.preferences.reduceLongInternalPauses
            )
        } catch {
            fail(requestID: request.id, message: error.localizedDescription)
        }
    }

    private func consumeLatestCommand() {
        guard let command = KeyboardHandoffStore.readRequest(), command.isSupported,
              command.createdAt != lastCommandDate else { return }
        lastCommandDate = command.createdAt

        switch command.command {
        case .start:
            guard command.id != activeRequest?.id else { return }
            if activeRequest != nil { coordinator.cancelRecording() }
            begin(command)
        case .stop:
            guard command.id == activeRequest?.id, let dictationRequest = activeDictationRequest else { return }
            coordinator.stopRecording(request: dictationRequest)
        case .cancel:
            guard command.id == activeRequest?.id else { return }
            coordinator.cancelRecording()
        }
    }

    private func consume(snapshot: DictationSnapshot) {
        guard let request = activeRequest else { return }
        let previousState = lastCoordinatorState
        lastCoordinatorState = snapshot.state

        switch snapshot.state {
        case .idle:
            guard previousState != .idle else { return }
            if previousState == .transcribing, let transcript = snapshot.lastTranscript, !transcript.isEmpty {
                complete(requestID: request.id, state: .completed, transcript: transcript)
            } else {
                complete(requestID: request.id, state: .cancelled)
            }
        case .requestingPermission:
            state = .requestingPermission
            KeyboardHandoffStore.writeResult(KeyboardDictationResult(requestID: request.id, state: .requested))
        case .recording:
            state = .recording
            KeyboardHandoffStore.writeResult(KeyboardDictationResult(requestID: request.id, state: .recording))
        case .transcribing:
            state = .transcribing
            beginTranscriptionBackgroundTask()
            KeyboardHandoffStore.writeResult(KeyboardDictationResult(requestID: request.id, state: .transcribing))
        case .error(let failure):
            fail(requestID: request.id, message: message(for: failure))
        }
    }

    private func complete(
        requestID: UUID,
        state resultState: KeyboardDictationState,
        transcript: String? = nil
    ) {
        endTranscriptionBackgroundTask()
        KeyboardHandoffStore.writeResult(
            KeyboardDictationResult(requestID: requestID, state: resultState, transcript: transcript)
        )
        activeRequest = nil
        activeDictationRequest = nil
        lastCoordinatorState = .idle
        state = .idle
        isPresented = false
    }

    private func fail(requestID: UUID, message: String) {
        endTranscriptionBackgroundTask()
        KeyboardHandoffStore.writeResult(
            KeyboardDictationResult(requestID: requestID, state: .failed, message: message)
        )
        activeRequest = nil
        activeDictationRequest = nil
        lastCoordinatorState = .idle
        state = .failed(message)
        isPresented = true
    }

    private func beginTranscriptionBackgroundTask() {
        guard transcriptionBackgroundTask == .invalid else { return }
        transcriptionBackgroundTask = UIApplication.shared.beginBackgroundTask(
            withName: "Entrevoix keyboard transcription"
        ) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let request = self.activeRequest else { return }
                self.coordinator.cancelRecording()
                self.fail(
                    requestID: request.id,
                    message: String(localized: "Dictation took too long to finish. Try again.")
                )
            }
        }
    }

    private func endTranscriptionBackgroundTask() {
        guard transcriptionBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(transcriptionBackgroundTask)
        transcriptionBackgroundTask = .invalid
    }

    private func message(for failure: DictationFailure) -> String {
        switch failure {
        case .microphonePermissionDenied:
            String(localized: "Microphone access was denied. Allow Entrevoix in Settings and try again.")
        case .recordingFailed:
            String(localized: "Entrevoix could not start audio capture. Try again.")
        case .audioUnavailable:
            String(localized: "No audio was captured. Try again.")
        case .noSpeechDetected:
            String(localized: "No speech was detected. Try again.")
        case .sessionUnavailable:
            String(localized: "The dictation session ended unexpectedly. Try again.")
        case .transcriptionFailed:
            String(localized: "Transcription failed. Check your provider settings and try again.")
        case .cleanupFailed, .cleanupWorkflowFailed:
            String(localized: "Transcript improvement failed. Check your provider settings and try again.")
        }
    }
}

struct DictationBridgeView: View {
    @Bindable var bridge: DictationBridge

    var body: some View {
        Group {
            switch bridge.state {
            case .requestingPermission:
                ContentUnavailableView(
                    "Preparing microphone…",
                    systemImage: "mic.badge.plus",
                    description: Text("Allow microphone access if iOS asks, and keep Entrevoix open until the microphone indicator appears.")
                )
            case .recording:
                ContentUnavailableView(
                    "Dictation is on",
                    systemImage: "mic.fill",
                    description: Text("Swipe back to the app where you were typing, speak, then tap the red microphone in the Entrevoix keyboard to finish.")
                )
            case .transcribing:
                ContentUnavailableView(
                    "Transcribing…",
                    systemImage: "waveform",
                    description: Text("Entrevoix is preparing your text.")
                )
            case .failed(let message):
                ContentUnavailableView(
                    "Dictation failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .idle:
                EmptyView()
            }
        }
        .toolbar {
            if bridge.state != .transcribing {
                Button("Cancel", role: .cancel) { bridge.cancelFromApp() }
            }
        }
    }
}

@MainActor
private final class KeyboardAudioRecorder: NSObject, AudioRecording {
    private var recorder: AVAudioRecorder?
    private var activeCaptureURL: URL?

    func start(input: AudioInputSelection) throws -> AudioInputStartResult {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetoothHFP, .defaultToSpeaker])
        try session.setActive(true)

        let captureURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("entrevoix-dictation-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        let recorder = try AVAudioRecorder(url: captureURL, settings: settings)
        guard recorder.prepareToRecord(), recorder.record() else {
            throw KeyboardAudioRecorderError.couldNotStart
        }
        self.recorder = recorder
        activeCaptureURL = captureURL
        if case .device = input { return .fellBackToSystemDefault }
        return .requestedInput
    }

    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        let captureURL = activeCaptureURL
        activeCaptureURL = nil
        deactivateAudioSession()
        return captureURL
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        if let activeCaptureURL { deleteCapture(at: activeCaptureURL) }
        activeCaptureURL = nil
        deactivateAudioSession()
    }

    func deleteLastCapture() {
        if let activeCaptureURL { deleteCapture(at: activeCaptureURL) }
        activeCaptureURL = nil
    }

    func captureSize(at url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    func deleteCapture(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.log("Unable to remove temporary dictation audio: \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.log("Unable to deactivate dictation audio session: \(error.localizedDescription)")
        }
    }

    private let logger = KeyboardDictationLogger()
}

private enum KeyboardAudioRecorderError: LocalizedError {
    case couldNotStart

    var errorDescription: String? {
        String(localized: "Entrevoix could not start audio capture.")
    }
}

@MainActor
private final class KeyboardMicrophonePermission: MicrophonePermissionRequesting {
    func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            break
        @unknown default:
            return false
        }

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

@MainActor
private final class KeyboardTextDelivery: TextDelivering {
    func copy(_: String) {}
    func copyAndPaste(_: String) {}
    func deliver(_: String, mode _: OutputMode) -> TextDeliveryResult { .inserted }
}

@MainActor
private final class KeyboardDictationLogger: LogWriting {
    func log(_ message: String) {
        #if DEBUG
        print("[Keyboard dictation] \(message)")
        #endif
    }
}

private struct KeyboardSpeechTranscriber: SpeechTranscribing {
    private let remote = OpenAITranscriptionService()
    private let apple = AppleSpeechTranscriptionService()

    func preflight(request: TranscriptionRequest) async throws {
        switch request.target {
        case .remote:
            try await remote.preflight(request: request)
        case .apple:
            try await apple.preflight(request: request)
        }
    }

    func transcribe(
        audioURL: URL,
        configuration: ProviderConfiguration,
        apiKey: String,
        prompt: String?,
        language: String?
    ) async throws -> String {
        try await remote.transcribe(
            audioURL: audioURL,
            configuration: configuration,
            apiKey: apiKey,
            prompt: prompt,
            language: language
        )
    }

    func transcribe(audioURL: URL, request: TranscriptionRequest) async throws -> String {
        switch request.target {
        case .remote:
            try await remote.transcribe(audioURL: audioURL, request: request)
        case .apple:
            try await apple.transcribe(audioURL: audioURL, request: request)
        }
    }
}

private struct KeyboardTextCleaner: TextCleaning {
    private let remote = OpenAITextCleanupService()
    private let anthropic = AnthropicTextCleanupService()
    private let apple = AppleFoundationCleanupService()

    func clean(
        text: String,
        configuration: ProviderConfiguration,
        apiKey: String,
        format: CleanupAPIFormat,
        prompt: String
    ) async throws -> String {
        try await remote.clean(
            text: text,
            configuration: configuration,
            apiKey: apiKey,
            format: format,
            prompt: prompt
        )
    }

    func clean(text: String, request: CleanupRequest) async throws -> String {
        switch request.target {
        case .remote:
            try await remote.clean(text: text, request: request)
        case .anthropic:
            try await anthropic.clean(text: text, request: request)
        case .apple:
            try await apple.clean(text: text, request: request)
        case .codex:
            throw ProviderUnavailableError(capability: .ttt, reason: .missingConfiguration)
        }
    }
}
