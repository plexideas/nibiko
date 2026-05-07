import Foundation
import MenuBarNotesCore
import UserNotifications

struct UserNotificationReminderScheduler: ReminderNotificationScheduling {
    func currentAuthorization() async -> ReminderNotificationAuthorization {
        await authorization(from: UNUserNotificationCenter.current().notificationSettings())
    }

    func requestAuthorization() async -> ReminderNotificationAuthorization {
        do {
            let isAllowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            return isAllowed ? .authorized : .denied
        } catch {
            return .unavailable
        }
    }

    func scheduleReminderNotification(_ request: ReminderNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, request.scheduledAt.timeIntervalSinceNow),
            repeats: false
        )
        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )

        try await UNUserNotificationCenter.current().add(notificationRequest)
    }

    private func authorization(from settings: UNNotificationSettings) -> ReminderNotificationAuthorization {
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            return .unavailable
        }
    }
}
