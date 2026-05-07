import AppKit
import Combine
import MenuBarNotesCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let localizer = Localizer()
    private lazy var settingsStore = AppSettingsStore(errorHandler: { error in
        NSLog("Menu Bar Notes settings error: \(error.localizedDescription)")
    })
    private lazy var menuBarController = MenuBarController(
        settingsStore: settingsStore,
        localizer: localizer,
        showSettings: { [weak self] in self?.showSettings() },
        showAppInfo: { [weak self] in self?.showAppInfo() }
    )
    private var settingsWindowController: SettingsWindowController?
    private var appInfoWindowController: AppInfoWindowController?
    private var settingsSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.installStatusItem()
        applyAppearance(settingsStore.settings.appearanceMode)

        settingsSubscription = settingsStore.$settings.sink { [weak self] settings in
            self?.applyAppearance(settings.appearanceMode)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settingsStore: settingsStore,
                localizer: localizer
            )
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
    }

    private func showAppInfo() {
        if appInfoWindowController == nil {
            appInfoWindowController = AppInfoWindowController(
                appInfo: .current(),
                localizer: localizer
            )
        }

        NSApp.activate(ignoringOtherApps: true)
        appInfoWindowController?.showWindow(nil)
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
