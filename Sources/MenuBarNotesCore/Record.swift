import Foundation

public enum RecordKind: String, Codable, CaseIterable, Equatable, Sendable {
    case note
    case todo
    case reminder

    public var isActionable: Bool {
        switch self {
        case .note:
            return false
        case .todo, .reminder:
            return true
        }
    }
}

public enum RecordStatus: String, Codable, Equatable, Sendable {
    case active
    case completed
}

public struct Record: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: RecordKind
    public var title: String
    public var body: String
    public var status: RecordStatus
    public var createdAt: Date
    public var updatedAt: Date
    public var dueAt: Date?
    public var reminderAt: Date?
    public var completedAt: Date?

    public init(
        id: String = UUID().uuidString,
        kind: RecordKind,
        title: String,
        body: String = "",
        status: RecordStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        dueAt: Date? = nil,
        reminderAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dueAt = dueAt
        self.reminderAt = reminderAt
        self.completedAt = completedAt
    }
}

public struct RecordDraft: Equatable, Sendable {
    public var kind: RecordKind
    public var title: String
    public var body: String

    public init(kind: RecordKind, title: String, body: String = "") {
        self.kind = kind
        self.title = title
        self.body = body
    }
}

public enum ActiveRecordCounter {
    public static func count(_ records: [Record]) -> Int {
        records.filter { record in
            record.kind.isActionable && record.status != .completed
        }.count
    }
}
