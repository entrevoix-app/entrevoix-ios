@testable import Entrevoix
import EntrevoixCore
import Foundation
import Testing

@Suite("Preferences model")
@MainActor
struct PreferencesModelTests {
    @Test("Loads stored preferences without showing a recovery message")
    func loadsStoredPreferences() {
        var preferences = AppPreferences()
        preferences.sttLanguage = .french
        let store = PreferencesStoreSpy(loadResult: .loaded(preferences))

        let model = PreferencesModel(
            preferencesStore: store,
            secretStore: SecretStoreSpy()
        )

        #expect(model.preferences.sttLanguage == .french)
        #expect(model.recoveryMessage == nil)
    }

    @Test("Explains when recovered preferences were restored")
    func explainsRecoveredPreferences() {
        let model = PreferencesModel(
            preferencesStore: PreferencesStoreSpy(loadResult: .recovered(AppPreferences())),
            secretStore: SecretStoreSpy()
        )

        #expect(model.recoveryMessage != nil)
    }

    @Test("Resets incompatible preferences to safe defaults")
    func resetsIncompatiblePreferences() {
        let model = PreferencesModel(
            preferencesStore: PreferencesStoreSpy(loadResult: .incompatible(schemaVersion: 99)),
            secretStore: SecretStoreSpy()
        )

        #expect(model.preferences == AppPreferences())
        #expect(model.recoveryMessage?.contains("99") == true)
    }

    @Test("Bindings persist normalized preferences")
    func bindingsPersistNormalizedPreferences() {
        var preferences = AppPreferences()
        preferences.cleanupEnabled = true
        let store = PreferencesStoreSpy(loadResult: .loaded(preferences))
        let model = PreferencesModel(
            preferencesStore: store,
            secretStore: SecretStoreSpy()
        )

        model.binding(for: \.sttLanguage).wrappedValue = .german

        let savedPreferences = store.saved.last
        #expect(savedPreferences?.sttLanguage == .german)
        #expect(savedPreferences?.cleanupEnabled == false)
    }

    @Test("CloudKit sync is disabled on the simulator")
    func cloudKitSyncAvailabilityDisablesSimulator() {
        #expect(!CloudKitSyncAvailability.isAvailable(isSimulator: true))
        #expect(CloudKitSyncAvailability.isAvailable(isSimulator: false))
    }

    @Test("Adding Apple Foundation persists once without changing provider selections")
    func addingAppleProviderPreservesSelectionsAndAvoidsDuplicates() {
        let remoteProvider = RemoteProviderProfile.openAI()
        var preferences = AppPreferences()
        preferences.providerCatalog = [.remote(remoteProvider)]
        preferences.selectedSTTProviderID = .remote(remoteProvider.id)
        preferences.selectedTTTProviderID = .remote(remoteProvider.id)
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(preferences))
        let secretStore = SecretStoreSpy()
        let model = PreferencesModel(preferencesStore: preferencesStore, secretStore: secretStore)

        model.addAppleProvider()
        model.addAppleProvider()

