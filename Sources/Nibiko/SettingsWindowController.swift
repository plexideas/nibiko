import AppKit
import NibikoCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(
        settingsStore: AppSettingsStore,
        hotkeyRegistrar: GlobalHotkeyRegistrar,
        calendarEventsStore: CalendarEventsStore,
        appInfo: AppInfo,
        localizer: Localizer
    ) {
        let contentView = SettingsView(
            settingsStore: settingsStore,
            hotkeyRegistrar: hotkeyRegistrar,
            calendarEventsStore: calendarEventsStore,
            appInfo: appInfo,
            localizer: localizer
        )
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = localizer.string(.settingsTitle)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 420))
        window.center()

        super.init(window: window)
        shouldCascadeWindows = false
        applyAppearance(settingsStore.settings.appearanceMode)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func applyAppearance(_ mode: AppearanceMode) {
        applyWindowAppearance(mode, to: window)
    }
}

struct SettingsView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var hotkeyRegistrar: GlobalHotkeyRegistrar
    @ObservedObject var calendarEventsStore: CalendarEventsStore
    let appInfo: AppInfo
    let localizer: Localizer

    var body: some View {
        TabView {
            GeneralSettingsView(settingsStore: settingsStore, localizer: localizer)
                .tabItem { Text(localizer.string(.generalTab)) }

            NotesTodosSettingsView(
                settingsStore: settingsStore,
                hotkeyRegistrar: hotkeyRegistrar,
                localizer: localizer
            )
                .tabItem { Text(localizer.string(.notesTodosTab)) }

            PomodoroSettingsView(settingsStore: settingsStore, localizer: localizer)
                .tabItem { Text(localizer.string(.pomodoroTab)) }

            CalendarSettingsView(
                settingsStore: settingsStore,
                calendarEventsStore: calendarEventsStore,
                localizer: localizer
            )
                .tabItem { Text(localizer.string(.calendarTab)) }

            AppInfoView(appInfo: appInfo, localizer: localizer)
                .tabItem { Text(localizer.string(.appInfoButton)) }
        }
        .padding(16)
        .frame(width: 520, height: 420)
        .id(settingsStore.settings.appearanceMode)
        .preferredColorScheme(settingsStore.settings.appearanceMode.colorScheme)
    }
}

private struct NotesTodosSettingsView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var hotkeyRegistrar: GlobalHotkeyRegistrar
    let localizer: Localizer
    @State private var vaultMode: VaultStorageMode = .choose
    @State private var draftVaultName = ""
    @State private var draftVaultLocation = AppSettings.defaultVaultStorageDirectory

    var body: some View {
        Form {
            vaultStorageSection

            Section(localizer.string(.quickAddHotkeyLabel)) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(localizer.string(.quickAddHotkeyLabel), selection: quickAddHotkeyBinding) {
                        Text(localizer.string(.quickAddHotkeyDisabled)).tag(HotkeyBinding.disabled)
                        ForEach(HotkeyBinding.configurableBindings) { binding in
                            Text(localizer.hotkeyDisplayString(binding)).tag(binding)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)

                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: resetDraftVault)
    }

    @ViewBuilder
    private var vaultStorageSection: some View {
        switch vaultMode {
        case .choose:
            Section(localizer.string(.markdownStorageLocationLabel)) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(settingsStore.settings.vaultStorageDirectory)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    VaultActionRow(
                        title: localizer.string(.createNewVaultTitle),
                        description: localizer.string(.createNewVaultDescription),
                        buttonTitle: localizer.string(.createVaultButton),
                        action: showCreateVault
                    )

                    Divider()

                    VaultActionRow(
                        title: localizer.string(.openFolderAsVaultTitle),
                        description: localizer.string(.openFolderAsVaultDescription),
                        buttonTitle: localizer.string(.openVaultButton),
                        action: openFolderAsVault
                    )
                }
            }
        case .create:
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { vaultMode = .choose }) {
                        Label(localizer.string(.backButton), systemImage: "arrow.left")
                    }
                    .buttonStyle(.borderless)

                    Text(localizer.string(.createLocalVaultTitle))
                        .font(.headline)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizer.string(.vaultNameLabel))
                                .font(.system(size: 12, weight: .semibold))
                            Text(localizer.string(.vaultNameHelp))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField(localizer.string(.vaultNamePlaceholder), text: $draftVaultName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 210)
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizer.string(.vaultLocationLabel))
                                .font(.system(size: 12, weight: .semibold))
                            Text(draftVaultLocation)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button(localizer.string(.browseButton), action: browseVaultLocation)
                            .controlSize(.small)
                    }

                    Button(localizer.string(.createVaultButton), action: createVault)
                        .controlSize(.small)
                        .disabled(!isDraftVaultValid)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var quickAddHotkeyBinding: Binding<HotkeyBinding> {
        Binding(
            get: { settingsStore.settings.quickAddHotkey },
            set: { settingsStore.setQuickAddHotkey($0) }
        )
    }

    private var statusText: String {
        switch hotkeyRegistrar.status {
        case .disabled:
            return localizer.string(.quickAddHotkeyStatusDisabled)
        case let .registered(binding):
            return String(
                format: localizer.string(.quickAddHotkeyStatusRegistered),
                localizer.hotkeyDisplayString(binding)
            )
        case .conflict:
            return localizer.string(.quickAddHotkeyStatusConflict)
        case .failed:
            return localizer.string(.quickAddHotkeyStatusFailed)
        }
    }

    private var isDraftVaultValid: Bool {
        !draftVaultName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftVaultLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func showCreateVault() {
        resetDraftVault()
        vaultMode = .create
    }

    private func openFolderAsVault() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = localizer.string(.openVaultButton)
        panel.directoryURL = URL(
            fileURLWithPath: settingsStore.settings.vaultStorageDirectory,
            isDirectory: true
        )

        if panel.runModal() == .OK, let url = panel.url {
            settingsStore.setVaultStorageDirectory(url.path)
        }
    }

    private func browseVaultLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = localizer.string(.browseButton)
        panel.directoryURL = URL(fileURLWithPath: draftVaultLocation, isDirectory: true)

        if panel.runModal() == .OK, let url = panel.url {
            draftVaultLocation = url.path
        }
    }

    private func createVault() {
        let vaultName = AppSettings.normalizedVaultName(draftVaultName)
        let vaultURL = URL(fileURLWithPath: draftVaultLocation, isDirectory: true)
            .appendingPathComponent(vaultName, isDirectory: true)
        try? FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        settingsStore.setVaultName(vaultName)
        settingsStore.setVaultStorageDirectory(draftVaultLocation)
        vaultMode = .choose
    }

    private func resetDraftVault() {
        draftVaultName = settingsStore.settings.vaultName
        draftVaultLocation = settingsStore.settings.vaultStorageDirectory
    }
}

