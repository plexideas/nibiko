import Foundation

public enum QuickAddCaptureSource: Equatable, Sendable {
    case popover
    case globalHotkey
}

public struct QuickAddCaptureRequest: Equatable, Sendable {
    public var source: QuickAddCaptureSource
    public var draft: RecordDraft

    public init(source: QuickAddCaptureSource, draft: RecordDraft) {
        self.source = source
        self.draft = draft
    }
}

@MainActor
public final class QuickAddCaptureService {
    private let recordListStore: RecordListStore
    private let scheduleReminder: @MainActor (Record) -> Void

    public init(
        recordListStore: RecordListStore,
        scheduleReminder: @escaping @MainActor (Record) -> Void = { _ in }
    ) {
        self.recordListStore = recordListStore
        self.scheduleReminder = scheduleReminder
    }

    @discardableResult
    public func capture(_ request: QuickAddCaptureRequest) throws -> Record {
        let record = try recordListStore.addDraft(request.draft)
        if record.kind == .reminder {
            scheduleReminder(record)
        }

        return record
    }
}