        #expect(model.preferences.providerCatalog == [.remote(remoteProvider), .apple])
        #expect(model.preferences.selectedSTTProviderID == .remote(remoteProvider.id))
        #expect(model.preferences.selectedTTTProviderID == .remote(remoteProvider.id))
        #expect(preferencesStore.saved == [model.preferences])
        #expect(secretStore.saved.isEmpty)
    }

    @Test("Adding an OpenAI provider persists its key separately")
    func addingOpenAIProviderPersistsKeySeparately() throws {
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(AppPreferences()))
        let secretStore = SecretStoreSpy()
        let model = PreferencesModel(
            preferencesStore: preferencesStore,
            secretStore: secretStore
        )

        model.addOpenAIProvider(apiKey: "test-api-key")

        let entry = try #require(model.preferences.providerCatalog.first)
        guard case .remote(let provider) = entry else {
            Issue.record("Expected an OpenAI remote provider")
            return
        }
        #expect(provider.name == "OpenAI")
        #expect(model.preferences.selectedSTTProviderID == .remote(provider.id))
        #expect(model.preferences.selectedTTTProviderID == .remote(provider.id))
        #expect(model.preferences.cleanupEnabled)
        #expect(secretStore.saved == [[provider.id: "test-api-key"]])
        #expect(preferencesStore.saved.count == 1)
        #expect(model.configurationError == nil)
    }

    @Test("Adding an Anthropic provider preserves STT and selects it for cleanup")
    func addingAnthropicProviderPersistsItsKeySeparately() throws {
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(AppPreferences()))
        let secretStore = SecretStoreSpy()
        let model = PreferencesModel(preferencesStore: preferencesStore, secretStore: secretStore)
        model.addOpenAIProvider(apiKey: "openai-key")
        let sttProviderID = model.preferences.selectedSTTProviderID

        model.addAnthropicProvider(apiKey: "anthropic-key")

        let entry = try #require(model.preferences.providerCatalog.last)
        guard case .remote(let provider) = entry else {
            Issue.record("Expected an Anthropic remote provider")
            return
        }
        #expect(provider.kind == .anthropic)
        #expect(provider.stt == nil)
        #expect(provider.ttt?.format == .anthropicMessages)
        #expect(model.preferences.selectedSTTProviderID == sttProviderID)
        #expect(model.preferences.selectedTTTProviderID == .remote(provider.id))
        #expect(model.preferences.cleanupEnabled)
        #expect(secretStore.saved.last?[sttProviderID?.remoteID ?? UUID()] == "openai-key")
        #expect(secretStore.saved.last?[provider.id] == "anthropic-key")
    }

    @Test("Adding an OpenAI-compatible provider persists its address and key")
    func addingOpenAICompatibleProviderPersistsAddressAndKey() throws {
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(AppPreferences()))
        let secretStore = SecretStoreSpy()
        let model = PreferencesModel(preferencesStore: preferencesStore, secretStore: secretStore)

        let didAdd = model.addOpenAICompatibleProvider(
            baseURL: " https://models.example.com/v1 ",
            apiKey: "compatible-key"
        )

        let entry = try #require(model.preferences.providerCatalog.first)
        guard case .remote(let provider) = entry else {
            Issue.record("Expected an OpenAI-compatible remote provider")
            return
        }
        #expect(didAdd)
        #expect(provider.kind == .openAICompatible)
        #expect(provider.baseURL == "https://models.example.com/v1")
        #expect(provider.stt != nil)
        #expect(provider.ttt == nil)
        #expect(model.preferences.selectedSTTProviderID == .remote(provider.id))
        #expect(model.preferences.selectedTTTProviderID == nil)
        #expect(!model.preferences.cleanupEnabled)
        #expect(secretStore.saved == [[provider.id: "compatible-key"]])
        #expect(preferencesStore.saved.count == 1)
    }

    @Test("An invalid compatible provider address does not save configuration or its key")
    func invalidOpenAICompatibleProviderAddressDoesNotPersist() {
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(AppPreferences()))
        let secretStore = SecretStoreSpy()
        let model = PreferencesModel(preferencesStore: preferencesStore, secretStore: secretStore)

        let didAdd = model.addOpenAICompatibleProvider(baseURL: "ftp://models.example.com", apiKey: "super-secret")

        #expect(!didAdd)
        #expect(model.preferences.providerCatalog.isEmpty)
        #expect(model.preferences.selectedSTTProviderID == nil)
        #expect(secretStore.saved.isEmpty)
        #expect(preferencesStore.saved.isEmpty)
        #expect(model.configurationError?.contains("super-secret") == false)
    }

    @Test("Editing a remote provider preserves its identity, selections, and current key")
    func editingRemoteProviderPreservesSelectionsAndCurrentKey() throws {
        var provider = RemoteProviderProfile.compatible()
        provider.baseURL = "https://old.example.com/v1"
        var preferences = AppPreferences()
        preferences.providerCatalog = [.remote(provider)]
        preferences.selectedSTTProviderID = .remote(provider.id)
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(preferences))
        let secretStore = SecretStoreSpy(secrets: [provider.id: "current-key"])
        let model = PreferencesModel(preferencesStore: preferencesStore, secretStore: secretStore)

        provider.baseURL = " https://new.example.com/v1 "
        let didUpdate = model.updateRemoteProvider(provider, apiKey: "")

        let entry = try #require(model.preferences.providerCatalog.first)
        guard case .remote(let savedProvider) = entry else {
            Issue.record("Expected an edited remote provider")
            return
        }
        #expect(didUpdate)
        #expect(savedProvider.id == provider.id)
        #expect(savedProvider.baseURL == "https://new.example.com/v1")
        #expect(model.preferences.selectedSTTProviderID == .remote(provider.id))
        #expect(secretStore.saved.isEmpty)
        #expect(preferencesStore.saved.last?.providerCatalog == [.remote(savedProvider)])
    }

    @Test("Replacing a provider key retains the keys of other configured providers")
    func replacingProviderKeyRetainsOtherProviderKeys() {
        let openAI = RemoteProviderProfile.openAI()
        var compatible = RemoteProviderProfile.compatible()
        compatible.baseURL = "https://models.example.com/v1"
        var preferences = AppPreferences()
        preferences.providerCatalog = [.remote(openAI), .remote(compatible)]
        let secretStore = SecretStoreSpy(secrets: [openAI.id: "openai-key", compatible.id: "old-compatible-key"])
        let model = PreferencesModel(
            preferencesStore: PreferencesStoreSpy(loadResult: .loaded(preferences)),
            secretStore: secretStore
        )

        compatible.baseURL = "https://updated.example.com/v1"
        #expect(model.updateRemoteProvider(compatible, apiKey: "new-compatible-key"))
        #expect(secretStore.saved.last?[openAI.id] == "openai-key")
        #expect(secretStore.saved.last?[compatible.id] == "new-compatible-key")
    }

    @Test("An Anthropic keychain failure restores the previous cleanup selection")
    func anthropicKeychainFailureRestoresConfiguration() {
        var preferences = AppPreferences()
        let openAI = RemoteProviderProfile.openAI()
        preferences.providerCatalog = [.remote(openAI)]
        preferences.selectedSTTProviderID = .remote(openAI.id)
        preferences.selectedTTTProviderID = .remote(openAI.id)
        preferences.cleanupEnabled = true
        let model = PreferencesModel(
            preferencesStore: PreferencesStoreSpy(loadResult: .loaded(preferences)),
            secretStore: SecretStoreSpy(saveError: TestStoreError.saveFailed)
        )

        model.addAnthropicProvider(apiKey: "super-secret")

        #expect(model.preferences.providerCatalog == [.remote(openAI)])
        #expect(model.preferences.selectedTTTProviderID == .remote(openAI.id))
        #expect(model.preferences.cleanupEnabled)
        #expect(model.configurationError?.contains("super-secret") == false)
    }

    @Test("A keychain failure rolls back provider configuration without exposing the key")
    func keychainFailureRollsBackProviderConfiguration() {
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(AppPreferences()))
        let secretStore = SecretStoreSpy(saveError: TestStoreError.saveFailed)
        let model = PreferencesModel(
            preferencesStore: preferencesStore,
            secretStore: secretStore
        )

        model.addOpenAIProvider(apiKey: "super-secret")

        #expect(model.preferences.providerCatalog.isEmpty)
        #expect(model.preferences.selectedSTTProviderID == nil)
        #expect(model.preferences.selectedTTTProviderID == nil)
        #expect(model.preferences.cleanupEnabled == false)
        #expect(preferencesStore.saved.isEmpty)
        #expect(model.configurationError?.contains("super-secret") == false)
    }

    @Test("Reset removes preferences but leaves stored API keys alone")
    func resetRemovesPreferencesButKeepsKeys() {
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(AppPreferences()))
        let secretStore = SecretStoreSpy()
        let model = PreferencesModel(
            preferencesStore: preferencesStore,
            secretStore: secretStore
        )
        model.addOpenAIProvider(apiKey: "test-api-key")

        model.reset()

        #expect(preferencesStore.resetCount == 1)
        #expect(model.preferences == AppPreferences())
        #expect(secretStore.saved.count == 1)
        #expect(model.recoveryMessage == nil)
        #expect(model.configurationError == nil)
    }

    @Test("Prompt CRUD persists changes and keeps workflows consistent")
    func promptCRUDPersistsAndRepairsWorkflows() {
        let original = CleanupPrompt(name: "Original", systemImageName: "sparkles", instructions: "Original text")
        let workflow = CleanupWorkflow(name: "Chain", promptIDs: [original.id])
        let store = PreferencesStoreSpy(loadResult: .loaded(AppPreferences(
            cleanupPrompts: [original],
            cleanupWorkflows: [workflow],
            activeCleanupSelection: .prompt(original.id)
        )))
        let model = PreferencesModel(preferencesStore: store, secretStore: SecretStoreSpy())

        let edited = CleanupPrompt(id: original.id, name: "Edited", systemImageName: "quote.bubble", instructions: "Edited text")
        #expect(model.saveCleanupPrompt(edited) == nil)
        #expect(model.preferences.cleanupPrompts == [edited])
        #expect(model.preferences.cleanupPrompt == "Edited text")

        model.deleteCleanupPrompt(id: edited.id)
        #expect(model.preferences.cleanupPrompts.isEmpty)
        #expect(model.preferences.cleanupWorkflows.first?.promptIDs.isEmpty == true)
        #expect(model.preferences.activeCleanupSelection == nil)

        model.resetPromptLibrary()
        #expect(model.preferences.cleanupPrompts.count == 1)
        #expect(model.preferences.activeCleanupSelection == .prompt(AppPreferences.defaultCleanupPromptID))
        #expect(store.saved.count >= 3)
    }

    @Test("Cloud bootstrap applies the remote prompt library", .timeLimit(.minutes(1)))
    func cloudBootstrapAppliesRemotePromptLibrary() async {
        let id = UUID()
        let localPrompt = CleanupPrompt(id: id, name: "Local", systemImageName: "sparkles", instructions: "Local text")
        let remotePrompt = CleanupPrompt(id: id, name: "Remote", systemImageName: "quote.bubble", instructions: "Remote text")
        let remoteWorkflow = CleanupWorkflow(name: "Remote workflow", promptIDs: [id])
        let remoteLibrary = CleanupLibrary(prompts: [remotePrompt], workflows: [remoteWorkflow])
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(AppPreferences(
            cleanupPrompts: [localPrompt],
            activeCleanupSelection: .prompt(id)
        )))
        let cloudStore = CleanupLibraryCloudStoreSpy(bootstrapResult: .success(remoteLibrary))
        let model = PreferencesModel(
            preferencesStore: preferencesStore,
            secretStore: SecretStoreSpy(),
            cleanupLibraryCloudStore: cloudStore
        )

        await cloudStore.waitForBootstrap()

        #expect(cloudStore.subscriptionIDs == [CleanupLibraryCloudSync.subscriptionID])
        #expect(model.preferences.cleanupPrompts == [remotePrompt])
        #expect(model.preferences.cleanupWorkflows == [remoteWorkflow])
        #expect(model.preferences.cleanupPrompt == remotePrompt.instructions)
        #expect(preferencesStore.saved.last?.cleanupPrompts == [remotePrompt])
    }

    @Test("Adding and editing prompts publish the full CloudKit library", .timeLimit(.minutes(1)))
    func savingPromptsPublishesCloudLibrary() async {
        let original = CleanupPrompt(name: "Original", systemImageName: "sparkles", instructions: "Original text")
        let initialLibrary = CleanupLibrary(prompts: [original], workflows: [])
        let cloudStore = CleanupLibraryCloudStoreSpy(bootstrapResult: .success(initialLibrary))
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(AppPreferences(
            cleanupPrompts: [original],
            activeCleanupSelection: .prompt(original.id)
        )))
        let model = PreferencesModel(
            preferencesStore: preferencesStore,
            secretStore: SecretStoreSpy(),
            cleanupLibraryCloudStore: cloudStore
        )
        await cloudStore.waitForBootstrap()

        let added = CleanupPrompt(name: "Added", systemImageName: "doc.text", instructions: "Added text")
        #expect(model.saveCleanupPrompt(added) == nil)
        await cloudStore.waitForSavedLibraries(count: 1)

        #expect(cloudStore.savedLibraries[0].prompts == [original, added])
        #expect(cloudStore.replacedLibraries[0] == initialLibrary)

        let edited = CleanupPrompt(
            id: added.id,
            name: "Edited",
            systemImageName: "quote.bubble",
            instructions: "Edited text"
        )
        #expect(model.saveCleanupPrompt(edited) == nil)
        await cloudStore.waitForSavedLibraries(count: 2)

        #expect(model.preferences.cleanupPrompts == [original, edited])
        #expect(preferencesStore.saved.last?.cleanupPrompts == [original, edited])
        #expect(cloudStore.savedLibraries[1].prompts == [original, edited])
        #expect(cloudStore.replacedLibraries[1]?.prompts == [original, added])
    }

    @Test("Refreshing applies remote changes without republishing them", .timeLimit(.minutes(1)))
    func refreshAppliesRemotePromptLibraryWithoutRepublishing() async {
        let id = UUID()
        let initialPrompt = CleanupPrompt(id: id, name: "Initial", systemImageName: "sparkles", instructions: "Initial text")
        let refreshedPrompt = CleanupPrompt(id: id, name: "Refreshed", systemImageName: "quote.bubble", instructions: "Refreshed text")
        let initialLibrary = CleanupLibrary(prompts: [initialPrompt], workflows: [])
        let refreshedLibrary = CleanupLibrary(prompts: [refreshedPrompt], workflows: [])
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(AppPreferences(
            cleanupPrompts: [initialPrompt],
            activeCleanupSelection: .prompt(id)
        )))
        let cloudStore = CleanupLibraryCloudStoreSpy(
            bootstrapResult: .success(initialLibrary),
            fetchResult: .success(refreshedLibrary)
        )
        let model = PreferencesModel(
            preferencesStore: preferencesStore,
            secretStore: SecretStoreSpy(),
            cleanupLibraryCloudStore: cloudStore
        )
        await cloudStore.waitForBootstrap()

        model.refreshCleanupLibrary()
        await cloudStore.waitForFetches(count: 1)

        #expect(model.preferences.cleanupPrompts == [refreshedPrompt])
        #expect(model.preferences.cleanupPrompt == refreshedPrompt.instructions)
        #expect(preferencesStore.saved.last?.cleanupPrompts == [refreshedPrompt])
        #expect(cloudStore.savedLibraries.isEmpty)
    }

    @Test("CloudKit publication failures keep prompt edits stored locally", .timeLimit(.minutes(1)))
    func cloudPublicationFailureKeepsPromptEditsLocally() async {
        let original = CleanupPrompt(name: "Original", systemImageName: "sparkles", instructions: "Original text")
        let initialLibrary = CleanupLibrary(prompts: [original], workflows: [])
        let preferencesStore = PreferencesStoreSpy(loadResult: .loaded(AppPreferences(
            cleanupPrompts: [original],
            activeCleanupSelection: .prompt(original.id)
        )))
        let cloudStore = CleanupLibraryCloudStoreSpy(
            bootstrapResult: .success(initialLibrary),
            saveResult: .failure(TestStoreError.saveFailed)
        )
        let model = PreferencesModel(
            preferencesStore: preferencesStore,
            secretStore: SecretStoreSpy(),
            cleanupLibraryCloudStore: cloudStore
        )
        await cloudStore.waitForBootstrap()

        let edited = CleanupPrompt(
            id: original.id,
            name: "Edited",
            systemImageName: "quote.bubble",
            instructions: "Edited text"
        )
        #expect(model.saveCleanupPrompt(edited) == nil)
        await cloudStore.waitForSavedLibraries(count: 1)

        #expect(model.preferences.cleanupPrompts == [edited])
        #expect(model.preferences.cleanupPrompt == edited.instructions)
        #expect(preferencesStore.saved.last?.cleanupPrompts == [edited])
    }
}

