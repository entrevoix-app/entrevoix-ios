import EntrevoixCore
import SwiftUI

struct PreferencesView: View {
    @Bindable var model: PreferencesModel
    @State private var isAddingProvider = false
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                transcriptionSection
                cleanupSection
                deliverySection

                Section {
                    Button("Reset settings", role: .destructive) {
                        showingResetConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isAddingProvider) {
                AddProviderView(model: model)
            }
            .confirmationDialog(
                "Reset all settings?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset settings", role: .destructive) {
                    model.reset()
                }
            } message: {
                Text("This removes Entrevoix preferences from this device. API keys remain protected in your Keychain.")
            }
        }
    }

    private var providerSection: some View {
        Section("Provider") {
            if model.preferences.providerCatalog.isEmpty {
                ContentUnavailableView(
                    "No provider configured",
                    systemImage: "network",
                    description: Text("Add an OpenAI provider to enable transcription and text cleanup.")
                )
                Button("Add OpenAI provider") {
                    isAddingProvider = true
                }
            } else {
                ForEach(model.preferences.providerCatalog) { provider in
                    Label(provider.displayName, systemImage: provider.systemImageName)
                }
                Button("Add another OpenAI provider") {
                    isAddingProvider = true
                }
            }
        }
    }

    private var transcriptionSection: some View {
        Section("Transcription") {
            Picker("Language", selection: model.binding(for: \.sttLanguage)) {
                ForEach(TranscriptionLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            Toggle("Trim leading and trailing silence", isOn: model.binding(for: \.trimLeadingAndTrailingSilence))
            Toggle("Reduce long internal pauses", isOn: model.binding(for: \.reduceLongInternalPauses))
        }
    }

    private var cleanupSection: some View {
        Section("Text cleanup") {
            Toggle("Improve transcript after dictation", isOn: model.binding(for: \.cleanupEnabled))
                .disabled(model.preferences.selectedTTTProviderID == nil)
            if model.preferences.selectedTTTProviderID == nil {
                Text("Add a provider with text cleanup support to enable this option.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Picker("If cleanup fails", selection: model.binding(for: \.cleanupFailurePolicy)) {
                ForEach(CleanupFailurePolicy.allCases) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            .disabled(!model.preferences.cleanupEnabled)
        }
    }

    private var deliverySection: some View {
        Section("Delivery") {
            Picker("Send result to", selection: model.binding(for: \.outputMode)) {
                ForEach(OutputMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Toggle("Play feedback sounds", isOn: model.binding(for: \.playFeedbackSounds))
        }
    }
}

private struct AddProviderView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: PreferencesModel
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API key", text: $apiKey)
                        .autocorrectionDisabled()
                } footer: {
                    Text("The key is stored in the device Keychain; it is never written to Entrevoix preferences.")
                }
            }
            .navigationTitle("OpenAI")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        model.addOpenAIProvider(apiKey: apiKey)
                        dismiss()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private extension ProviderCatalogEntry {
    var displayName: String {
        switch self {
        case .apple: "Apple"
        case .codex: "OpenAI (Codex)"
        case .remote(let profile): profile.name
        }
    }

    var systemImageName: String {
        switch self {
        case .apple: "apple.logo"
        case .codex: "sparkles"
        case .remote: "network"
        }
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

private extension CleanupFailurePolicy {
    var displayName: String {
        switch self {
        case .useRawTranscript: "Use the original transcript"
        case .stop: "Stop and show an error"
        }
    }
}

private extension OutputMode {
    var displayName: String {
        switch self {
        case .clipboard: "Clipboard"
        case .paste: "Paste into active text field"
        }
    }
}
