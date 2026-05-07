import AppKit
import MenuBarNotesCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(settingsStore: AppSettingsStore, localizer: Localizer) {
        let contentView = SettingsView(settingsStore: settingsStore, localizer: localizer)
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
    let localizer: Localizer

    var body: some View {
        TabView {
            GeneralSettingsView(settingsStore: settingsStore, localizer: localizer)
                .tabItem { Text(localizer.string(.generalTab)) }

            PlaceholderSettingsTab(localizer: localizer)
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
