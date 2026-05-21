import EventKit
import Foundation
import NibikoCore

@MainActor
final class EventKitReminderProvider: ObservableObject {
    @Published private(set) var records: [Record] = []

    private let eventStore = EKEventStore()
    private var eventStoreChangedObserver: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        eventStoreChangedObserver = notificationCenter.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshIfAuthorized()
            }
        }
    }

    deinit {
        MainActor.assumeIsolated {
            if let eventStoreChangedObserver {
                NotificationCenter.default.removeObserver(eventStoreChangedObserver)
            }
        }
    }

    func refreshIfAuthorized() {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            records = []
            return
        }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        eventStore.fetchReminders(matching: predicate) { [weak self] reminders in
            let records = (reminders ?? []).map(Self.record(from:))
            Task { @MainActor in
                self?.records = RecordDisplaySupport.activeRecordsForDisplay(records)
            }
        }
    }

    func completeRecord(id: String) {
        updateReminder(id: id) { reminder in
            reminder.isCompleted = true
            reminder.completionDate = Date()
        }
    }

    func deleteRecord(id: String) {
        guard let reminderIdentifier = Self.reminderIdentifier(fromRecordID: id),
              let reminder = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder
        else {
            return
        }

        do {
            try eventStore.remove(reminder, commit: true)
            refreshIfAuthorized()
        } catch {
            NSLog("Nibiko reminder delete error: \(error.localizedDescription)")
        }
    }

    static func isAppleReminderRecordID(_ id: String) -> Bool {
        reminderIdentifier(fromRecordID: id) != nil
    }

    static func mergedRecords(localRecords: [Record], appleReminderRecords: [Record]) -> [Record] {
        let localReminderKeys = Set(localRecords.compactMap(dedupeKey(for:)))
        let visibleAppleRecords = appleReminderRecords.filter { record in
            guard let key = dedupeKey(for: record) else {
                return true
            }

            return !localReminderKeys.contains(key)
        }

        return localRecords + visibleAppleRecords
    }

    private func updateReminder(id: String, update: (EKReminder) -> Void) {
        guard let reminderIdentifier = Self.reminderIdentifier(fromRecordID: id),
              let reminder = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder
        else {
            return
        }

        update(reminder)

        do {
            try eventStore.save(reminder, commit: true)
            refreshIfAuthorized()
        } catch {
            NSLog("Nibiko reminder update error: \(error.localizedDescription)")
        }
    }

    private static func record(from reminder: EKReminder) -> Record {
        let dueAt = reminder.dueDateComponents.flatMap { components in
            Calendar.current.date(from: components)
        }

        return Record(
            id: "apple-reminder-\(reminder.calendarItemIdentifier)",
            kind: .reminder,
            title: reminder.title ?? "Reminder",
            body: reminder.notes ?? "",
            status: reminder.isCompleted ? .completed : .active,
            createdAt: reminder.creationDate ?? Date(),
            updatedAt: reminder.lastModifiedDate ?? Date(),
            dueAt: dueAt,
            reminderAt: reminder.alarms?.compactMap(\.absoluteDate).sorted().first
        )
    }

    private static func reminderIdentifier(fromRecordID id: String) -> String? {
        let prefix = "apple-reminder-"
        guard id.hasPrefix(prefix) else {
            return nil
        }

        return String(id.dropFirst(prefix.count))
    }

    private static func dedupeKey(for record: Record) -> String? {
        guard record.kind == .reminder else {
            return nil
        }

        let scheduledAt = RecordDisplaySupport.displayTime(for: record)
        let scheduledMinute = scheduledAt.map { Int($0.timeIntervalSince1970 / 60) } ?? -1
        let title = record.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(title)-\(scheduledMinute)"
    }
}
