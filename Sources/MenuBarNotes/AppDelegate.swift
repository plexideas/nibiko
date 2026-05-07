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
    private lazy var pomodoroTimer = PomodoroTimer(
        selectedTemplate: selectedPomodoroTemplate(from: settingsStore.settings),
        currentSession: settingsStore.settings.currentPomodoroSession
    )
    private lazy var calendarEventsStore = CalendarEventsStore(provider: EventKitCalendarProvider())
    private lazy var quickAddCaptureService = QuickAddCaptureService(
        recordListStore: recordListStore,
        scheduleReminder: { [weak self] record in
            self?.reminderNotificationStore.scheduleIfNeeded(for: record)
        }
    )
    private lazy var quickAddPanelController = QuickAddPanelController(
        captureService: quickAddCaptureService,
        localizer: localizer
    )
    private lazy var hotkeyRegistrar = GlobalHotkeyRegistrar { [weak self] in
        self?.showQuickAddPanel()
    }
    private lazy var menuBarController = MenuBarController(
        settingsStore: settingsStore,
        recordListStore: recordListStore,
        reminderNotificationStore: reminderNotificationStore,
        pomodoroTimer: pomodoroTimer,
        calendarEventsStore: calendarEventsStore,
        captureService: quickAddCaptureService,
        localizer: localizer,
        showSettings: { [weak self] in self?.showSettings() },
        showAppInfo: { [weak self] in self?.showAppInfo() }
    )
    private var settingsWindowController: SettingsWindowController?
    private var appInfoWindowController: AppInfoWindowController?
    private var settingsSubscription: AnyCancellable?
    private var recordsSubscription: AnyCancellable?
    private var pomodoroSessionSubscription: AnyCancellable?
    private var lastPomodoroTemplates: [PomodoroTemplate] = []
    private var lastSelectedPomodoroTemplateID: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.installStatusItem()
        applyAppearance(settingsStore.settings.appearanceMode)
        menuBarController.updateActiveCount(recordListStore.activeCount)
        hotkeyRegistrar.register(settingsStore.settings.quickAddHotkey)
        refreshCalendarIfVisible(settingsStore.settings)
        lastPomodoroTemplates = settingsStore.settings.pomodoroTemplates
        lastSelectedPomodoroTemplateID = settingsStore.settings.selectedPomodoroTemplateID

        settingsSubscription = settingsStore.$settings.sink { [weak self] settings in
            self?.applyAppearance(settings.appearanceMode)
            self?.recordListStore.setDirectory(self?.markdownStorageURL(from: settings))
            self?.hotkeyRegistrar.register(settings.quickAddHotkey)
            self?.resetPomodoroTemplatesIfNeeded(from: settings)
            self?.refreshCalendarIfVisible(settings)
        }

        recordsSubscription = recordListStore.$records.sink { [weak self] records in
            self?.menuBarController.updateActiveCount(ActiveRecordCounter.count(records))
        }

        pomodoroSessionSubscription = pomodoroTimer.$session
            .removeDuplicates()
            .sink { [weak self] session in
                guard self?.settingsStore.settings.currentPomodoroSession != session else {
                    return
                }
                self?.settingsStore.setCurrentPomodoroSession(session)
            }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settingsStore: settingsStore,
                hotkeyRegistrar: hotkeyRegistrar,
                calendarEventsStore: calendarEventsStore,
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

    private func showQuickAddPanel() {
        quickAddPanelController.showPanel()
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

    private func selectedPomodoroTemplate(from settings: AppSettings) -> PomodoroTemplate {
        let templateID = settings.currentPomodoroSession?.templateID ?? settings.selectedPomodoroTemplateID
        return settings.pomodoroTemplates.first { $0.id == templateID }
            ?? settings.pomodoroTemplates[0]
    }

    private func resetPomodoroTemplatesIfNeeded(from settings: AppSettings) {
        guard settings.pomodoroTemplates != lastPomodoroTemplates
            || settings.selectedPomodoroTemplateID != lastSelectedPomodoroTemplateID
        else {
            return
        }

        lastPomodoroTemplates = settings.pomodoroTemplates
        lastSelectedPomodoroTemplateID = settings.selectedPomodoroTemplateID
        pomodoroTimer.resetTemplates(
            settings.pomodoroTemplates,
            selectedTemplateID: settings.selectedPomodoroTemplateID
        )
    }

    private func refreshCalendarIfVisible(_ settings: AppSettings) {
        guard settings.isCalendarCardVisible else {
            return
        }

        calendarEventsStore.refresh(selectedSourceIDs: settings.selectedCalendarSourceIDs)
    }
}
