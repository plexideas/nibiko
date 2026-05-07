import Foundation

public struct MarkdownRecordsStore: Sendable {
    public init() {}

    public func loadRecords(in directory: URL) throws -> [Record] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let records = fileURLs
            .filter { $0.pathExtension.lowercased() == "md" }
            .compactMap { try? parseRecord(at: $0) }

        return records.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status == .active
            }
            return lhs.updatedAt > rhs.updatedAt
        }
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
        var record = try parseRecord(at: recordURL(for: id, in: directory))
        record.status = .completed
        record.completedAt = completedAt
        record.updatedAt = completedAt
        try writeRecord(record, in: directory)
    }

    public func writeRecord(_ record: Record, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try serializedMarkdown(for: record).write(
            to: recordURL(for: record.id, in: directory),
            atomically: true,
            encoding: .utf8
        )
    }

    private func recordURL(for id: String, in directory: URL) -> URL {
        directory.appendingPathComponent(safeFileName(for: id)).appendingPathExtension("md")
    }

    private func safeFileName(for id: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = id.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let fileName = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return fileName.isEmpty ? UUID().uuidString : fileName
    }

    private func parseRecord(at fileURL: URL) throws -> Record {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
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
