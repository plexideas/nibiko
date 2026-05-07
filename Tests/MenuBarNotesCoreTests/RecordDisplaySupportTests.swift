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
}
