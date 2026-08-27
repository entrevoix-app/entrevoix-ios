import CoreFoundation
import Foundation

/// The durable, App Group-backed contract between the containing app and the
/// keyboard extension. It carries only control state and final text — never
/// audio, credentials, or provider configuration.
enum KeyboardDictationCommand: String, Codable, Equatable, Sendable {
    case start
    case stop
    case cancel
}

struct KeyboardDictationRequest: Codable, Equatable, Sendable, Identifiable {
    static let currentVersion = 1

    let id: UUID
    let version: Int
    let command: KeyboardDictationCommand
    let createdAt: Date

    init(
        id: UUID = UUID(),
        version: Int = Self.currentVersion,
        command: KeyboardDictationCommand = .start,
        createdAt: Date = .now
    ) {
        self.id = id
        self.version = version
        self.command = command
        self.createdAt = createdAt
    }

    var isSupported: Bool { version == Self.currentVersion }
}

enum KeyboardDictationState: String, Codable, Equatable, Sendable {
    case requested
    case recording
    case transcribing
    case completed
    case failed
    case cancelled
}

struct KeyboardDictationResult: Codable, Equatable, Sendable {
    let requestID: UUID
    let state: KeyboardDictationState
    let transcript: String?
    let message: String?

    init(
        requestID: UUID,
        state: KeyboardDictationState,
        transcript: String? = nil,
        message: String? = nil
    ) {
        self.requestID = requestID
        self.state = state
        self.transcript = transcript
        self.message = message
    }
}

enum KeyboardHandoffStore {
    static let appGroupIdentifier = "group.app.entrevoix.ios"

    private static let requestKey = "keyboard.dictation.request"
    private static let resultKey = "keyboard.dictation.result"
    nonisolated fileprivate static let commandNotificationName = CFNotificationName(
        rawValue: "app.entrevoix.ios.keyboard-dictation-command" as CFString
    )

    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func writeRequest(_ request: KeyboardDictationRequest) {
        write(request, forKey: requestKey)
    }

    /// Wakes a running containing-app process after a command is written to the
    /// App Group. The durable request remains the source of truth, so a missed
    /// notification never changes command semantics.
    static func notifyCommand() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            commandNotificationName,
            nil,
            nil,
            true
        )
    }

    static func observeCommands(_ handler: @escaping @Sendable () -> Void) -> KeyboardHandoffCommandObserver {
        KeyboardHandoffCommandObserver(handler: handler)
    }

    static func readRequest() -> KeyboardDictationRequest? {
        read(KeyboardDictationRequest.self, forKey: requestKey)
    }

    static func writeResult(_ result: KeyboardDictationResult) {
        write(result, forKey: resultKey)
    }

    static func readResult() -> KeyboardDictationResult? {
        read(KeyboardDictationResult.self, forKey: resultKey)
    }

    static func clearResult(for requestID: UUID) {
        guard readResult()?.requestID == requestID else { return }
        sharedDefaults().removeObject(forKey: resultKey)
    }

    static func clearRequest(for requestID: UUID) {
        guard readRequest()?.id == requestID else { return }
        sharedDefaults().removeObject(forKey: requestKey)
    }

    static func clearHandoff(for requestID: UUID) {
        clearRequest(for: requestID)
        clearResult(for: requestID)
    }

    private static func write<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        sharedDefaults().set(data, forKey: key)
    }

    private static func read<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = sharedDefaults().data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

final class KeyboardHandoffCommandObserver {
    private var handler: @Sendable () -> Void

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            Self.receiveCommand,
            KeyboardHandoffStore.commandNotificationName.rawValue,
            nil,
            .deliverImmediately
        )
    }

    func replaceHandler(with handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            KeyboardHandoffStore.commandNotificationName,
            nil
        )
    }

    private static let receiveCommand: CFNotificationCallback = { _, observer, _, _, _ in
        guard let observer else { return }
        let receiver = Unmanaged<KeyboardHandoffCommandObserver>
            .fromOpaque(observer)
            .takeUnretainedValue()
        receiver.handler()
    }
}
