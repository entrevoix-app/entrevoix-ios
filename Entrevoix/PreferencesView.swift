import EntrevoixCore
import SwiftUI

struct PreferencesView: View {
    @Bindable var model: PreferencesModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: SettingsSection? = .general

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                SettingsSidebar(selection: $selection)
                    .navigationTitle("Settings")
            } detail: {
                SettingsDetail(section: selection ?? .general, model: model)
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack {
                SettingsCatalog(model: model)
            }
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case providers
    case transcription
    case cleanup
    case dictationDictionary
    case prompts
    case workflows

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .providers: "Providers"
        case .transcription: "STT Transcription"
        case .cleanup: "TTT Cleanup"
        case .dictationDictionary: "Dictation Dictionary"
        case .prompts: "Prompts"
        case .workflows: "Workflows"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .providers: "network"
        case .transcription: "waveform"
        case .cleanup: "wand.and.stars"
        case .dictationDictionary: "character.book.closed"
        case .prompts: "text.badge.checkmark"
        case .workflows: "point.3.connected.trianglepath.dotted"
        }
    }
}

private struct SettingsCatalog: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        List {
            Section("Application") { destination(.general) }
            Section("Processing") {
                destination(.providers)
                destination(.transcription)
                destination(.cleanup)
            }
            Section("Customization") {
                destination(.dictationDictionary)
                destination(.prompts)
                destination(.workflows)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationDestination(for: SettingsSection.self) { section in
            SettingsDetail(section: section, model: model)
        }
    }

    private func destination(_ section: SettingsSection) -> some View {
        NavigationLink(value: section) {
            Label(section.title, systemImage: section.systemImage)
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection?

    var body: some View {
        List(selection: $selection) {
            Section("Application") { row(.general) }
            Section("Processing") {
                row(.providers)
                row(.transcription)
                row(.cleanup)
            }
            Section("Customization") {
                row(.dictationDictionary)
                row(.prompts)
                row(.workflows)
            }
        }
        .listStyle(.sidebar)
    }

    private func row(_ section: SettingsSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .tag(section)
    }
}

private struct SettingsDetail: View {
    let section: SettingsSection
    @Bindable var model: PreferencesModel

    var body: some View {
        Group {
            switch section {
            case .general: GeneralSettingsView(model: model)
            case .providers: ProvidersSettingsView(model: model)
            case .transcription: TranscriptionSettingsView(model: model)
            case .cleanup: CleanupSettingsView(model: model)
            case .dictationDictionary: DictationDictionarySettingsView(model: model)
            case .prompts: PromptLibrarySettingsView(model: model)
            case .workflows: WorkflowLibrarySettingsView(model: model)
            }
        }
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var model: PreferencesModel
    @State private var isResetConfirmationPresented = false

    var body: some View {
        Form {
            Section("Audio Input") {
                Toggle("Trim leading and trailing silence", isOn: model.binding(for: \.trimLeadingAndTrailingSilence))
                Toggle("Reduce long internal pauses", isOn: model.binding(for: \.reduceLongInternalPauses))
            }
            Section("Delivery") {
                Picker("Send result to", selection: model.binding(for: \.outputMode)) {
                    ForEach(OutputMode.allCases) { mode in Text(mode.displayName).tag(mode) }
                }
                Toggle("Play feedback sounds", isOn: model.binding(for: \.playFeedbackSounds))
            }
            Section {
                Button("Reset settings", role: .destructive) { isResetConfirmationPresented = true }
            }
        }
        .confirmationDialog("Reset all settings?", isPresented: $isResetConfirmationPresented, titleVisibility: .visible) {
            Button("Reset settings", role: .destructive) { model.reset() }
        } message: {
            Text("This removes Entrevoix preferences from this device. API keys remain protected in your Keychain.")
        }
    }
}

private struct ProvidersSettingsView: View {
    @Bindable var model: PreferencesModel
    @State private var isAddingProvider = false

    var body: some View {
        Form {
            Section {
                if model.preferences.providerCatalog.isEmpty {
                    ContentUnavailableView("No provider configured", systemImage: "network", description: Text("Add an OpenAI provider for transcription, or Anthropic for text cleanup."))
                    Button("Add provider") { isAddingProvider = true }
                } else {
                    ForEach(model.preferences.providerCatalog) { provider in
                        Label(provider.displayName, systemImage: provider.systemImageName)
                    }
                    Button("Add another provider") { isAddingProvider = true }
                }
            }
        }
        .sheet(isPresented: $isAddingProvider) { AddProviderView(model: model) }
    }
}

private struct TranscriptionSettingsView: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: model.binding(for: \.sttLanguage)) {
                    ForEach(TranscriptionLanguage.allCases) { language in Text(language.displayName).tag(language) }
                }
            } footer: {
                Text("Choose the language Entrevoix uses for transcription.")
            }
        }
    }
}