private enum VaultStorageMode {
    case choose
    case create
}

private struct VaultActionRow: View {
    let title: String
    let description: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(buttonTitle, action: action)
                .controlSize(.small)
                .frame(width: 92)
        }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    let localizer: Localizer

    var body: some View {
        Form {
            Picker(localizer.string(.appearanceLabel), selection: appearanceBinding) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(localizer.string(mode.localizationKey)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Section(localizer.string(.cardOrderLabel)) {
                VStack(spacing: 6) {
                    ForEach(settingsStore.settings.cardOrder) { card in
                        CardOrderRow(
                            card: card,
                            cards: settingsStore.settings.cardOrder,
                            localizer: localizer,
                            moveUp: { settingsStore.moveCard(card, direction: .up) },
                            moveDown: { settingsStore.moveCard(card, direction: .down) }
                        )
                    }
                }
            }

            Section {
                Toggle(localizer.string(.automaticUpdatesLabel), isOn: automaticUpdatesBinding)
                Toggle(localizer.string(.launchAtLoginLabel), isOn: launchAtLoginBinding)
            }
        }
        .formStyle(.grouped)
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { settingsStore.settings.appearanceMode },
            set: { settingsStore.setAppearanceMode($0) }
        )
    }

    private var automaticUpdatesBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.automaticUpdatesEnabled },
            set: { settingsStore.setAutomaticUpdatesEnabled($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.launchAtLoginEnabled },
            set: { settingsStore.setLaunchAtLoginEnabled($0) }
        )
    }
}

private struct CardOrderRow: View {
    let card: MenuCard
    let cards: [MenuCard]
    let localizer: Localizer
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        HStack {
            Text(localizer.string(card.titleKey))
                .font(.system(size: 12))
            Spacer()
            Button(action: moveUp) {
                Image(systemName: "chevron.up")
            }
            .help(localizer.string(.moveUp))
            .disabled(cards.first == card)

            Button(action: moveDown) {
                Image(systemName: "chevron.down")
            }
            .help(localizer.string(.moveDown))
            .disabled(cards.last == card)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }
}

private struct PomodoroSettingsView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    let localizer: Localizer

    var body: some View {
        Form {
            Toggle(localizer.string(.pomodoroVisibleLabel), isOn: visibilityBinding)

            Section(localizer.string(.pomodoroTemplatesLabel)) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(settingsStore.settings.pomodoroTemplates) { template in
                            PomodoroTemplateSettingsRow(
                                template: template,
                                canRemove: settingsStore.settings.pomodoroTemplates.count > 1,
                                localizer: localizer,
                                update: updateTemplate,
                                remove: {
                                    settingsStore.removePomodoroTemplate(id: template.id)
                                }
                            )
                        }

                        Button(action: addTemplate) {
                            Label(localizer.string(.pomodoroAddTemplate), systemImage: "plus")
                        }
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 190)
            }
        }
        .formStyle(.grouped)
    }

    private var visibilityBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.isPomodoroCardVisible },
            set: { settingsStore.setPomodoroCardVisible($0) }
        )
    }

    private func addTemplate() {
        let templateNumber = settingsStore.settings.pomodoroTemplates.count + 1
        settingsStore.upsertPomodoroTemplate(
            PomodoroTemplate(
                name: String(
                    format: localizer.string(.pomodoroNewTemplateNameFormat),
                    templateNumber
                ),
                focusDurationSeconds: PomodoroTemplate.defaultFocus.focusDurationSeconds
            )
        )
    }

    private func updateTemplate(_ template: PomodoroTemplate) {
        settingsStore.upsertPomodoroTemplate(template)
    }
}

