import AppKit
import MenuBarNotesCore
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let settingsStore: AppSettingsStore
    private let recordListStore: RecordListStore
    private let reminderNotificationStore: ReminderNotificationStore
    private let captureService: QuickAddCaptureService
    private let localizer: Localizer
    private let showSettings: () -> Void
    private let showAppInfo: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init(
        settingsStore: AppSettingsStore,
        recordListStore: RecordListStore,
        reminderNotificationStore: ReminderNotificationStore,
        captureService: QuickAddCaptureService,
        localizer: Localizer,
        showSettings: @escaping () -> Void,
        showAppInfo: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.recordListStore = recordListStore
        self.reminderNotificationStore = reminderNotificationStore
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
        popover.contentSize = NSSize(width: 340, height: 480)
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView(
                settingsStore: settingsStore,
                recordListStore: recordListStore,
                reminderNotificationStore: reminderNotificationStore,
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
