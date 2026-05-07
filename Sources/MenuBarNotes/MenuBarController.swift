import AppKit
import MenuBarNotesCore
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let settingsStore: AppSettingsStore
    private let recordListStore: RecordListStore
    private let reminderNotificationStore: ReminderNotificationStore
    private let pomodoroTimer: PomodoroTimer
    private let calendarEventsStore: CalendarEventsStore
    private let captureService: QuickAddCaptureService
    private let localizer: Localizer
    private let showSettings: () -> Void
    private let showAppInfo: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let popoverWidth: CGFloat = 340
    private let maximumPopoverScreenHeightRatio: CGFloat = 2.0 / 3.0
    private var hostingController: NSHostingController<PopoverRootView>?

    init(
        settingsStore: AppSettingsStore,
        recordListStore: RecordListStore,
        reminderNotificationStore: ReminderNotificationStore,
        pomodoroTimer: PomodoroTimer,
        calendarEventsStore: CalendarEventsStore,
        captureService: QuickAddCaptureService,
        localizer: Localizer,
        showSettings: @escaping () -> Void,
        showAppInfo: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.recordListStore = recordListStore
        self.reminderNotificationStore = reminderNotificationStore
        self.pomodoroTimer = pomodoroTimer
        self.calendarEventsStore = calendarEventsStore
        self.captureService = captureService
        self.localizer = localizer
        self.showSettings = showSettings
        self.showAppInfo = showAppInfo
    }

    func installStatusItem() {
        statusItem.button?.image = NSImage(
            systemSymbolName: "note.text",
            accessibilityDescription: localizer.string(.statusItemDescription)
        )
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.toolTip = localizer.string(.appName)

        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(
            rootView: PopoverRootView(
                settingsStore: settingsStore,
                recordListStore: recordListStore,
                reminderNotificationStore: reminderNotificationStore,
                pomodoroTimer: pomodoroTimer,
                calendarEventsStore: calendarEventsStore,
                captureService: captureService,
                localizer: localizer,
                showSettings: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.showSettings()
                },
                showAppInfo: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.showAppInfo()
                }
            )
        )
        self.hostingController = hostingController
        popover.contentViewController = hostingController
    }

    func updateActiveCount(_ count: Int) {
        statusItem.button?.title = count > 0 ? "\(count)" : ""
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            updatePopoverContentSize(relativeTo: button)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func updatePopoverContentSize(relativeTo button: NSStatusBarButton) {
        guard let hostingController else {
            return
        }

        let maximumHeight = maximumPopoverHeight(relativeTo: button)
        let fittingSize = hostingController.sizeThatFits(
            in: NSSize(width: popoverWidth, height: maximumHeight)
        )
        let height = min(max(fittingSize.height, 1), maximumHeight)
        popover.contentSize = NSSize(width: popoverWidth, height: ceil(height))
    }

    private func maximumPopoverHeight(relativeTo button: NSStatusBarButton) -> CGFloat {
        let screen = button.window?.screen ?? NSScreen.main
        return floor((screen?.visibleFrame.height ?? 720) * maximumPopoverScreenHeightRatio)
    }
}