private struct PomodoroTemplateSettingsRow: View {
    let template: PomodoroTemplate
    let canRemove: Bool
    let localizer: Localizer
    let update: (PomodoroTemplate) -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(localizer.string(.pomodoroTemplateNamePlaceholder), text: nameBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                Button(action: remove) {
                    Image(systemName: "minus.circle")
                }
                .help(localizer.string(.pomodoroRemoveTemplate))
                .buttonStyle(.borderless)
                .disabled(!canRemove)
            }

            Stepper(value: focusMinutesBinding, in: 1...180) {
                Text("\(localizer.string(.pomodoroFocusMinutesLabel)): \(focusMinutes)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .controlSize(.small)
        }
        .padding(8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var focusMinutes: Int {
        max(1, template.focusDurationSeconds / 60)
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { template.name },
            set: { name in
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    return
                }
                update(
                    PomodoroTemplate(
                        id: template.id,
                        name: trimmedName,
                        focusDurationSeconds: template.focusDurationSeconds,
                        shortBreakDurationSeconds: template.shortBreakDurationSeconds,
                        longBreakDurationSeconds: template.longBreakDurationSeconds,
                        cycleCount: template.cycleCount
                    )
                )
            }
        )
    }

    private var focusMinutesBinding: Binding<Int> {
        Binding(
            get: { focusMinutes },
            set: { minutes in
                update(
                    PomodoroTemplate(
                        id: template.id,
                        name: template.name,
                        focusDurationSeconds: minutes * 60,
                        shortBreakDurationSeconds: template.shortBreakDurationSeconds,
                        longBreakDurationSeconds: template.longBreakDurationSeconds,
                        cycleCount: template.cycleCount
                    )
                )
            }
        )
    }
}

private struct CalendarSettingsView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var calendarEventsStore: CalendarEventsStore
    let localizer: Localizer

    var body: some View {
        Form {
            Toggle(localizer.string(.calendarVisibleLabel), isOn: visibilityBinding)

            Section(localizer.string(.calendarSourcesLabel)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(permissionStatusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if calendarEventsStore.permissionState == .notDetermined {
                        Button(localizer.string(.calendarEnableAccess), action: requestAccess)
                            .controlSize(.small)
                            .keyboardShortcut(.defaultAction)
                    } else if calendarEventsStore.permissionState == .allowed {
                        sourceList

                        Button(localizer.string(.calendarRefreshSources), action: refreshSources)
                            .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshSources)
    }

    @ViewBuilder
    private var sourceList: some View {
        if calendarEventsStore.sources.isEmpty {
            Text(localizer.string(.calendarNoSources))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(calendarEventsStore.sources) { source in
                        Toggle(localizer.calendarSourceTitle(source), isOn: sourceBinding(for: source))
                            .font(.system(size: 12))
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 165)
        }
    }

    private var visibilityBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.isCalendarCardVisible },
            set: { isVisible in
                settingsStore.setCalendarCardVisible(isVisible)
                guard isVisible else {
                    return
                }

                calendarEventsStore.refresh(
                    selectedSourceIDs: settingsStore.settings.selectedCalendarSourceIDs,
                    requestPermissionIfNeeded: true
                )
            }
        )
    }

    private var permissionStatusText: String {
        switch calendarEventsStore.permissionState {
        case .notDetermined:
            return localizer.string(.calendarAccessNotDeterminedStatus)
        case .allowed:
            return calendarEventsStore.isLoading
                ? localizer.string(.calendarLoadingStatus)
                : localizer.string(.calendarPlaceholder)
        case .denied:
            return localizer.string(.calendarAccessDeniedStatus)
        case .unavailable:
            return localizer.string(.calendarAccessUnavailableStatus)
        }
    }

    private func sourceBinding(for source: CalendarSource) -> Binding<Bool> {
        Binding(
            get: {
                selectedSourceIDs.contains(source.id)
            },
            set: { isSelected in
                var nextSelection = selectedSourceIDs
                if isSelected {
                    nextSelection.insert(source.id)
                } else {
                    nextSelection.remove(source.id)
                }
                settingsStore.setSelectedCalendarSourceIDs(nextSelection)
                refreshSources()
            }
        )
    }

    private var selectedSourceIDs: Set<String> {
        CalendarDisplaySupport.selectedSourceIDs(
            from: settingsStore.settings.selectedCalendarSourceIDs,
            availableSources: calendarEventsStore.sources
        )
    }

    private func requestAccess() {
        calendarEventsStore.refresh(
            selectedSourceIDs: settingsStore.settings.selectedCalendarSourceIDs,
            requestPermissionIfNeeded: true
        )
    }

    private func refreshSources() {
        calendarEventsStore.refresh(selectedSourceIDs: settingsStore.settings.selectedCalendarSourceIDs)
    }
}
