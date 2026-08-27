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
    @State private var providerBeingEdited: RemoteProviderProfile?
    @State private var isEditingCodex = false

    var body: some View {
        Form {
            Section {
                if model.preferences.providerCatalog.isEmpty {
                    ContentUnavailableView("No provider configured", systemImage: "network", description: Text("Add Apple Foundation, OpenAI, OpenAI-compatible, or Anthropic providers."))
                } else {
                    ForEach(model.preferences.providerCatalog) { provider in
                        if let remoteProvider = provider.remoteProfile {
                            Button { providerBeingEdited = remoteProvider } label: {
                                HStack(spacing: 12) {
                                    ProviderCatalogIcon(icon: remoteProvider.catalogIcon)
                                        .accessibilityHidden(true)
                                    Text(remoteProvider.name)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 12)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                        .accessibilityHidden(true)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Edit provider")
                        } else if provider.codexProfile != nil {
                            Button { isEditingCodex = true } label: {
                                HStack(spacing: 12) {
                                    ProviderCatalogIcon(icon: .openAI)
                                        .accessibilityHidden(true)
                                    Text(provider.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 12)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                        .accessibilityHidden(true)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Edit provider")
                        } else {
                            Label(provider.displayName, systemImage: provider.systemImageName)
                        }
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
        .sheet(item: $providerBeingEdited) { provider in
            EditRemoteProviderView(model: model, provider: provider)
        }
        .sheet(isPresented: $isEditingCodex) {
            CodexProviderSettingsView(model: model)
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
                if !model.preferences.providerCatalog.contains(where: { $0.id == .codex }) {
                    ProviderCatalogItem(title: "OpenAI (Codex)", icon: .openAI, accessibilityHint: "Configure provider") {
                        model.addCodexProvider()
                        dismiss()
                    }
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

private struct CodexProviderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: PreferencesModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Use your ChatGPT account to improve transcriptions.", systemImage: "person.crop.circle")
                    connectionControls
                } header: {
                    Text("OpenAI (Codex)")
                }

                Section {
                    Picker("Model", selection: codexModel) {
                        ForEach(CodexModel.allCases) { model in
                            Text(model.rawValue).tag(model)
                        }
                    }

                    Text("OpenAI (Codex) is available for text cleanup only. Choose a separate speech-to-text provider.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Text cleanup")
                }
            }
            .navigationTitle("OpenAI (Codex)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var codexModel: Binding<CodexModel> {
        Binding(
            get: { model.preferences.provider(for: .codex)?.codexProfile?.model ?? .gpt56Luna },
            set: { model.setCodexModel($0) }
        )
    }

    @ViewBuilder private var connectionControls: some View {
        switch model.codexConnectionState {
        case .disconnected:
            Button("Connect ChatGPT", action: model.connectCodex)
                .buttonStyle(.borderedProminent)
        case .connecting:
            HStack {
                ProgressView()
                Text("Connecting to ChatGPT…")
            }
        case .connected:
            HStack {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("Disconnect", action: model.disconnectCodex)
                    .buttonStyle(.bordered)
            }
        case .failed:
            HStack {
                Label("Could not connect to ChatGPT.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Spacer()
                Button("Connect ChatGPT", action: model.connectCodex)
                    .buttonStyle(.bordered)
            }
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

private struct EditRemoteProviderView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: PreferencesModel
    let provider: RemoteProviderProfile
    @State private var apiKey = ""
    @State private var draft: RemoteProviderProfile
    @State private var discoveredModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelDiscoveryError: String?
    @State private var modelLoadingRequest: UUID?

    init(model: PreferencesModel, provider: RemoteProviderProfile) {
        self.model = model
        self.provider = provider
        _draft = State(initialValue: provider)
    }

    var body: some View {
        NavigationStack {
            Form {
                if draft.kind == .anthropic {
                    anthropicSettings
                } else {
                    connectionSettings
                    capabilities
                }

                if let configurationError = model.configurationError {
                    Section {
                        Label(configurationError, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit \(provider.name)")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: modelLoadingRequest) {
                guard modelLoadingRequest != nil else { return }
                isLoadingModels = true
                modelDiscoveryError = nil
                let loadedModels = await model.loadModels(for: draft, replacementAPIKey: apiKey)
                guard !Task.isCancelled else { return }
                isLoadingModels = false
                if let loadedModels {
                    discoveredModels = loadedModels
                } else {
                    modelDiscoveryError = String(localized: "Could not load models. You can still enter one manually.")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.updateRemoteProvider(draft, apiKey: apiKey) {
                            dismiss()
                        }
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    private var connectionSettings: some View {
        Section {
            TextField("Name", text: $draft.name)
                .textInputAutocapitalization(.words)

            TextField("Base URL", text: $draft.baseURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(draft.kind == .openAI)

            Picker("Authentication", selection: $draft.authentication) {
                ForEach(AuthenticationMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .disabled(draft.kind == .openAI)

            if draft.authentication != .none {
                SecureField("New API key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if draft.authentication == .apiKey {
                    TextField("Header name", text: $draft.customHeaderName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            if draft.kind == .openAICompatible {
                TextField("Models path", text: $draft.modelsPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Button {
                modelLoadingRequest = UUID()
            } label: {
                if isLoadingModels {
                    HStack {
                        Text("Load / Refresh models")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Text("Load / Refresh models")
                }
            }
            .disabled(isLoadingModels || (draft.stt == nil && draft.ttt == nil))

            if !discoveredModels.isEmpty {
                Menu("Use a loaded model") {
                    ForEach(discoveredModels, id: \.self) { modelID in
                        Button(modelID) {
                            if draft.stt != nil {
                                draft.stt?.model = modelID
                            } else {
                                draft.ttt?.model = modelID
                            }
                        }
                    }
                }
            }

            if let modelDiscoveryError {
                Text(modelDiscoveryError)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text(draft.kind == .openAI ? "OpenAI" : "OpenAI-compatible")
        } footer: {
            if draft.authentication != .none {
                Text("Leave this field blank to keep the current key. A replacement key is stored in the device Keychain.")
            }
        }
    }

    private var anthropicSettings: some View {
        Section {
            TextField("Name", text: $draft.name)
                .textInputAutocapitalization(.words)

            SecureField("New API key", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("TTT model", text: tttModel)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Label(
                "Anthropic is available for text cleanup only. Its endpoint and authentication are preconfigured.",
                systemImage: "text.badge.checkmark"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        } header: {
            Text("Anthropic")
        } footer: {
            Text("Leave this field blank to keep the current key. A replacement key is stored in the device Keychain.")
        }
    }

    private var capabilities: some View {
        Section {
            Toggle("Speech to text", isOn: sttEnabled)

            if draft.stt != nil {
                TextField("STT route", text: sttPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(draft.kind == .openAI)

                TextField("STT model", text: sttModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Picker("Audio upload format", selection: sttUploadFormat) {
                    ForEach(AudioUploadFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
            }

            Toggle("Text cleanup", isOn: tttEnabled)

            if draft.ttt != nil {
                TextField("TTT route", text: tttPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(draft.kind == .openAI)

                TextField("TTT model", text: tttModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Picker("TTT API format", selection: tttFormat) {
                    ForEach(CleanupAPIFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
            }
        } header: {
            Text("Capabilities")
        } footer: {
            if draft.stt != nil {
                Text("Format support varies by endpoint. When in doubt, choose WAV.")
            }
        }
    }

    private var sttEnabled: Binding<Bool> {
        Binding(
            get: { draft.stt != nil },
            set: { isEnabled in
                draft.stt = isEnabled ? STTCapability() : nil
            }
        )
    }

    private var tttEnabled: Binding<Bool> {
        Binding(
            get: { draft.ttt != nil },
            set: { isEnabled in
                draft.ttt = isEnabled ? TTTCapability() : nil
            }
        )
    }

    private var sttPath: Binding<String> {
        Binding(get: { draft.stt?.path ?? "" }, set: { draft.stt?.path = $0 })
    }

    private var sttModel: Binding<String> {
        Binding(get: { draft.stt?.model ?? "" }, set: { draft.stt?.model = $0 })
    }

    private var sttUploadFormat: Binding<AudioUploadFormat> {
        Binding(get: { draft.stt?.uploadFormat ?? .wav }, set: { draft.stt?.uploadFormat = $0 })
    }

    private var tttPath: Binding<String> {
        Binding(get: { draft.ttt?.path ?? "" }, set: { draft.ttt?.path = $0 })
    }

    private var tttModel: Binding<String> {
        Binding(get: { draft.ttt?.model ?? "" }, set: { draft.ttt?.model = $0 })
    }

    private var tttFormat: Binding<CleanupAPIFormat> {
        Binding(get: { draft.ttt?.format ?? .responses }, set: { draft.ttt?.format = $0 })
    }

    private var isSaveDisabled: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (draft.kind == .openAICompatible && draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

private extension AuthenticationMode {
    var displayName: String {
        switch self {
        case .bearer: "Bearer"
        case .apiKey: "API key"
        case .none: "None"
        }
    }
}

private extension AudioUploadFormat {
    var displayName: String {
        switch self {
        case .wav: "WAV (lossless)"
        case .m4aAAC: "M4A (AAC, 32 kb/s)"
        case .flac: "FLAC (lossless)"
        }
    }
}

private extension CleanupAPIFormat {
    var displayName: String {
        switch self {
        case .responses: "Responses API"
        case .chatCompletions: "Chat Completions API"
        case .anthropicMessages: "Anthropic Messages API"
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

private extension RemoteProviderProfile {
    var catalogIcon: ProviderCatalogIcon.Kind {
        switch kind {
        case .openAI: .openAI
        case .openAICompatible: .system("network")
        case .anthropic: .anthropic
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
