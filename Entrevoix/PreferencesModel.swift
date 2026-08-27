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
        cleanupLibraryCloudSync.start(
            with: CleanupLibrary(
                prompts: preferences.cleanupPrompts,
                workflows: preferences.cleanupWorkflows
            ),
            seedLocalLibrary: cleanupLibraryDiffersFromDefault
        )
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

    func addAppleProvider() {
        guard !preferences.providerCatalog.contains(where: { $0.id == .apple }) else { return }
        preferences.providerCatalog.append(.apple)
        persist()
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

    func refreshCleanupLibrary() {
        cleanupLibraryCloudSync.refresh()
    }

    func setActiveCleanupPrompt(_ id: UUID?) {
        let selection = id.map(CleanupTransformationSelection.prompt)
        guard selection == nil || preferences.isValidCleanupSelection(selection) else { return }
        preferences.activeCleanupSelection = selection
        synchronizeLegacyPrompt()
        persist()
    }

    @discardableResult
    func saveCleanupPrompt(_ prompt: CleanupPrompt) -> CleanupPromptValidationError? {
        let savedPrompt: CleanupPrompt
        switch CleanupPromptLibrary.validatedSaving(prompt, into: preferences.cleanupPrompts) {
        case .success(let value): savedPrompt = value
        case .failure(let error): return error
        }
        if let index = preferences.cleanupPrompts.firstIndex(where: { $0.id == savedPrompt.id }) {
            preferences.cleanupPrompts[index] = savedPrompt
        } else {
            preferences.cleanupPrompts.append(savedPrompt)
        }
        if preferences.activeCleanupSelection == nil {
            preferences.activeCleanupSelection = .prompt(savedPrompt.id)
        }
        synchronizeLegacyPrompt()
        persist()
        publishCleanupLibrary()
        return nil
    }

    func deleteCleanupPrompt(id: UUID) {
        guard let index = preferences.cleanupPrompts.firstIndex(where: { $0.id == id }) else { return }
        preferences.cleanupPrompts.remove(at: index)
        preferences.cleanupWorkflows = preferences.cleanupWorkflows.map { workflow in
            var value = workflow
            value.promptIDs.removeAll { $0 == id }
            return value
        }
        preferences.normalizeCleanupSelection()
        synchronizeLegacyPrompt()
        persist()
        publishCleanupLibrary()
    }

    func resetPromptLibrary() {
        let prompt = CleanupPrompt(
            id: AppPreferences.defaultCleanupPromptID,
            name: "Standard",
            systemImageName: "wand.and.stars",
            instructions: AppPreferences.defaultCleanupPrompt
        )
        preferences.cleanupPrompts = [prompt]
        preferences.cleanupWorkflows = preferences.cleanupWorkflows.map { workflow in
            var value = workflow
            value.promptIDs = []
            return value
        }
        preferences.activeCleanupSelection = .prompt(prompt.id)
        synchronizeLegacyPrompt()
        persist()
        publishCleanupLibrary()
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
        synchronizeLegacyPrompt()
        persist()
    }

    private func publishCleanupLibrary() {
        cleanupLibraryCloudSync.publish(
            CleanupLibrary(
                prompts: preferences.cleanupPrompts,
                workflows: preferences.cleanupWorkflows
            )
        )
    }

    private func synchronizeLegacyPrompt() {
        if case .prompt(let id) = preferences.activeCleanupSelection,
           let prompt = preferences.cleanupPrompts.first(where: { $0.id == id }) {
            preferences.cleanupPrompt = prompt.instructions
            preferences.cleanupPromptMode = .custom
        }
    }

    private var cleanupLibraryDiffersFromDefault: Bool {
        guard preferences.cleanupWorkflows.isEmpty,
              preferences.cleanupPrompts.count == 1,
              let prompt = preferences.cleanupPrompts.first else { return true }
        return prompt.id != AppPreferences.defaultCleanupPromptID
            || prompt.name != "Standard"
            || prompt.systemImageName != "wand.and.stars"
            || prompt.instructions != AppPreferences.defaultCleanupPrompt
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
    func bootstrap(localLibrary _: CleanupLibrary, seedLocalLibrary _: Bool) async throws -> CleanupLibrary {
        throw UnavailableError()
    }

    func fetchLibrary() async throws -> CleanupLibrary? {
        throw UnavailableError()
    }

    func saveLibrary(_: CleanupLibrary, replacing _: CleanupLibrary?) async throws {
        throw UnavailableError()
    }

    func ensureSubscription(id _: String) async throws {
        throw UnavailableError()
    }

    private struct UnavailableError: Error {}
}
