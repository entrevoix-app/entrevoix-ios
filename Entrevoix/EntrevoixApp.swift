import SwiftUI

@main
struct EntrevoixApp: App {
    @UIApplicationDelegateAdaptor(EntrevoixAppDelegate.self) private var appDelegate
    @State private var preferences: PreferencesModel

    init() {
        let preferences = if NSClassFromString("XCTestCase") == nil,
                             CloudKitSyncAvailability.isAvailable {
            PreferencesModel(cleanupLibraryCloudStore: CloudKitCleanupLibraryStore())
        } else {
            PreferencesModel()
        }
        _preferences = State(initialValue: preferences)
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: preferences)
        }
    }
}
