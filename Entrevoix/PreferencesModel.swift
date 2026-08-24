import EntrevoixAppleAdapters
import EntrevoixCore
import SwiftUI

@MainActor
@Observable
final class PreferencesModel {
    private let preferencesStore: any PreferencesStoring
    private let secretStore: any SecretStoring

    var preferences: AppPreferences
    var recoveryMessage: String?
    var configurationError: String?

    init(
        preferencesStore: any PreferencesStoring = UserDefaultsPreferencesStore(
            defaults: KeyboardHandoffStore.sharedDefaults()
        ),
        secretStore: any SecretStoring = KeychainStore()
    ) {
        self.preferencesStore = preferencesStore
        self.secretStore = secretStore

        switch preferencesStore.load() {
        case .loaded(let savedPreferences):
            preferences = Self.migrated(savedPreferences)
        case .recovered(let savedPreferences):
            preferences = Self.migrated(savedPreferences)
            recoveryMessage = "Your previous settings could not be read, so Entrevoix restored safe defaults."
        case .incompatible(let schemaVersion):
            preferences = AppPreferences()
            recoveryMessage = "These settings were created by a newer version of Entrevoix (schema \(schemaVersion))."
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

    func addOpenAIProvider(apiKey: String) {
        var provider = RemoteProviderProfile.openAI()
        provider.name = "OpenAI"
        preferences.providerCatalog.append(.remote(provider))
        preferences.selectedSTTProviderID = .remote(provider.id)
        preferences.selectedTTTProviderID = .remote(provider.id)
        preferences.cleanupEnabled = true

        do {
            try secretStore.save([provider.id: apiKey])
            persist()
        } catch {
            preferences.providerCatalog.removeAll { $0.id == .remote(provider.id) }
            preferences.selectedSTTProviderID = nil
            preferences.selectedTTTProviderID = nil
            preferences.cleanupEnabled = false
            configurationError = "The API key could not be stored securely. \(error.localizedDescription)"
        }
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

    private static func migrated(_ preferences: AppPreferences) -> AppPreferences {
        PreferencesMigrator.migrate(
            preferences,
            localizedDefaultPrompt: AppPreferences.defaultCleanupPrompt
        )
    }
}
