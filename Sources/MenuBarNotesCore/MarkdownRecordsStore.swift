import Foundation

public struct MarkdownRecordsStore: Sendable {
    private let recordsFileName = "MenuBarNotes.md"
    private let recordBlockStart = "<!-- menuBarNotesRecord -->"
    private let recordBlockEnd = "<!-- /menuBarNotesRecord -->"

    public init() {}

    public func loadRecords(in directory: URL) throws -> [Record] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        let records: [Record]
        let fileURL = recordsURL(in: directory)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            records = try parseRecordsFile(at: fileURL)
        } else {
            let legacyRecords = try loadLegacyRecords(in: directory)
            if !legacyRecords.isEmpty {
                try? writeRecords(legacyRecords, in: directory)
            }
            records = legacyRecords
        }

        return sortedRecords(records)
    }

    @discardableResult
    public func addRecord(
        _ draft: RecordDraft,
        in directory: URL,
        now: Date = Date()
    ) throws -> Record {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw MarkdownRecordsStoreError.emptyTitle
        }

        let record = Record(
            kind: draft.kind,
            title: title,
            body: draft.body.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            updatedAt: now,
            dueAt: draft.dueAt,
            reminderAt: draft.reminderAt
        )
        try writeRecord(record, in: directory)
        return record
    }

    public func completeRecord(
        id: String,
        in directory: URL,
        completedAt: Date = Date()
    ) throws {
        var records = try loadRecordsForMutation(in: directory)
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw MarkdownRecordsStoreError.malformedRecord
        }

        records[index].status = .completed
        records[index].completedAt = completedAt
        records[index].updatedAt = completedAt
        try writeRecords(records, in: directory)
    }

    public func deleteRecord(id: String, in directory: URL) throws {
        var records = try loadRecordsForMutation(in: directory)
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw MarkdownRecordsStoreError.malformedRecord
        }

        records.remove(at: index)
        try writeRecords(records, in: directory)
    }

    public func writeRecord(_ record: Record, in directory: URL) throws {
        var records = try loadRecordsForMutation(in: directory)
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }

        try writeRecords(records, in: directory)
    }

    private func loadLegacyRecords(in directory: URL) throws -> [Record] {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return fileURLs
            .filter { $0.pathExtension.lowercased() == "md" && $0.lastPathComponent != recordsFileName }
            .compactMap { try? parseRecord(at: $0) }
    }

    private func loadRecordsForMutation(in directory: URL) throws -> [Record] {
        if FileManager.default.fileExists(atPath: directory.path) {
            return try loadRecords(in: directory)
        }

        return []
    }

    private func writeRecords(_ records: [Record], in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try serializedRecordsFile(for: records).write(
            to: recordsURL(in: directory),
            atomically: true,
            encoding: .utf8
        )
    }

    private func recordsURL(in directory: URL) -> URL {
        directory.appendingPathComponent(recordsFileName)
    }

    private func sortedRecords(_ records: [Record]) -> [Record] {
        records.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status == .active
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func parseRecordsFile(at fileURL: URL) throws -> [Record] {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return parseRecordBlocks(in: text).compactMap { try? parseRecord(from: $0) }
    }

    private func parseRecordBlocks(in text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [String] = []
        var index = lines.startIndex

        while index < lines.endIndex {
            guard lines[index] == recordBlockStart else {
                index = lines.index(after: index)
                continue
            }

            let blockStart = lines.index(after: index)
            guard let blockEnd = lines[blockStart...].firstIndex(of: recordBlockEnd) else {
                break
            }

            blocks.append(lines[blockStart..<blockEnd].joined(separator: "\n"))
            index = lines.index(after: blockEnd)
        }

        return blocks
    }

    private func parseRecord(at fileURL: URL) throws -> Record {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return try parseRecord(from: text)
    }

    private func parseRecord(from text: String) throws -> Record {
        let lines = text.components(separatedBy: .newlines)
        guard lines.first == "---", let endIndex = lines.dropFirst().firstIndex(of: "---") else {
            throw MarkdownRecordsStoreError.malformedRecord
        }

        let frontMatter = parseFrontMatter(Array(lines[1..<endIndex]))
        guard
            frontMatter["menuBarNotesRecord"] == "v1",
            let id = frontMatter["id"],
            let kindValue = frontMatter["kind"],
            let kind = RecordKind(rawValue: kindValue),
            let statusValue = frontMatter["status"],
            let status = RecordStatus(rawValue: statusValue),
            let createdAtValue = frontMatter["createdAt"],
            let createdAt = Self.date(from: createdAtValue),
            let updatedAtValue = frontMatter["updatedAt"],
            let updatedAt = Self.date(from: updatedAtValue)
        else {
            throw MarkdownRecordsStoreError.malformedRecord
        }

        let content = lines[(endIndex + 1)...].joined(separator: "\n")
        let parsedContent = parseContent(content, kind: kind)
        guard !parsedContent.title.isEmpty else {
            throw MarkdownRecordsStoreError.malformedRecord
        }

        return Record(
            id: id,
            kind: kind,
            title: parsedContent.title,
            body: parsedContent.body,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            dueAt: frontMatter["dueAt"].flatMap(Self.date(from:)),
            reminderAt: frontMatter["reminderAt"].flatMap(Self.date(from:)),
            completedAt: frontMatter["completedAt"].flatMap(Self.date(from:))
        )
    }

    private func parseFrontMatter(_ lines: [String]) -> [String: String] {
        var values: [String: String] = [:]
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                continue
            }
            values[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                String(parts[1]).trimmingCharacters(in: .whitespaces)
        }
        return values
    }

    private func parseContent(_ content: String, kind: RecordKind) -> (title: String, body: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmedContent.components(separatedBy: .newlines)
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return ("", "")
        }

        let title: String
        if firstLine.hasPrefix("# ") {
            title = String(firstLine.dropFirst(2))
        } else if kind.isActionable, firstLine.hasPrefix("- [ ] ") || firstLine.hasPrefix("- [x] ") {
            title = String(firstLine.dropFirst(6))
        } else {
            title = firstLine
        }

        let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (title.trimmingCharacters(in: .whitespacesAndNewlines), body)
    }

    private func serializedRecordsFile(for records: [Record]) -> String {
        var lines = ["# Menu Bar Notes", ""]
        let recordsByCreation = records.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id < rhs.id
        }

        for record in recordsByCreation {
            lines.append(recordBlockStart)
            lines.append(serializedMarkdown(for: record).trimmingCharacters(in: .newlines))
            lines.append(recordBlockEnd)
            lines.append("")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func serializedMarkdown(for record: Record) -> String {
        var lines = [
            "---",
            "menuBarNotesRecord: v1",
            "id: \(record.id)",
            "kind: \(record.kind.rawValue)",
            "status: \(record.status.rawValue)",
            "createdAt: \(Self.string(from: record.createdAt))",
            "updatedAt: \(Self.string(from: record.updatedAt))"
        ]

        if let dueAt = record.dueAt {
            lines.append("dueAt: \(Self.string(from: dueAt))")
        }
        if let reminderAt = record.reminderAt {
            lines.append("reminderAt: \(Self.string(from: reminderAt))")
        }
        if let completedAt = record.completedAt {
            lines.append("completedAt: \(Self.string(from: completedAt))")
        }

        lines.append("---")

        switch record.kind {
        case .note:
            lines.append("# \(singleLine(record.title))")
        case .todo, .reminder:
            let checkbox = record.status == .completed ? "- [x]" : "- [ ]"
            lines.append("\(checkbox) \(singleLine(record.title))")
        }

        let body = record.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty {
            lines.append("")
            lines.append(body)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func singleLine(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func date(from value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private static func string(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

public enum MarkdownRecordsStoreError: Error, Equatable, Sendable {
    case emptyTitle
    case malformedRecord
}
