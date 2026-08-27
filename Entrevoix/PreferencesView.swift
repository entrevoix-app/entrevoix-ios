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
        case .general: String(localized: "General")
        case .providers: String(localized: "Providers")
        case .transcription: String(localized: "Transcription")
        case .cleanup: String(localized: "Cleanup")
        case .dictationDictionary: String(localized: "Dictation Dictionary")
        case .prompts: String(localized: "Prompts")
        case .workflows: String(localized: "Workflows")
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
                    ContentUnavailableView("No provider configured", systemImage: "network", description: Text("Add Apple Foundation, OpenAI, OpenAI-compatible, or Anthropic providers."))
                } else {
                    ForEach(model.preferences.providerCatalog) { provider in
                        Label(provider.displayName, systemImage: provider.systemImageName)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add provider", systemImage: "plus") { isAddingProvider = true }
            }
        }
        .sheet(isPresented: $isAddingProvider) {
            AddProviderCatalogView(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct TranscriptionSettingsView: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: model.binding(for: \.selectedSTTProviderID)) {
                    if transcriptionProviders.isEmpty {
                        Text("No provider configured").tag(ProviderIdentifier?.none)
                    } else {
                        ForEach(transcriptionProviders) { provider in
                            Text(provider.displayName).tag(provider.id as ProviderIdentifier?)
                        }
                    }
                }
                .disabled(transcriptionProviders.isEmpty)

                Picker("Language", selection: model.binding(for: \.sttLanguage)) {
                    ForEach(transcriptionLanguages) { language in Text(language.displayName).tag(language) }
                }
            } footer: {
                Text("Choose the language Entrevoix uses for transcription.")
            }
        }
    }

    private var transcriptionProviders: [ProviderCatalogEntry] {
        model.preferences.providerCatalog.filter(\.supportsSTT)
    }

    private var transcriptionLanguages: [TranscriptionLanguage] {
        TranscriptionLanguage.allCases.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
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
    @State private var draft: CleanupPrompt?
    @State private var promptPendingDeletion: CleanupPrompt?

    var body: some View {
        List {
            if model.preferences.cleanupPrompts.isEmpty {
                ContentUnavailableView(
                    "No prompts saved",
                    systemImage: "text.badge.checkmark",
                    description: Text("Create reusable instructions to refine your dictations.")
                )
            } else {
                Section {
                ForEach(model.preferences.cleanupPrompts) { prompt in
                    HStack(spacing: 12) {
                        Button { draft = prompt } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: prompt.systemImageName)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(prompt.name)
                                        .foregroundStyle(.primary)
                                    Text(prompt.instructions)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)

                        Button {
                            model.setActiveCleanupPrompt(prompt.id)
                        } label: {
                            Image(systemName: isActive(prompt) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isActive(prompt) ? Color.accentColor : Color.secondary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel(isActive(prompt) ? "Selected cleanup prompt" : "Use \(prompt.name) for cleanup")
                    }
                    .padding(.vertical, 2)
                    .swipeActions {
                        Button(role: .destructive) {
                            promptPendingDeletion = prompt
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                } footer: {
                    Text("Prompts sync automatically with Entrevoix for Mac.")
                }
            }

        }
        .toolbar {
            Button {
                draft = CleanupPrompt(name: "", systemImageName: "sparkles", instructions: "")
            } label: {
                Label("Add prompt", systemImage: "plus")
            }
        }
        .sheet(item: $draft) { prompt in
            PromptEditorView(model: model, initialPrompt: prompt)
        }
        .confirmationDialog(
            "Delete \(promptPendingDeletion?.name ?? "prompt")?",
            isPresented: Binding(
                get: { promptPendingDeletion != nil },
                set: { if !$0 { promptPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let promptPendingDeletion { model.deleteCleanupPrompt(id: promptPendingDeletion.id) }
                promptPendingDeletion = nil
            }
        } message: {
            Text("This also removes the prompt from saved workflows.")
        }
    }

    private func isActive(_ prompt: CleanupPrompt) -> Bool {
        model.preferences.activeCleanupSelection == .prompt(prompt.id)
    }
}

private struct PromptEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: PreferencesModel
    @State private var prompt: CleanupPrompt
    @State private var validationError: CleanupPromptValidationError?

    init(model: PreferencesModel, initialPrompt: CleanupPrompt) {
        self.model = model
        _prompt = State(initialValue: initialPrompt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Prompt") {
                    TextField("Name", text: $prompt.name)
                        .textInputAutocapitalization(.words)
                    Picker("Icon", selection: $prompt.systemImageName) {
                        ForEach(CleanupPrompt.allowedSystemImageNames, id: \.self) { icon in
                            Label(icon, systemImage: icon).tag(icon)
                        }
                    }
                }
                Section("Instructions") {
                    TextEditor(text: $prompt.instructions)
                        .frame(minHeight: 160)
                        .textInputAutocapitalization(.sentences)
                }
                if let validationError {
                    Section {
                        Text(validationError.message)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button("Use for cleanup") {
                        guard save() else { return }
                        model.setActiveCleanupPrompt(prompt.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle(prompt.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New prompt" : "Edit prompt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if save() { dismiss() }
                    }
                    .disabled(prompt.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prompt.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() -> Bool {
        validationError = model.saveCleanupPrompt(prompt)
        return validationError == nil
    }
}

private extension CleanupPromptValidationError {
    var message: String {
        switch self {
        case .emptyName: String(localized: "Enter a prompt name.")
        case .duplicateName: String(localized: "A prompt already uses this name.")
        case .emptyInstructions: String(localized: "Enter prompt instructions.")
        case .invalidIcon: String(localized: "Choose a supported icon.")
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
                            Text(String(localized: "\(workflow.promptIDs.count) prompts"))
                                .foregroundStyle(.secondary)
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

private struct AddProviderCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: PreferencesModel
    @State private var configurationKind: ProviderKind?

    var body: some View {
        NavigationStack {
            Group {
                if let configurationKind {
                    AddRemoteProviderView(
                        model: model,
                        kind: configurationKind,
                        onBack: { self.configurationKind = nil }
                    )
                } else {
                    providerCatalog
                }
            }
        }
    }

    private var providerCatalog: some View {
        List {
            Section("Available providers") {
                if !model.preferences.providerCatalog.contains(where: { $0.id == .apple }) {
                    ProviderCatalogItem(
                        title: "Apple Foundation",
                        icon: .system("apple.logo"),
                        accessibilityHint: "Add provider"
                    ) {
                        model.addAppleProvider()
                        dismiss()
                    }
                }

                ProviderCatalogItem(title: "OpenAI", icon: .openAI, accessibilityHint: "Configure provider") {
                    configurationKind = .openAI
                }
                ProviderCatalogItem(title: "Anthropic", icon: .anthropic, accessibilityHint: "Configure provider") {
                    configurationKind = .anthropic
                }
                ProviderCatalogItem(title: "OpenAI-compatible", icon: .system("network"), accessibilityHint: "Configure provider") {
                    configurationKind = .openAICompatible
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Add a provider")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

private struct ProviderCatalogItem: View {
    let title: String
    let icon: ProviderCatalogIcon.Kind
    let accessibilityHint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ProviderCatalogIcon(icon: icon)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 12)
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }
}

private struct ProviderCatalogIcon: View {
    static let size: CGFloat = 28

    enum Kind {
        case openAI
        case anthropic
        case system(String)
    }

    let icon: Kind

    var body: some View {
        Group {
            switch icon {
            case .openAI:
                Image("ProviderOpenAI")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .padding(4)
            case .anthropic:
                Image("ProviderAnthropic")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .padding(5)
            case .system(let name):
                Image(systemName: name)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            if isRemoteProvider {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var isRemoteProvider: Bool {
        switch icon {
        case .openAI, .anthropic: true
        case .system: false
        }
    }

    private var backgroundColor: Color {
        switch icon {
        case .openAI, .anthropic:
            Color(uiColor: .secondarySystemGroupedBackground)
        case .system:
            Color.accentColor.opacity(0.14)
        }
    }
}

private struct AddRemoteProviderView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: PreferencesModel
    let kind: ProviderKind
    let onBack: () -> Void
    @State private var apiKey = ""
    @State private var baseURL = ""

    var body: some View {
        Form {
            if kind == .openAICompatible {
                Section {
                    TextField("Base URL", text: $baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Enter the provider address, for example https://api.example.com/v1.")
                }
            }
            Section {
                SecureField("API key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("The key is stored in the device Keychain; it is never written to Entrevoix preferences.")
            }
        }
        .navigationTitle(kind.title)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onBack) {
                    Label("All providers", systemImage: "chevron.left")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let didAdd: Bool
                    switch kind {
                    case .openAI:
                        didAdd = model.addOpenAIProvider(apiKey: apiKey)
                    case .openAICompatible:
                        didAdd = model.addOpenAICompatibleProvider(baseURL: baseURL, apiKey: apiKey)
                    case .anthropic:
                        didAdd = model.addAnthropicProvider(apiKey: apiKey)
                    }
                    if didAdd {
                        dismiss()
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (kind == .openAICompatible && baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
    }
}

private enum ProviderKind: CaseIterable, Identifiable {
    case openAI
    case openAICompatible
    case anthropic

    var id: Self { self }

    var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .openAICompatible: "OpenAI-compatible"
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

private extension CleanupFailurePolicy {
    var displayName: String {
        switch self {
        case .useRawTranscript: String(localized: "Use the original transcript")
        case .stop: String(localized: "Stop and show an error")
        }
    }
}

private extension OutputMode {
    var displayName: String {
        switch self {
        case .clipboard: String(localized: "Clipboard")
        case .paste: String(localized: "Paste into active text field")
        }
    }
}
