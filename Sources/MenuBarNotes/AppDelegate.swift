import AppKit
import Combine
import MenuBarNotesCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let localizer = Localizer()
    private lazy var settingsStore = AppSettingsStore(errorHandler: { error in
        NSLog("Menu Bar Notes settings error: \(error.localizedDescription)")
    })
    private lazy var recordListStore = RecordListStore(directory: markdownStorageURL(from: settingsStore.settings))
    private lazy var reminderNotificationStore = ReminderNotificationStore(
        scheduler: UserNotificationReminderScheduler()
    )
    private lazy var menuBarController = MenuBarController(
        settingsStore: settingsStore,
        recordListStore: recordListStore,
        reminderNotificationStore: reminderNotificationStore,
        localizer: localizer,
        showSettings: { [weak self] in self?.showSettings() },
        showAppInfo: { [weak self] in self?.showAppInfo() }
    )
    private var settingsWindowController: SettingsWindowController?
    private var appInfoWindowController: AppInfoWindowController?
    private var settingsSubscription: AnyCancellable?
    private var recordsSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.installStatusItem()
        applyAppearance(settingsStore.settings.appearanceMode)
        menuBarController.updateActiveCount(recordListStore.activeCount)

        settingsSubscription = settingsStore.$settings.sink { [weak self] settings in
            self?.applyAppearance(settings.appearanceMode)
            self?.recordListStore.setDirectory(self?.markdownStorageURL(from: settings))
        }

        recordsSubscription = recordListStore.$records.sink { [weak self] records in
            self?.menuBarController.updateActiveCount(ActiveRecordCounter.count(records))
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

    private func markdownStorageURL(from settings: AppSettings) -> URL? {
        guard let path = settings.markdownStorageDirectory else {
            return nil
        }

        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
