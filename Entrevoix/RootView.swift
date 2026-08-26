import EntrevoixCore
import SwiftUI
import Combine

struct RootView: View {
    @Bindable var model: PreferencesModel
    @State private var selectedTab: RootTab = .dictation
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            DictationHomeView(model: model) {
                selectedTab = .settings
            }
            .tabItem {
                Label("Dictation", systemImage: "mic.fill")
            }
            .tag(RootTab.dictation)

            PreferencesView(model: model)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(RootTab.settings)
        }
        .alert("Settings restored", isPresented: recoveryAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.recoveryMessage ?? "")
        }
        .alert("Configuration error", isPresented: configurationErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.configurationError ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .cleanupLibraryCloudChange)) { _ in
            model.refreshCleanupLibrary()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refreshCleanupLibrary() }
        }
    }

    private var recoveryAlert: Binding<Bool> {
        Binding(
            get: { model.recoveryMessage != nil },
            set: { isPresented in
                if !isPresented { model.recoveryMessage = nil }
            }
        )
    }

    private var configurationErrorAlert: Binding<Bool> {
        Binding(
            get: { model.configurationError != nil },
            set: { isPresented in
                if !isPresented { model.configurationError = nil }
            }
        )
    }
}

private enum RootTab: Hashable {
    case dictation
    case settings
}

private struct DictationHomeView: View {
    @Bindable var model: PreferencesModel
    let showSettings: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Ready when you are")
                        .font(.title2.weight(.semibold))
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if model.preferences.selectedSTTProviderID == nil {
                    Button(action: showSettings) {
                        Label("Configure a provider", systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Label(model.preferences.sttLanguage.displayName, systemImage: "globe")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Entrevoix")
        }
    }

    private var statusMessage: String {
        if model.preferences.selectedSTTProviderID == nil {
            return "Add a transcription provider in Settings before starting your first dictation."
        }
        return "Your iOS recording controls will appear here."
    }
}

private extension TranscriptionLanguage {
    var displayName: String {
        switch self {
        case .automatic: String(localized: "Automatic")
        case .arabic: String(localized: "Arabic")
        case .chinese: String(localized: "Chinese")
        case .dutch: String(localized: "Dutch")
        case .english: String(localized: "English")
        case .french: String(localized: "French")
        case .german: String(localized: "German")
        case .hindi: String(localized: "Hindi")
        case .indonesian: String(localized: "Indonesian")
        case .italian: String(localized: "Italian")
        case .japanese: String(localized: "Japanese")
        case .korean: String(localized: "Korean")
        case .polish: String(localized: "Polish")
        case .portuguese: String(localized: "Portuguese")
        case .russian: String(localized: "Russian")
        case .spanish: String(localized: "Spanish")
        case .turkish: String(localized: "Turkish")
        case .ukrainian: String(localized: "Ukrainian")
        case .vietnamese: String(localized: "Vietnamese")
        }
    }
}
