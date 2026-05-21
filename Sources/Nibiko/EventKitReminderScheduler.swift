import EventKit
import Foundation
import NibikoCore

actor EventKitReminderScheduler: ReminderNotificationScheduling {
    private let eventStore = EKEventStore()
    private let notificationScheduler: (any ReminderNotificationScheduling)?

    init(notificationScheduler: (any ReminderNotificationScheduling)? = nil) {
        self.notificationScheduler = notificationScheduler
    }

    func currentAuthorization() async -> ReminderNotificationAuthorization {
        if let notificationScheduler {
            return await notificationScheduler.currentAuthorization()
        }

        return reminderAuthorization()
    }

    func requestAuthorization() async -> ReminderNotificationAuthorization {
        if let notificationScheduler {
            return await notificationScheduler.requestAuthorization()
        }

        let authorization = reminderAuthorization()
        if authorization == .authorized {
            return .authorized
        }

        guard authorization == .notDetermined else {
            return authorization
        }

        do {
            let isAllowed = try await eventStore.requestFullAccessToReminders()
            return isAllowed ? .authorized : .denied
        } catch {
            return .unavailable
        }
    }

    func scheduleReminderNotification(_ request: ReminderNotificationRequest) async throws {
        if let notificationScheduler {
            try await notificationScheduler.scheduleReminderNotification(request)
            try? saveAppleReminderIfAuthorized(for: request)
            return
        }

        try saveAppleReminderIfAuthorized(for: request)
    }

    private func saveAppleReminderIfAuthorized(for request: ReminderNotificationRequest) throws {
        let authorization = reminderAuthorization()
        if authorization == .authorized {
            try saveAppleReminder(for: request)
            return
        }

        throw EventKitReminderSchedulerError.notAuthorized
    }

    private func reminderAuthorization() -> ReminderNotificationAuthorization {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined:
            return .notDetermined
        case .fullAccess:
            return .authorized
        case .writeOnly, .denied, .restricted:
            return .denied
        @unknown default:
            return .unavailable
        }
    }

    private func saveAppleReminder(for request: ReminderNotificationRequest) throws {
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            throw EventKitReminderSchedulerError.missingDefaultReminderList
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        reminder.title = request.title
        reminder.notes = request.body.isEmpty ? nil : request.body
        reminder.timeZone = .current
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: request.scheduledAt
        )
        reminder.addAlarm(EKAlarm(absoluteDate: request.scheduledAt))

        try eventStore.save(reminder, commit: true)
    }
}

private enum EventKitReminderSchedulerError: Error {
    case missingDefaultReminderList
    case notAuthorized
}
