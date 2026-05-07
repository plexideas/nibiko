import Foundation
import Testing
@testable import MenuBarNotesCore

@MainActor
@Suite("Quick-add capture")
struct QuickAddCaptureServiceTests {
    @Test("popover and hotkey capture create equivalent records")
    func popoverAndHotkeyCaptureAreEquivalent() throws {
        let popoverDirectory = try temporaryDirectory()
        let hotkeyDirectory = try temporaryDirectory()
        let draft = RecordDraft(kind: .todo, title: "Ship quick add", body: "Same storage path.")

        let popoverRecord = try service(directory: popoverDirectory).capture(
            QuickAddCaptureRequest(source: .popover, draft: draft)
        )
        let hotkeyRecord = try service(directory: hotkeyDirectory).capture(
            QuickAddCaptureRequest(source: .globalHotkey, draft: draft)
        )

        #expect(popoverRecord.kind == hotkeyRecord.kind)
        #expect(popoverRecord.title == hotkeyRecord.title)
        #expect(popoverRecord.body == hotkeyRecord.body)
        #expect(popoverRecord.status == hotkeyRecord.status)
    }

    @Test("reminder capture schedules notifications after storage succeeds")
    func reminderCaptureSchedulesNotification() throws {
        let directory = try temporaryDirectory()
        var scheduledRecord: Record?
        let captureService = service(directory: directory) { record in
            scheduledRecord = record
        }
        let reminderAt = Date(timeIntervalSince1970: 1_800_000_600)

        let record = try captureService.capture(
            QuickAddCaptureRequest(
                source: .globalHotkey,
                draft: RecordDraft(
                    kind: .reminder,
                    title: "Check oven",
                    dueAt: reminderAt,
                    reminderAt: reminderAt
                )
            )
        )

        #expect(scheduledRecord?.id == record.id)
        #expect(record.reminderAt == reminderAt)
    }

    private func service(
        directory: URL,
        scheduleReminder: @escaping @MainActor (Record) -> Void = { _ in }
    ) -> QuickAddCaptureService {
        QuickAddCaptureService(
            recordListStore: RecordListStore(directory: directory, watchesDirectoryChanges: false),
            scheduleReminder: scheduleReminder
        )
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MenuBarNotesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
