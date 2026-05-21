import Foundation
import NibikoCore
import UserNotifications

struct UserNotificationReminderScheduler: ReminderNotificationScheduling {
    func currentAuthorization() async -> ReminderNotificationAuthorization {
        guard let notificationCenter else {
            return .unavailable
        }

        return await authorization(from: notificationCenter.notificationSettings())
    }

    func requestAuthorization() async -> ReminderNotificationAuthorization {
        guard let notificationCenter else {
            return .unavailable
        }

        do {
            let isAllowed = try await notificationCenter.requestAuthorization(options: [.alert, .sound])
            return isAllowed ? .authorized : .denied
        } catch {
            return .unavailable
        }
    }

    func scheduleReminderNotification(_ request: ReminderNotificationRequest) async throws {
        guard let notificationCenter else {
            throw UserNotificationReminderSchedulerError.unavailable
        }

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

        try await notificationCenter.add(notificationRequest)
    }

    private var notificationCenter: UNUserNotificationCenter? {
        guard
            Bundle.main.bundleURL.pathExtension == "app",
            Bundle.main.bundleIdentifier != nil
        else {
            return nil
        }

        return UNUserNotificationCenter.current()
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

private enum UserNotificationReminderSchedulerError: Error {
    case unavailable
}