private final class PreferencesStoreSpy: PreferencesStoring {
    let loadResult: PreferencesLoadResult
    private(set) var saved: [AppPreferences] = []
    private(set) var resetCount = 0

    init(loadResult: PreferencesLoadResult) {
        self.loadResult = loadResult
    }

    func load() -> PreferencesLoadResult {
        loadResult
    }

    func save(_ preferences: AppPreferences) {
        saved.append(preferences)
    }

    func reset() {
        resetCount += 1
    }
}

private final class SecretStoreSpy: SecretStoring {
    let saveError: (any Error)?
    private(set) var saved: [[UUID: String]] = []
    private var secrets: [UUID: String]

    init(secrets: [UUID: String] = [:], saveError: (any Error)? = nil) {
        self.secrets = secrets
        self.saveError = saveError
    }

    func read(profileIDs: [UUID]) throws -> [UUID: String] {
        secrets.filter { profileIDs.contains($0.key) }
    }

    func save(_ secrets: [UUID: String]) throws {
        if let saveError {
            throw saveError
        }
        self.secrets = secrets
        saved.append(secrets)
    }
}

@MainActor
private final class CleanupLibraryCloudStoreSpy: CleanupLibraryCloudStoring {
    private let bootstrapResult: Result<CleanupLibrary, any Error>
    private let fetchResult: Result<CleanupLibrary?, any Error>
    private let saveResult: Result<Void, any Error>

