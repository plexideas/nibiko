import Foundation
import Testing
@testable import NibikoCore

@Suite("Reminder notification planning")
struct ReminderNotificationPlannerTests {
    @Test("requests permission only for active future reminders with notification time")
    func requestsPermissionOnlyWhenSchedulingIsNeeded() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reminder = Record(
            id: "abc",
            kind: .reminder,
            title: "Check build",
            reminderAt: now.addingTimeInterval(600)
        )
        let note = Record(kind: .note, title: "Reference", reminderAt: now.addingTimeInterval(600))
        let pastReminder = Record(kind: .reminder, title: "Past", reminderAt: now.addingTimeInterval(-60))

        #expect(
            ReminderNotificationPlanner.decision(
                for: reminder,
                authorization: .notDetermined,
                now: now
            ) == .requestPermission(
                ReminderNotificationRequest(
                    identifier: "record-abc",
                    title: "Check build",
                    scheduledAt: now.addingTimeInterval(600)
                )
            )
        )
        #expect(
            ReminderNotificationPlanner.decision(
                for: note,
                authorization: .notDetermined,
                now: now
            ) == .noNotificationNeeded
        )
        #expect(
            ReminderNotificationPlanner.decision(
                for: pastReminder,
                authorization: .notDetermined,
                now: now
            ) == .noNotificationNeeded
        )
    }

    @Test("maps authorization states to scheduling decisions")
    func mapsAuthorizationStates() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reminder = Record(
            id: "reminder",
            kind: .reminder,
            title: "Stretch",
            reminderAt: now.addingTimeInterval(300)
        )
        let request = ReminderNotificationRequest(
            identifier: "record-reminder",
            title: "Stretch",
            scheduledAt: now.addingTimeInterval(300)
        )

        #expect(
            ReminderNotificationPlanner.decision(for: reminder, authorization: .authorized, now: now)
                == .schedule(request)
        )
        #expect(
            ReminderNotificationPlanner.decision(for: reminder, authorization: .denied, now: now)
                == .denied
        )
        #expect(
            ReminderNotificationPlanner.decision(for: reminder, authorization: .unavailable, now: now)
                == .unavailable
        )
    }
}
