import Combine
import Darwin
import Foundation

@MainActor
public final class RecordListStore: ObservableObject {
    @Published public private(set) var records: [Record] = []
    @Published public private(set) var lastErrorDescription: String?

    public var activeCount: Int {
        ActiveRecordCounter.count(records)
    }

    public var hasStorageDirectory: Bool {
        directory != nil
    }

    private let storage: MarkdownRecordsStore
    private let watchesDirectoryChanges: Bool
    private let watchQueue = DispatchQueue(label: "MenuBarNotes.RecordListStore.watch")
    private var directory: URL?
    private var watcher: DispatchSourceFileSystemObject?

    public init(
        directory: URL? = nil,
        storage: MarkdownRecordsStore = MarkdownRecordsStore(),
        watchesDirectoryChanges: Bool = true
    ) {
        self.storage = storage
        self.watchesDirectoryChanges = watchesDirectoryChanges
        setDirectory(directory)
    }

    deinit {
        watcher?.cancel()
    }

    public func setDirectory(_ directory: URL?) {
        guard self.directory != directory else {
            return
        }

        self.directory = directory
        reload()
        startWatchingDirectory()
    }

    @discardableResult
    public func addNote(title: String) throws -> Record {
        try addRecord(RecordDraft(kind: .note, title: title))
    }

    @discardableResult
    public func addTodo(title: String) throws -> Record {
        try addRecord(RecordDraft(kind: .todo, title: title))
    }

    public func completeTodo(id: String) throws {
        guard let directory else {
            throw RecordListStoreError.missingStorageDirectory
        }

        try storage.completeRecord(id: id, in: directory)
        reload()
    }

    public func reload() {
        guard let directory else {
            records = []
            lastErrorDescription = nil
            return
        }

        do {
            records = try storage.loadRecords(in: directory)
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    private func addRecord(_ draft: RecordDraft) throws -> Record {
        guard let directory else {
            throw RecordListStoreError.missingStorageDirectory
        }

        let record = try storage.addRecord(draft, in: directory)
        reload()
        return record
    }

    private func startWatchingDirectory() {
        watcher?.cancel()
        watcher = nil

        guard watchesDirectoryChanges, let directory else {
            return
        }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .attrib, .extend],
            queue: watchQueue
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.reload()
            }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        watcher = source
        source.resume()
    }
}

public enum RecordListStoreError: Error, Equatable, Sendable {
    case missingStorageDirectory
}
