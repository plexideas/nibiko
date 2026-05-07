import Foundation
import Testing
@testable import MenuBarNotesCore

@Suite("Markdown records storage")
struct MarkdownRecordsStoreTests {
    @Test("writes and reads note and todo records from Markdown")
    func writesAndReadsRecords() throws {
        let directory = try temporaryDirectory()
        let store = MarkdownRecordsStore()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

        let note = try store.addRecord(
            RecordDraft(kind: .note, title: "Idea", body: "Keep the body portable."),
            in: directory,
            now: createdAt
        )
        let todo = try store.addRecord(
            RecordDraft(kind: .todo, title: "Ship phase 2"),
            in: directory,
            now: createdAt.addingTimeInterval(60)
        )

        let records = try store.loadRecords(in: directory)

        #expect(records.map(\.id).contains(note.id))
        #expect(records.map(\.id).contains(todo.id))
        #expect(records.first(where: { $0.id == note.id })?.body == "Keep the body portable.")
        #expect(records.first(where: { $0.id == todo.id })?.status == .active)
    }

    @Test("writes and reads reminder time metadata")
    func writesAndReadsReminderTimeMetadata() throws {
        let directory = try temporaryDirectory()
        let store = MarkdownRecordsStore()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let dueAt = createdAt.addingTimeInterval(3_600)
        let reminderAt = createdAt.addingTimeInterval(1_800)

        let reminder = try store.addRecord(
            RecordDraft(
                kind: .reminder,
                title: "Review launch notes",
                dueAt: dueAt,
                reminderAt: reminderAt
            ),
            in: directory,
            now: createdAt
        )

        let reloaded = try #require(try store.loadRecords(in: directory).first(where: { $0.id == reminder.id }))
        #expect(reloaded.kind == .reminder)
        #expect(reloaded.dueAt == dueAt)
        #expect(reloaded.reminderAt == reminderAt)
    }

    @Test("completes a todo record without dropping its Markdown body")
    func completesTodo() throws {
        let directory = try temporaryDirectory()
        let store = MarkdownRecordsStore()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let completedAt = createdAt.addingTimeInterval(120)
        let todo = try store.addRecord(
            RecordDraft(kind: .todo, title: "Check the box", body: "Completion should keep this note."),
            in: directory,
            now: createdAt
        )

        try store.completeRecord(id: todo.id, in: directory, completedAt: completedAt)

        let reloaded = try #require(try store.loadRecords(in: directory).first(where: { $0.id == todo.id }))
        #expect(reloaded.status == .completed)
        #expect(reloaded.completedAt == completedAt)
        #expect(reloaded.body == "Completion should keep this note.")
    }

    @Test("malformed Markdown files do not prevent valid records from loading")
    func skipsMalformedRecords() throws {
        let directory = try temporaryDirectory()
        let store = MarkdownRecordsStore()
        _ = try store.addRecord(RecordDraft(kind: .note, title: "Valid"), in: directory)
        try "not front matter".write(
            to: directory.appendingPathComponent("broken.md"),
            atomically: true,
            encoding: .utf8
        )

        let records = try store.loadRecords(in: directory)

        #expect(records.count == 1)
        #expect(records.first?.title == "Valid")
    }

    @MainActor
    @Test("explicit reload reflects externally modified records")
    func reloadsExternallyModifiedRecords() throws {
        let directory = try temporaryDirectory()
        let store = MarkdownRecordsStore()
        let todo = try store.addRecord(RecordDraft(kind: .todo, title: "Original title"), in: directory)
        let listStore = RecordListStore(directory: directory, storage: store, watchesDirectoryChanges: false)

        var externallyEdited = todo
        externallyEdited.title = "Edited from another editor"
        externallyEdited.updatedAt = todo.updatedAt.addingTimeInterval(60)
        try store.writeRecord(externallyEdited, in: directory)
        listStore.reload()

        #expect(listStore.records.map(\.title) == ["Edited from another editor"])
    }

    @MainActor
    @Test("directory watcher reloads externally added records")
    func directoryWatcherReloadsExternallyAddedRecords() async throws {
        let directory = try temporaryDirectory()
        let store = MarkdownRecordsStore()
        let listStore = RecordListStore(directory: directory, storage: store)

        let record = try store.addRecord(RecordDraft(kind: .note, title: "Watched note"), in: directory)
        await waitUntil {
            listStore.records.contains { $0.id == record.id }
        }

        #expect(listStore.records.map(\.title).contains("Watched note"))
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MenuBarNotesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
