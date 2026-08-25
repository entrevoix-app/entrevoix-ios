import EntrevoixAppleAdapters
import EntrevoixCore
import SwiftUI

@MainActor
@Observable
final class PreferencesModel {
    private let preferencesStore: any PreferencesStoring
    private let secretStore: any SecretStoring
    private let cleanupLibraryCloudSync: CleanupLibraryCloudSync

    var preferences: AppPreferences
    var recoveryMessage: String?
    var configurationError: String?

    init(
        preferencesStore: any PreferencesStoring = UserDefaultsPreferencesStore(
            defaults: KeyboardHandoffStore.sharedDefaults()
        ),
        secretStore: any SecretStoring = KeychainStore(),
        cleanupLibraryCloudStore: any CleanupLibraryCloudStoring = UnavailableCleanupLibraryCloudStore()
    ) {
        self.preferencesStore = preferencesStore
        self.secretStore = secretStore
        self.cleanupLibraryCloudSync = CleanupLibraryCloudSync(store: cleanupLibraryCloudStore)

        switch preferencesStore.load() {
        case .loaded(let savedPreferences):
            preferences = Self.migrated(savedPreferences)
        case .recovered(let savedPreferences):
            preferences = Self.migrated(savedPreferences)
            recoveryMessage = String(localized: "Your previous settings could not be read, so Entrevoix restored safe defaults.")
        case .incompatible(let schemaVersion):
            preferences = AppPreferences()
            recoveryMessage = "\(String(localized: "These settings were created by a newer version of Entrevoix.")) (\(String(localized: "schema")) \(schemaVersion))."
        }

        cleanupLibraryCloudSync.onRemoteLibrary = { [weak self] library in
            self?.applySharedCleanupLibrary(library)
        }
        cleanupLibraryCloudSync.start()
    }

    func binding<Value>(for keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { self.preferences[keyPath: keyPath] },
            set: { value in
                self.preferences[keyPath: keyPath] = value
                self.persist()
            }
        )
    }

    @discardableResult
    func addOpenAIProvider(apiKey: String) -> Bool {
        addRemoteProvider(RemoteProviderProfile.openAI(), apiKey: apiKey)
    }

    @discardableResult
    func addDictionaryTerm(_ rawTerm: String) -> Bool {
        guard let term = AppPreferences.normalizedDictationDictionary([rawTerm]).first,
              !preferences.dictationDictionary.contains(term) else { return false }

        preferences.dictationDictionary.append(term)
        persist()
        return true
    }

    func removeDictionaryTerms(at offsets: IndexSet) {
        preferences.dictationDictionary.remove(atOffsets: offsets)
        persist()
    }

    @discardableResult
    func addAnthropicProvider(apiKey: String) -> Bool {
        addRemoteProvider(RemoteProviderProfile.anthropic(), apiKey: apiKey)
    }

    @discardableResult
    func addOpenAICompatibleProvider(baseURL: String, apiKey: String) -> Bool {
        var provider = RemoteProviderProfile.compatible()
        provider.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return addRemoteProvider(provider, apiKey: apiKey)
    }

    func reset() {
        preferencesStore.reset()
        preferences = AppPreferences()
        recoveryMessage = nil
        configurationError = nil
    }

    private func persist() {
        preferences.normalizeProviderReferences()
        preferences.normalizeCleanupSelection()
        preferencesStore.save(preferences)
    }

    private func addRemoteProvider(_ provider: RemoteProviderProfile, apiKey: String) -> Bool {
        let validationIssues = provider.validationIssues(apiKey: apiKey)
        guard validationIssues.isEmpty,
              provider.configuration(for: provider.stt == nil ? .ttt : .stt)?.endpointURL != nil else {
            configurationError = String(localized: "Enter a valid http:// or https:// URL.")
            return false
        }

        let previousPreferences = preferences
        preferences.providerCatalog.append(.remote(provider))
        if provider.stt != nil {
            preferences.selectedSTTProviderID = .remote(provider.id)
        }
        if provider.ttt != nil {
            preferences.selectedTTTProviderID = .remote(provider.id)
            preferences.cleanupEnabled = true
        }

        do {
            try secretStore.save([provider.id: apiKey])
            persist()
            configurationError = nil
            return true
        } catch {
            preferences = previousPreferences
            configurationError = String(localized: "The API key could not be stored securely.") + " " + error.localizedDescription
            return false
        }
    }

    private func applySharedCleanupLibrary(_ library: CleanupLibrary) {
        preferences.cleanupPrompts = library.prompts
        preferences.cleanupWorkflows = library.workflows
        preferences.normalizeCleanupSelection()
        if case .prompt(let id) = preferences.activeCleanupSelection,
           let prompt = preferences.cleanupPrompts.first(where: { $0.id == id }) {
            preferences.cleanupPrompt = prompt.instructions
            preferences.cleanupPromptMode = .custom
        }
        persist()
    }

    private static func migrated(_ preferences: AppPreferences) -> AppPreferences {
        PreferencesMigrator.migrate(
            preferences,
            localizedDefaultPrompt: AppPreferences.defaultCleanupPrompt
        )
    }
}

@MainActor
private final class UnavailableCleanupLibraryCloudStore: CleanupLibraryCloudStoring {
    func fetchLibrary() async throws -> CleanupLibrary? {
        throw UnavailableError()
    }

    private struct UnavailableError: Error {}
}
