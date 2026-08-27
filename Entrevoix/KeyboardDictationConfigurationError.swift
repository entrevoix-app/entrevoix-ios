import Foundation

enum KeyboardDictationConfigurationError: LocalizedError {
    case noTranscriptionProvider
    case missingTranscriptionCredential
    case unsupportedTranscriptionProvider
    case noCleanupProvider
    case missingCleanupCredential
    case unsupportedCleanupProvider
    case invalidCleanupSelection
    case couldNotReadCredentials

    var errorDescription: String? {
        switch self {
        case .noTranscriptionProvider:
            String(localized: "Choose a transcription provider before dictating from the keyboard.")
        case .missingTranscriptionCredential:
            String(localized: "The transcription provider is missing its API key.")
        case .unsupportedTranscriptionProvider:
            String(localized: "The selected transcription provider is not available on iPhone.")
        case .noCleanupProvider:
            String(localized: "Choose a cleanup provider or turn off transcript improvement.")
        case .missingCleanupCredential:
            String(localized: "The cleanup provider is missing its API key.")
        case .unsupportedCleanupProvider:
            String(localized: "The selected cleanup provider is not available on iPhone.")
        case .invalidCleanupSelection:
            String(localized: "Choose a valid cleanup prompt or workflow before dictating.")
        case .couldNotReadCredentials:
            String(localized: "Entrevoix could not read the API key needed for dictation.")
        }
    }
}
