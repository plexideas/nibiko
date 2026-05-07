import Foundation
import Testing
@testable import MenuBarNotesCore

@Suite("Markdown records storage")
struct MarkdownRecordsStoreTests {
    @Test("writes and reads note and todo records from one Markdown file")
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
        let markdownFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "md" }

        #expect(records.map(\.id).contains(note.id))
        #expect(records.map(\.id).contains(todo.id))
        #expect(records.first(where: { $0.id == note.id })?.body == "Keep the body portable.")
        #expect(records.first(where: { $0.id == todo.id })?.status == .active)
        #expect(markdownFiles.map(\.lastPathComponent) == ["MenuBarNotes.md"])
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

    @Test("legacy separate Markdown files are consolidated into the shared file")
    func migratesLegacySeparateFilesToSharedFile() throws {
        let directory = try temporaryDirectory()
        let store = MarkdownRecordsStore()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

        try legacyRecordMarkdown(id: "legacy-note", kind: .note, title: "Legacy idea", createdAt: createdAt)
            .write(
                to: directory.appendingPathComponent("legacy-note.md"),
                atomically: true,
                encoding: .utf8
            )
        try legacyRecordMarkdown(
            id: "legacy-todo",
            kind: .todo,
            title: "Legacy task",
            createdAt: createdAt.addingTimeInterval(60)
        )
            .write(
                to: directory.appendingPathComponent("legacy-todo.md"),
                atomically: true,
                encoding: .utf8
            )

        let records = try store.loadRecords(in: directory)
        let sharedMarkdown = try String(
            contentsOf: directory.appendingPathComponent("MenuBarNotes.md"),
            encoding: .utf8
        )

        #expect(records.map(\.title).contains("Legacy idea"))
        #expect(records.map(\.title).contains("Legacy task"))
        #expect(sharedMarkdown.contains("id: legacy-note"))
        #expect(sharedMarkdown.contains("id: legacy-todo"))
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

    @Test("deletes a record from the shared Markdown file")
    func deletesRecord() throws {
        let directory = try temporaryDirectory()
        let store = MarkdownRecordsStore()
        let note = try store.addRecord(RecordDraft(kind: .note, title: "Remove me"), in: directory)
        let todo = try store.addRecord(RecordDraft(kind: .todo, title: "Keep me"), in: directory)

        try store.deleteRecord(id: note.id, in: directory)

        let records = try store.loadRecords(in: directory)
        let sharedMarkdown = try String(
            contentsOf: directory.appendingPathComponent("MenuBarNotes.md"),
            encoding: .utf8
        )

        #expect(records.map(\.id) == [todo.id])
        #expect(!sharedMarkdown.contains("id: \(note.id)"))
        #expect(sharedMarkdown.contains("id: \(todo.id)"))
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

    private func legacyRecordMarkdown(id: String, kind: RecordKind, title: String, createdAt: Date) -> String {
        let timestamp = ISO8601DateFormatter().string(from: createdAt)
        let markdownTitle = kind == .note ? "# \(title)" : "- [ ] \(title)"

        return """
        ---
        menuBarNotesRecord: v1
        id: \(id)
        kind: \(kind.rawValue)
        status: active
        createdAt: \(timestamp)
        updatedAt: \(timestamp)
        ---
        \(markdownTitle)
        """
    }
}
