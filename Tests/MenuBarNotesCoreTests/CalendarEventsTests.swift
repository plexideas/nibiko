import Foundation
import Testing
@testable import MenuBarNotesCore

@Suite("Calendar events")
struct CalendarEventsTests {
    @Test("orders sources by display name")
    func ordersSourcesByDisplayName() {
        let sources = [
            CalendarSource(id: "personal", title: "Personal"),
            CalendarSource(id: "work", title: "work"),
            CalendarSource(id: "family", title: "Family")
        ]

        #expect(CalendarDisplaySupport.orderedSources(sources).map(\.id) == ["family", "personal", "work"])
    }

    @Test("uses all available sources until the user stores an explicit selection")
    func resolvesSelectedSources() {
        let sources = [
            CalendarSource(id: "work", title: "Work"),
            CalendarSource(id: "home", title: "Home")
        ]

        #expect(CalendarDisplaySupport.selectedSourceIDs(from: nil, availableSources: sources) == ["work", "home"])
        #expect(CalendarDisplaySupport.selectedSourceIDs(from: [], availableSources: sources) == [])
        #expect(CalendarDisplaySupport.selectedSourceIDs(from: ["work"], availableSources: sources) == ["work"])
    }

    @Test("filters selected upcoming events and orders ties by title")
    func filtersAndOrdersUpcomingEvents() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let events = [
            Self.event(id: "past", sourceID: "work", title: "Past", startOffset: -60, duration: 30, now: now),
            Self.event(id: "ignored", sourceID: "home", title: "Home", startOffset: 300, duration: 30, now: now),
            Self.event(id: "b", sourceID: "work", title: "Beta", startOffset: 600, duration: 30, now: now),
            Self.event(id: "a", sourceID: "work", title: "Alpha", startOffset: 600, duration: 30, now: now),
            Self.event(id: "late", sourceID: "work", title: "Late", startOffset: 90_000, duration: 30, now: now)
        ]

        let upcoming = CalendarDisplaySupport.upcomingEvents(
            from: events,
            selectedSourceIDs: ["work"],
            now: now,
            through: now.addingTimeInterval(24 * 60 * 60)
        )

        #expect(upcoming.map { $0.id } == ["a", "b"])
    }

    @MainActor
    @Test("does not request permission when loading without user intent")
    func doesNotRequestPermissionWithoutIntent() async {
        let provider = FakeCalendarProvider(permissionState: .notDetermined)
        let store = CalendarEventsStore(provider: provider)

        await store.reload(selectedSourceIDs: nil)

        #expect(provider.requestPermissionCallCount == 0)
        #expect(store.permissionState == .notDetermined)
        #expect(store.sources.isEmpty)
        #expect(store.events.isEmpty)
    }

    @MainActor
    @Test("denied permission clears calendar data without erroring")
    func deniedPermissionClearsCalendarData() async {
        let provider = FakeCalendarProvider(permissionState: .denied)
        let store = CalendarEventsStore(provider: provider)

        await store.reload(selectedSourceIDs: nil, requestPermissionIfNeeded: true)

        #expect(provider.availableSourcesCallCount == 0)
        #expect(provider.eventsCallCount == 0)
        #expect(store.permissionState == .denied)
        #expect(store.lastErrorDescription == nil)
    }

    @MainActor
    @Test("requested allowed permission loads selected upcoming events")
    func requestedAllowedPermissionLoadsSelectedEvents() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = FakeCalendarProvider(
            permissionState: .notDetermined,
            requestedPermissionState: .allowed,
            sources: [
                CalendarSource(id: "home", title: "Home"),
                CalendarSource(id: "work", title: "Work")
            ],
            events: [
                Self.event(id: "home", sourceID: "home", title: "Dinner", startOffset: 300, duration: 60, now: now),
                Self.event(id: "standup", sourceID: "work", title: "Standup", startOffset: 120, duration: 30, now: now)
            ]
        )
        let store = CalendarEventsStore(provider: provider, now: { now })

        await store.reload(selectedSourceIDs: ["work"], requestPermissionIfNeeded: true)

        #expect(provider.requestPermissionCallCount == 1)
        #expect(provider.requestedSourceIDs == ["work"])
        #expect(store.permissionState == PermissionState.allowed)
        #expect(store.sources.map { $0.id } == ["home", "work"])
        #expect(store.events.map { $0.id } == ["standup"])
    }

    private static func event(
        id: String,
        sourceID: String,
        title: String,
        startOffset: TimeInterval,
        duration: TimeInterval,
        now: Date
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            sourceID: sourceID,
            title: title,
            startsAt: now.addingTimeInterval(startOffset),
            endsAt: now.addingTimeInterval(startOffset + duration * 60)
        )
    }
}

private final class FakeCalendarProvider: CalendarEventProviding {
    var permissionState: PermissionState
    var requestedPermissionState: PermissionState
    var sources: [CalendarSource]
    var eventData: [CalendarEvent]
    var requestedSourceIDs: Set<String>?
    var requestPermissionCallCount = 0
    var availableSourcesCallCount = 0
    var eventsCallCount = 0
    var didOpenCalendar = false

    init(
        permissionState: PermissionState,
        requestedPermissionState: PermissionState = .denied,
        sources: [CalendarSource] = [],
        events: [CalendarEvent] = []
    ) {
        self.permissionState = permissionState
        self.requestedPermissionState = requestedPermissionState
        self.sources = sources
        self.eventData = events
    }

    func currentPermissionState() async -> PermissionState {
        permissionState
    }

    func requestPermission() async -> PermissionState {
        requestPermissionCallCount += 1
        permissionState = requestedPermissionState
        return requestedPermissionState
    }

    func availableSources() async throws -> [CalendarSource] {
        availableSourcesCallCount += 1
        return sources
    }

    func events(startingAt startDate: Date, endingAt endDate: Date, sourceIDs: Set<String>) async throws -> [CalendarEvent] {
        eventsCallCount += 1
        requestedSourceIDs = sourceIDs
        return eventData.filter { event in
            sourceIDs.contains(event.sourceID)
                && event.startsAt >= startDate
                && event.startsAt <= endDate
        }
    }

    func openCalendar() {
        didOpenCalendar = true
    }
}
