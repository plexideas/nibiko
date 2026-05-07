import AppKit
import EventKit
import Foundation
import MenuBarNotesCore

final class EventKitCalendarProvider: CalendarEventProviding {
    private let eventStore = EKEventStore()

    func currentPermissionState() async -> PermissionState {
        permissionState(from: EKEventStore.authorizationStatus(for: .event))
    }

    func requestPermission() async -> PermissionState {
        do {
            let isAllowed = try await eventStore.requestFullAccessToEvents()
            return isAllowed ? .allowed : .denied
        } catch {
            return .unavailable
        }
    }

    func availableSources() async throws -> [CalendarSource] {
        eventStore.calendars(for: .event).map { calendar in
            CalendarSource(id: calendar.calendarIdentifier, title: calendar.title)
        }
    }

    func events(startingAt startDate: Date, endingAt endDate: Date, sourceIDs: Set<String>) async throws -> [CalendarEvent] {
        guard !sourceIDs.isEmpty else {
            return []
        }

        let calendars = eventStore.calendars(for: .event).filter { calendar in
            sourceIDs.contains(calendar.calendarIdentifier)
        }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)

        return eventStore.events(matching: predicate).map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? "\(event.calendar.calendarIdentifier)-\(event.startDate.timeIntervalSince1970)",
                sourceID: event.calendar.calendarIdentifier,
                title: event.title ?? CalendarEvent.fallbackTitle,
                startsAt: event.startDate,
                endsAt: event.endDate
            )
        }
    }

    func openCalendar() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app", isDirectory: true))
    }

    private func permissionState(from status: EKAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .fullAccess:
            return .allowed
        case .writeOnly:
            return .denied
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .unavailable
        }
    }
}
