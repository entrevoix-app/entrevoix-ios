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

        #expect(model.recoveryMessage?.contains("restored safe defaults") == true)
    }

    @Test("Resets incompatible preferences to safe defaults")
    func resetsIncompatiblePreferences() {
        let model = PreferencesModel(
            preferencesStore: PreferencesStoreSpy(loadResult: .incompatible(schemaVersion: 99)),
            secretStore: SecretStoreSpy()
        )

        #expect(model.preferences == AppPreferences())
        #expect(model.recoveryMessage?.contains("schema 99") == true)
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

    init(saveError: (any Error)? = nil) {
        self.saveError = saveError
    }

    func read(profileIDs: [UUID]) throws -> [UUID: String] {
        [:]
    }

    func save(_ secrets: [UUID: String]) throws {
        if let saveError {
            throw saveError
        }
        saved.append(secrets)
    }
}

private enum TestStoreError: LocalizedError {
    case saveFailed

    var errorDescription: String? {
        "The secure store is unavailable."
    }
}
