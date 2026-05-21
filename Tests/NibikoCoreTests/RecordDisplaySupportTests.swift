import Foundation
import Testing
@testable import NibikoCore

@Suite("Record display support")
struct RecordDisplaySupportTests {
    @Test("orders active reminders by visible time before untimed records")
    func ordersRemindersByVisibleTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let laterReminder = Record(
            kind: .reminder,
            title: "Later",
            updatedAt: now.addingTimeInterval(300),
            reminderAt: now.addingTimeInterval(3_600)
        )
        let untimedTodo = Record(
            kind: .todo,
            title: "Todo",
            updatedAt: now.addingTimeInterval(600)
        )
        let earlierReminder = Record(
            kind: .reminder,
            title: "Earlier",
            updatedAt: now,
            dueAt: now.addingTimeInterval(1_800)
        )
        let completedReminder = Record(
            kind: .reminder,
            title: "Completed",
            status: .completed,
            updatedAt: now.addingTimeInterval(900),
            reminderAt: now.addingTimeInterval(900)
        )

        let displayed = RecordDisplaySupport.recordsForDisplay([
            untimedTodo,
            laterReminder,
            completedReminder,
            earlierReminder
        ])

        #expect(displayed.map(\.title) == ["Earlier", "Later", "Todo", "Completed"])
        #expect(RecordDisplaySupport.displayTime(for: earlierReminder) == earlierReminder.dueAt)
    }

    @Test("separates active records from completed history")
    func separatesActiveRecordsFromHistory() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let activeTodo = Record(
            kind: .todo,
            title: "Active todo",
            updatedAt: now.addingTimeInterval(60)
        )
        let completedTodo = Record(
            kind: .todo,
            title: "Done todo",
            status: .completed,
            updatedAt: now.addingTimeInterval(120),
            completedAt: now.addingTimeInterval(120)
        )
        let completedReminder = Record(
            kind: .reminder,
            title: "Done reminder",
            status: .completed,
            updatedAt: now.addingTimeInterval(180),
            completedAt: now.addingTimeInterval(180)
        )

        let records = [completedTodo, activeTodo, completedReminder]

        #expect(RecordDisplaySupport.activeRecordsForDisplay(records).map(\.title) == ["Active todo"])
        #expect(RecordDisplaySupport.historyRecordsForDisplay(records).map(\.title) == [
            "Done reminder",
            "Done todo"
        ])
    }

    @Test("marks only active past reminders as overdue")
    func marksOnlyActivePastRemindersAsOverdue() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let pastReminder = Record(
            kind: .reminder,
            title: "Past",
            reminderAt: now.addingTimeInterval(-60)
        )
        let futureReminder = Record(
            kind: .reminder,
            title: "Future",
            reminderAt: now.addingTimeInterval(60)
        )
        let completedPastReminder = Record(
            kind: .reminder,
            title: "Completed",
            status: .completed,
            reminderAt: now.addingTimeInterval(-60)
        )
        let pastTodo = Record(
            kind: .todo,
            title: "Todo",
            dueAt: now.addingTimeInterval(-60)
        )

        #expect(RecordDisplaySupport.isOverdue(pastReminder, now: now))
        #expect(!RecordDisplaySupport.isOverdue(futureReminder, now: now))
        #expect(!RecordDisplaySupport.isOverdue(completedPastReminder, now: now))
        #expect(!RecordDisplaySupport.isOverdue(pastTodo, now: now))
        #expect(RecordDisplaySupport.hasOverdueReminder([futureReminder, pastReminder], now: now))
        #expect(!RecordDisplaySupport.hasOverdueReminder([futureReminder, completedPastReminder, pastTodo], now: now))
    }
}
