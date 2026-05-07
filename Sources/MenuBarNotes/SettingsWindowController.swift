import AppKit
import MenuBarNotesCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(
        settingsStore: AppSettingsStore,
        hotkeyRegistrar: GlobalHotkeyRegistrar,
        localizer: Localizer
    ) {
        let contentView = SettingsView(
            settingsStore: settingsStore,
            hotkeyRegistrar: hotkeyRegistrar,
            localizer: localizer
        )
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = localizer.string(.settingsTitle)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 360))
        window.center()

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

struct SettingsView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var hotkeyRegistrar: GlobalHotkeyRegistrar
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

            PlaceholderSettingsTab(localizer: localizer)
                .tabItem { Text(localizer.string(.pomodoroTab)) }

            PlaceholderSettingsTab(localizer: localizer)
                .tabItem { Text(localizer.string(.calendarTab)) }
        }
        .padding(16)
        .frame(width: 520, height: 360)
    }
}

private struct NotesTodosSettingsView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var hotkeyRegistrar: GlobalHotkeyRegistrar
    let localizer: Localizer

    var body: some View {
        Form {
            Section(localizer.string(.markdownStorageLocationLabel)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedPath)
                        .font(.system(size: 12))
                        .foregroundStyle(settingsStore.settings.markdownStorageDirectory == nil ? .secondary : .primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(localizer.string(.markdownStorageLocationHelp))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Button(localizer.string(.chooseMarkdownStorageLocation), action: chooseFolder)
                        .controlSize(.small)
                }
            }

            Section(localizer.string(.quickAddHotkeyLabel)) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(localizer.string(.quickAddHotkeyLabel), selection: quickAddHotkeyBinding) {
                        Text(localizer.string(.quickAddHotkeyDisabled)).tag(HotkeyBinding.disabled)
                        ForEach(HotkeyBinding.configurableBindings) { binding in
                            Text(binding.displayString).tag(binding)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)

                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var selectedPath: String {
        settingsStore.settings.markdownStorageDirectory ?? localizer.string(.noStorageLocation)
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
                binding.displayString
            )
        case .conflict:
            return localizer.string(.quickAddHotkeyStatusConflict)
        case .failed:
            return localizer.string(.quickAddHotkeyStatusFailed)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = localizer.string(.chooseMarkdownStorageLocation)

        if panel.runModal() == .OK, let url = panel.url {
            settingsStore.setMarkdownStorageDirectory(url.path)
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
        }
        .formStyle(.grouped)
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { settingsStore.settings.appearanceMode },
            set: { settingsStore.setAppearanceMode($0) }
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

private struct PlaceholderSettingsTab: View {
    let localizer: Localizer

    var body: some View {
        Text(localizer.string(.featureComingSoon))
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
