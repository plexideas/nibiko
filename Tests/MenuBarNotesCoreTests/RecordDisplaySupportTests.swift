import Foundation
import Testing
@testable import MenuBarNotesCore

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
}
