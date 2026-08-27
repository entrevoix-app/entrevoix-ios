import SwiftUI

@main
struct EntrevoixApp: App {
    @UIApplicationDelegateAdaptor(EntrevoixAppDelegate.self) private var appDelegate
    @State private var preferences: PreferencesModel
    @State private var dictationBridge: DictationBridge

    init() {
        let preferences = if NSClassFromString("XCTestCase") == nil,
                             CloudKitSyncAvailability.isAvailable {
            PreferencesModel(cleanupLibraryCloudStore: CloudKitCleanupLibraryStore())
        } else {
            PreferencesModel()
        }
        _preferences = State(initialValue: preferences)
        _dictationBridge = State(initialValue: DictationBridge(preferences: preferences))
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: preferences, dictationBridge: dictationBridge)
        }
    }
}
