import AppKit
import Combine
import NibikoCore
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let localizer = Localizer()
    private let notificationPresenter = AppNotificationPresenter()
    private let launchAtLoginService = MacOSLaunchAtLoginService()
    private lazy var settingsStore = AppSettingsStore(
        usesVaultSettings: true,
        launchAtLoginService: launchAtLoginService,
        errorHandler: { error in
            NSLog("Nibiko settings error: \(error.localizedDescription)")
        }
    )
    private lazy var recordListStore = RecordListStore(
        directory: settingsStore.vaultDirectoryURL,
        storage: MarkdownRecordsStore()
    )
    private lazy var reminderNotificationStore = ReminderNotificationStore(
        scheduler: EventKitReminderScheduler(notificationScheduler: UserNotificationReminderScheduler())
    )
    private lazy var appleReminderProvider = EventKitReminderProvider()
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
        settingsStore: settingsStore,
        captureService: quickAddCaptureService,
        localizer: localizer
    )
    private lazy var hotkeyRegistrar = GlobalHotkeyRegistrar { [weak self] in
        self?.showQuickAddPanel()
    }
    private lazy var menuBarController = MenuBarController(
        settingsStore: settingsStore,
        recordListStore: recordListStore,
        appleReminderProvider: appleReminderProvider,
        reminderNotificationStore: reminderNotificationStore,
        pomodoroTimer: pomodoroTimer,
        calendarEventsStore: calendarEventsStore,
        captureService: quickAddCaptureService,
        localizer: localizer,
        showSettings: { [weak self] in self?.showSettings() },
        requestQuit: { [weak self] in self?.confirmQuit() }
    )
    private var settingsWindowController: SettingsWindowController?
    private var settingsSubscription: AnyCancellable?
    private var recordsSubscription: AnyCancellable?
    private var appleReminderRecordsSubscription: AnyCancellable?
    private var reminderOverdueCheckSubscription: AnyCancellable?
    private var pomodoroSessionSubscription: AnyCancellable?
    private var pomodoroTickSubscription: AnyCancellable?
    private var systemAppearanceObserver: NSObjectProtocol?
    private var lastPomodoroTemplates: [PomodoroTemplate] = []
    private var lastSelectedPomodoroTemplateID: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = notificationPresenter
        ApplicationCommandMenu.install(appName: localizer.string(.appName))
        menuBarController.installStatusItem()
        applyAppearance(settingsStore.settings.appearanceMode)
        menuBarController.updateActiveCount(recordListStore.activeCount)
        updateOverdueReminderStatus()
        updatePomodoroStatusItem()
        hotkeyRegistrar.register(settingsStore.settings.quickAddHotkey)
        settingsStore.applyLaunchAtLoginPreference()
        refreshCalendarIfVisible(settingsStore.settings)
        appleReminderProvider.refreshIfAuthorized()
        lastPomodoroTemplates = settingsStore.settings.pomodoroTemplates
        lastSelectedPomodoroTemplateID = settingsStore.settings.selectedPomodoroTemplateID
        systemAppearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.settingsStore.settings.appearanceMode == .system else {
                    return
                }
                self?.applyAppearance(.system)
            }
        }

        settingsSubscription = settingsStore.$settings.sink { [weak self] settings in
            self?.applyAppearance(settings.appearanceMode)
            self?.recordListStore.setStorageLocation(directory: self?.settingsStore.vaultDirectoryURL)
            self?.hotkeyRegistrar.register(settings.quickAddHotkey)
            self?.resetPomodoroTemplatesIfNeeded(from: settings)
            self?.refreshCalendarIfVisible(settings)
        }

        recordsSubscription = recordListStore.$records.sink { [weak self] records in
            self?.menuBarController.updateActiveCount(ActiveRecordCounter.count(records))
            self?.updateOverdueReminderStatus(localRecords: records)
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.appleReminderProvider.refreshIfAuthorized()
                self?.menuBarController.refreshPopoverSizeIfShown()
            }
        }

        appleReminderRecordsSubscription = appleReminderProvider.$records.sink { [weak self] appleReminderRecords in
            self?.updateOverdueReminderStatus(appleReminderRecords: appleReminderRecords)
        }

        reminderOverdueCheckSubscription = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateOverdueReminderStatus()
            }

        pomodoroSessionSubscription = pomodoroTimer.$session
            .removeDuplicates()
            .sink { [weak self] session in
                guard let self else {
                    return
                }

                if self.settingsStore.settings.currentPomodoroSession != session {
                    self.settingsStore.setCurrentPomodoroSession(session)
                }
                self.updatePomodoroStatusItem(session: session)
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
                appInfo: .current(),
                localizer: localizer
            )
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
    }

    private func confirmQuit() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localizer.string(.exitConfirmationTitle)
        alert.informativeText = String(
            format: localizer.string(.exitConfirmationMessage),
            localizer.string(.appName)
        )
        alert.addButton(withTitle: localizer.string(.exitButton))
        alert.addButton(withTitle: localizer.string(.cancelButton))

        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    private func showQuickAddPanel() {
        quickAddPanelController.showPanel()
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        NSApp.appearance = mode.appKitAppearance
        menuBarController.applyAppearance(mode)
        settingsWindowController?.applyAppearance(mode)
        quickAddPanelController.applyAppearance(mode)
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
        updatePomodoroStatusItem()
    }

    private func updatePomodoroStatusItem(session: PomodoroSession? = nil) {
        let statusSession = session ?? pomodoroTimer.session
        let template = pomodoroTemplate(for: statusSession)
        menuBarController.updatePomodoroStatus(
            state: statusSession.state,
            remainingSeconds: pomodoroRemainingSeconds(for: statusSession, template: template),
            totalSeconds: template.focusDurationSeconds
        )
        updatePomodoroTickSubscription(state: statusSession.state)
    }

    private func updateOverdueReminderStatus(
        localRecords: [NibikoCore.Record]? = nil,
        appleReminderRecords: [NibikoCore.Record]? = nil,
        now: Date = Date()
    ) {
        let records = EventKitReminderProvider.mergedRecords(
            localRecords: localRecords ?? recordListStore.records,
            appleReminderRecords: appleReminderRecords ?? appleReminderProvider.records
        )
        menuBarController.updateOverdueReminderState(
            RecordDisplaySupport.hasOverdueReminder(records, now: now)
        )
    }

    private func updatePomodoroTickSubscription(state: PomodoroSessionState? = nil) {
        guard (state ?? pomodoroTimer.session.state) == .running else {
            pomodoroTickSubscription?.cancel()
            pomodoroTickSubscription = nil
            return
        }

        guard pomodoroTickSubscription == nil else {
            return
        }

        pomodoroTickSubscription = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else {
                    return
                }

                self.pomodoroTimer.tick()
                self.updatePomodoroStatusItem()
            }
    }

    private func pomodoroTemplate(for session: PomodoroSession) -> PomodoroTemplate {
        let templateID = session.templateID ?? settingsStore.settings.selectedPomodoroTemplateID
        return settingsStore.settings.pomodoroTemplates.first { $0.id == templateID }
            ?? pomodoroTimer.selectedTemplate
    }

    private func pomodoroRemainingSeconds(for session: PomodoroSession, template: PomodoroTemplate) -> Int {
        switch session.state {
        case .idle:
            return template.focusDurationSeconds
        case .running:
            guard let endsAt = session.endsAt else {
                return template.focusDurationSeconds
            }
            return max(0, Int(ceil(endsAt.timeIntervalSince(Date()))))
        case .paused:
            return max(0, session.pausedRemainingSeconds ?? template.focusDurationSeconds)
        case .completed:
            return 0
        }
    }

    private func refreshCalendarIfVisible(_ settings: AppSettings) {
        guard settings.isCalendarCardVisible else {
            return
        }

        calendarEventsStore.refresh(selectedSourceIDs: settings.selectedCalendarSourceIDs)
    }
}

private final class AppNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
