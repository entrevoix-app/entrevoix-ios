import Foundation

/// The durable, App Group-backed contract between the containing app and the
/// keyboard extension. It carries only control state and final text — never
/// audio, credentials, or provider configuration.
struct KeyboardDictationRequest: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let createdAt: Date

    init(id: UUID = UUID(), createdAt: Date = .now) {
        self.id = id
        self.createdAt = createdAt
    }
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

    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func writeRequest(_ request: KeyboardDictationRequest) {
        write(request, forKey: requestKey)
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

    private static func write<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        sharedDefaults().set(data, forKey: key)
    }

    private static func read<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = sharedDefaults().data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
