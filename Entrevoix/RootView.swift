import EntrevoixCore
import SwiftUI

struct RootView: View {
    @Bindable var model: PreferencesModel
    @State private var selectedTab: RootTab = .dictation

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
        case .automatic: "Automatic"
        case .arabic: "Arabic"
        case .chinese: "Chinese"
        case .dutch: "Dutch"
        case .english: "English"
        case .french: "French"
        case .german: "German"
        case .hindi: "Hindi"
        case .indonesian: "Indonesian"
        case .italian: "Italian"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .polish: "Polish"
        case .portuguese: "Portuguese"
        case .russian: "Russian"
        case .spanish: "Spanish"
        case .turkish: "Turkish"
        case .ukrainian: "Ukrainian"
        case .vietnamese: "Vietnamese"
        }
    }
}
