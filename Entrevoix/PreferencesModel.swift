import EntrevoixAppleAdapters
import EntrevoixCore
import EntrevoixOpenAIAdapters
import SwiftUI

@MainActor
@Observable
final class PreferencesModel {
    private let preferencesStore: any PreferencesStoring
    private let secretStore: any SecretStoring
    private let modelCatalog: any RemoteModelDiscovering
    private let codexCredentialsStore: any CodexCredentialsStoring
    private let codexAuthenticator: any CodexAuthenticating
    private let cleanupLibraryCloudSync: CleanupLibraryCloudSync

    var preferences: AppPreferences
    var recoveryMessage: String?
    var configurationError: String?
    var codexConnectionState: CodexConnectionState = .disconnected

    init(
        preferencesStore: any PreferencesStoring = UserDefaultsPreferencesStore(
            defaults: KeyboardHandoffStore.sharedDefaults()
        ),
        secretStore: any SecretStoring = KeychainStore(),
        modelCatalog: any RemoteModelDiscovering = RemoteModelCatalogClient(),
        codexCredentialsStore: any CodexCredentialsStoring = CodexCredentialVault(),
        codexAuthenticator: any CodexAuthenticating = CodexBrowserAuthenticator(),
        cleanupLibraryCloudStore: any CleanupLibraryCloudStoring = UnavailableCleanupLibraryCloudStore()
    ) {
        self.preferencesStore = preferencesStore
        self.secretStore = secretStore
        self.modelCatalog = modelCatalog
        self.codexCredentialsStore = codexCredentialsStore
        self.codexAuthenticator = codexAuthenticator
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

        if preferences.providerCatalog.contains(where: { $0.id == .codex }) {
            refreshCodexConnectionState()
        }
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

    func addCodexProvider() {
        guard !preferences.providerCatalog.contains(where: { $0.id == .codex }) else { return }
        preferences.providerCatalog.append(.codex(CodexProviderProfile()))
        preferences.selectedTTTProviderID = .codex
        preferences.cleanupEnabled = true
        persist()
        refreshCodexConnectionState()
    }

    func setCodexModel(_ codexModel: CodexModel) {
        guard let index = preferences.providerCatalog.firstIndex(where: { $0.id == .codex }),
              case .codex(var profile) = preferences.providerCatalog[index] else { return }
        profile.model = codexModel
        preferences.providerCatalog[index] = .codex(profile)
        persist()
    }

    func connectCodex() {
        guard codexConnectionState != .connecting else { return }
        codexConnectionState = .connecting
        Task { [weak self, codexAuthenticator, codexCredentialsStore] in
            do {
                let credentials = try await codexAuthenticator.connect()
                try Task.checkCancellation()
                try await codexCredentialsStore.saveCodexCredentials(credentials)
                self?.codexConnectionState = .connected
            } catch is CancellationError {
                self?.codexConnectionState = .disconnected
            } catch {
                self?.codexConnectionState = .failed
            }
        }
    }

    func disconnectCodex() {
        guard codexConnectionState != .connecting else { return }
        codexConnectionState = .connecting
        Task { [weak self, codexCredentialsStore] in
            do {
                try await codexCredentialsStore.saveCodexCredentials(nil)
                self?.codexConnectionState = .disconnected
            } catch {
                self?.codexConnectionState = .failed
            }
        }
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

    @discardableResult
    func updateRemoteProvider(_ provider: RemoteProviderProfile, apiKey: String) -> Bool {
        guard let index = preferences.providerCatalog.firstIndex(where: { $0.id == .remote(provider.id) }) else {
            return false
        }

        let updatedProvider = normalized(provider)

        do {
            let existingSecrets = try secretStore.read(profileIDs: remoteProviderIDs)
            let replacementKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let keyToValidate = replacementKey.isEmpty ? existingSecrets[updatedProvider.id] ?? "" : replacementKey
            let existingNames = preferences.providerCatalog.compactMap { entry -> String? in
                guard let profile = entry.remoteProfile, profile.id != updatedProvider.id else { return nil }
                return profile.name
            }
            let validationIssues = updatedProvider.validationIssues(apiKey: keyToValidate, existingNames: existingNames)

            guard validationIssues.isEmpty else {
                configurationError = providerValidationMessage(for: validationIssues[0])
                return false
            }

            guard updatedProvider.configuration(for: updatedProvider.stt == nil ? .ttt : .stt)?.endpointURL != nil else {
                configurationError = String(localized: "Enter a valid http:// or https:// URL.")
                return false
            }

            if !replacementKey.isEmpty {
                var secrets = existingSecrets
                secrets[updatedProvider.id] = replacementKey
                try secretStore.save(secrets)
            }

            preferences.providerCatalog[index] = .remote(updatedProvider)
            persist()
            configurationError = nil
            return true
        } catch {
            configurationError = String(localized: "The API key could not be stored securely.") + " " + error.localizedDescription
            return false
        }
    }

    func loadModels(for profile: RemoteProviderProfile, replacementAPIKey: String) async -> [String]? {
        guard var configuration = profile.configuration(for: profile.stt == nil ? .ttt : .stt) else {
            return nil
        }

        configuration.path = profile.modelsPath
        let suppliedKey = replacementAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let storedKey = try secretStore.read(profileIDs: [profile.id])[profile.id] ?? ""
            let apiKey = suppliedKey.isEmpty ? storedKey : suppliedKey
            return try await modelCatalog.discoverModels(configuration: configuration, apiKey: apiKey)
        } catch {
            return nil
        }
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

    private func refreshCodexConnectionState() {
        Task { [weak self, codexCredentialsStore] in
            do {
                let credentials = try await codexCredentialsStore.readCodexCredentials()
                self?.codexConnectionState = credentials == nil ? .disconnected : .connected
            } catch {
                self?.codexConnectionState = .failed
            }
        }
    }

    private func normalized(_ provider: RemoteProviderProfile) -> RemoteProviderProfile {
        var provider = provider
        provider.name = provider.name.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.baseURL = provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.customHeaderName = provider.customHeaderName.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.modelsPath = provider.modelsPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if var stt = provider.stt {
            stt.path = stt.path.trimmingCharacters(in: .whitespacesAndNewlines)
            stt.model = stt.model.trimmingCharacters(in: .whitespacesAndNewlines)
            provider.stt = stt
        }
        if var ttt = provider.ttt {
            ttt.path = ttt.path.trimmingCharacters(in: .whitespacesAndNewlines)
            ttt.model = ttt.model.trimmingCharacters(in: .whitespacesAndNewlines)
            provider.ttt = ttt
        }
        provider.normalizeFixedProviderFields()
        return provider
    }

    private func providerValidationMessage(for issue: ProviderValidationIssue) -> String {
        switch issue {
        case .missingName:
            String(localized: "A provider name is required.")
        case .duplicateName:
            String(localized: "Provider names must be unique.")
        case .invalidEndpoint:
            String(localized: "Enter a valid http:// or https:// URL.")
        case .missingCapability:
            String(localized: "Select at least one capability.")
        case .missingRoute:
            String(localized: "A route is required for each capability.")
        case .missingModel:
            String(localized: "A model is required.")
        case .missingHeaderName:
            String(localized: "An authentication header name is required.")
        case .missingAPIKey:
            String(localized: "An API key is required for this authentication mode.")
        }
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
            var secrets = try secretStore.read(profileIDs: remoteProviderIDs)
            secrets[provider.id] = apiKey
            try secretStore.save(secrets)
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

    private var remoteProviderIDs: [UUID] {
        preferences.providerCatalog.compactMap(\.remoteProfile?.id)
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
