import SwiftUI

@main
struct EntrevoixApp: App {
    @State private var preferences: PreferencesModel

    init() {
        _preferences = State(
            initialValue: NSClassFromString("XCTestCase") == nil
                ? PreferencesModel(cleanupLibraryCloudStore: CloudKitCleanupLibraryStore())
                : PreferencesModel()
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: preferences)
        }
    }
}
