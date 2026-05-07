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
    public var dueAt: Date?
    public var reminderAt: Date?

    public init(
        kind: RecordKind,
        title: String,
        body: String = "",
        dueAt: Date? = nil,
        reminderAt: Date? = nil
    ) {
        self.kind = kind
        self.title = title
        self.body = body
        self.dueAt = dueAt
        self.reminderAt = reminderAt
    }
}

public enum ActiveRecordCounter {
    public static func count(_ records: [Record]) -> Int {
        records.filter { record in
            record.kind.isActionable && record.status != .completed
        }.count
    }
}

public enum RecordDisplaySupport {
    public static func activeRecordsForDisplay(_ records: [Record]) -> [Record] {
        recordsForDisplay(records.filter { $0.status == .active })
    }

    public static func historyRecordsForDisplay(_ records: [Record]) -> [Record] {
        records
            .filter { $0.status == .completed }
            .sorted { lhs, rhs in
                let lhsCompletedAt = lhs.completedAt ?? lhs.updatedAt
                let rhsCompletedAt = rhs.completedAt ?? rhs.updatedAt
                if lhsCompletedAt != rhsCompletedAt {
                    return lhsCompletedAt > rhsCompletedAt
                }

                return lhs.updatedAt > rhs.updatedAt
            }
    }

    public static func recordsForDisplay(_ records: [Record]) -> [Record] {
        records.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status == .active
            }

            let lhsDisplayAt = displayTime(for: lhs)
            let rhsDisplayAt = displayTime(for: rhs)
            if lhsDisplayAt != rhsDisplayAt {
                switch (lhsDisplayAt, rhsDisplayAt) {
                case let (lhsDisplayAt?, rhsDisplayAt?):
                    return lhsDisplayAt < rhsDisplayAt
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }
            }

            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public static func displayTime(for record: Record) -> Date? {
        guard record.kind == .reminder else {
            return nil
        }

        return record.reminderAt ?? record.dueAt
    }
}
