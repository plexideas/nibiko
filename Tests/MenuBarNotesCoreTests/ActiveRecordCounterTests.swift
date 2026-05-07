import Foundation
import Testing
@testable import MenuBarNotesCore

@Suite("Active record count")
struct ActiveRecordCounterTests {
    @Test("counts only unfinished actionable records")
    func countsOnlyUnfinishedActionableRecords() {
        let records = [
            Record(kind: .todo, title: "Active todo", status: .active),
            Record(kind: .todo, title: "Done todo", status: .completed),
            Record(kind: .reminder, title: "Active reminder", status: .active),
            Record(kind: .note, title: "Reference note", status: .active)
        ]

        #expect(ActiveRecordCounter.count(records) == 2)
    }
}