private struct CleanupSettingsView: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        Form {
            Section {
                Toggle("Improve transcript after dictation", isOn: model.binding(for: \.cleanupEnabled))
                    .disabled(model.preferences.selectedTTTProviderID == nil)
                if model.preferences.selectedTTTProviderID == nil {
                    Text("Add a provider with text cleanup support to enable this option.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Picker("If cleanup fails", selection: model.binding(for: \.cleanupFailurePolicy)) {
                    ForEach(CleanupFailurePolicy.allCases) { policy in Text(policy.displayName).tag(policy) }
                }
                .disabled(!model.preferences.cleanupEnabled)
            }
        }
    }
}

private struct DictationDictionarySettingsView: View {
    @Bindable var model: PreferencesModel
    @State private var isAddingTerm = false

    var body: some View {
        List {
            if model.preferences.dictationDictionary.isEmpty {
                ContentUnavailableView("No dictionary terms", systemImage: "character.book.closed", description: Text("Add names and terms that Entrevoix should recognize."))
            } else {
                Section {
                    ForEach(model.preferences.dictationDictionary, id: \.self) { term in Text(term) }
                        .onDelete(perform: model.removeDictionaryTerms)
                }
            }
            Section {
                Button("Add term", systemImage: "plus") { isAddingTerm = true }
            }
        }
        .sheet(isPresented: $isAddingTerm) { AddDictionaryTermView(model: model) }
    }
}

private struct PromptLibrarySettingsView: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        List {
            Section {
                ForEach(model.preferences.cleanupPrompts) { prompt in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(prompt.name, systemImage: prompt.systemImageName)
                        Text(prompt.instructions)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                }
            } footer: {
                Text("Prompt editing is managed on Entrevoix for Mac. Saved prompts remain available for iOS cleanup.")
            }
        }
    }
}

private struct WorkflowLibrarySettingsView: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        List {
            if model.preferences.cleanupWorkflows.isEmpty {
                ContentUnavailableView("No workflows", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Create workflows in Entrevoix for Mac to combine saved prompts."))
            } else {
                Section {
                    ForEach(model.preferences.cleanupWorkflows) { workflow in
                        HStack {
                            Label(workflow.name, systemImage: "point.3.connected.trianglepath.dotted")
                            Spacer()
                            Text("\(workflow.promptIDs.count) prompts").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct AddDictionaryTermView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: PreferencesModel
    @State private var term = ""
    @State private var showsDuplicateError = false

    var body: some View {
        NavigationStack {
            Form { TextField("Term", text: $term).autocorrectionDisabled() }
                .navigationTitle("Add term")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if model.addDictionaryTerm(term) { dismiss() } else { showsDuplicateError = true }
                        }
                        .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .alert("Term already exists", isPresented: $showsDuplicateError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Choose a different, non-empty term.")
                }
        }
    }
}

private struct AddProviderView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: PreferencesModel
    @State private var apiKey = ""
    @State private var kind: ProviderKind = .openAI

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    Picker("Provider", selection: $kind) {
                        ForEach(ProviderKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                }
                Section {
                    SecureField("API key", text: $apiKey).autocorrectionDisabled()
                } footer: {
                    Text("The key is stored in the device Keychain; it is never written to Entrevoix preferences.")
                }
            }
            .navigationTitle(kind.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        switch kind {
                        case .openAI: model.addOpenAIProvider(apiKey: apiKey)
                        case .anthropic: model.addAnthropicProvider(apiKey: apiKey)
                        }
                        dismiss()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private enum ProviderKind: CaseIterable, Identifiable {
    case openAI
    case anthropic

    var id: Self { self }

    var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
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