    private(set) var subscriptionIDs: [String] = []
    private(set) var savedLibraries: [CleanupLibrary] = []
    private(set) var replacedLibraries: [CleanupLibrary?] = []
    private var bootstrapWaiters: [CheckedContinuation<Void, Never>] = []
    private var fetchWaiters: [CheckedContinuation<Void, Never>] = []
    private var saveWaiters: [CheckedContinuation<Void, Never>] = []
    private var didBootstrap = false
    private var fetchCount = 0

    init(
        bootstrapResult: Result<CleanupLibrary, any Error>,
        fetchResult: Result<CleanupLibrary?, any Error> = .success(nil),
        saveResult: Result<Void, any Error> = .success(())
    ) {
        self.bootstrapResult = bootstrapResult
        self.fetchResult = fetchResult
        self.saveResult = saveResult
    }

    func bootstrap(localLibrary _: CleanupLibrary, seedLocalLibrary _: Bool) async throws -> CleanupLibrary {
        didBootstrap = true
        resume(&bootstrapWaiters)
        return try bootstrapResult.get()
    }

    func fetchLibrary() async throws -> CleanupLibrary? {
        fetchCount += 1
        resume(&fetchWaiters)
        return try fetchResult.get()
    }

    func saveLibrary(_ library: CleanupLibrary, replacing previousLibrary: CleanupLibrary?) async throws {
        savedLibraries.append(library)
        replacedLibraries.append(previousLibrary)
        resume(&saveWaiters)
        try saveResult.get()
    }

    func ensureSubscription(id: String) async throws {
        subscriptionIDs.append(id)
    }

    func waitForBootstrap() async {
        guard !didBootstrap else { return }
        await withCheckedContinuation { bootstrapWaiters.append($0) }
    }

    func waitForFetches(count: Int) async {
        guard fetchCount < count else { return }
        await withCheckedContinuation { fetchWaiters.append($0) }
    }

    func waitForSavedLibraries(count: Int) async {
        guard savedLibraries.count < count else { return }
        await withCheckedContinuation { saveWaiters.append($0) }
    }

    private func resume(_ waiters: inout [CheckedContinuation<Void, Never>]) {
        let waiting = waiters
        waiters.removeAll()
        waiting.forEach { $0.resume() }
    }
}

private enum TestStoreError: LocalizedError {
    case saveFailed

    var errorDescription: String? {
        "The secure store is unavailable."
    }
}
