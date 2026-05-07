import Combine
import Foundation

public enum PermissionState: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
    case unavailable
}

public struct CalendarSource: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = trimmedTitle.isEmpty ? "Calendar" : trimmedTitle
    }
}

public struct CalendarEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var sourceID: String
    public var title: String
    public var startsAt: Date
    public var endsAt: Date

    public init(id: String, sourceID: String, title: String, startsAt: Date, endsAt: Date) {
        self.id = id
        self.sourceID = sourceID
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = trimmedTitle.isEmpty ? "Untitled Event" : trimmedTitle
        self.startsAt = startsAt
        self.endsAt = max(endsAt, startsAt)
    }

    public var durationSeconds: TimeInterval {
        endsAt.timeIntervalSince(startsAt)
    }
}

@MainActor
public protocol CalendarEventProviding: AnyObject {
    func currentPermissionState() async -> PermissionState
    func requestPermission() async -> PermissionState
    func availableSources() async throws -> [CalendarSource]
    func events(startingAt startDate: Date, endingAt endDate: Date, sourceIDs: Set<String>) async throws -> [CalendarEvent]
    func openCalendar()
}

public enum CalendarDisplaySupport {
    public static func orderedSources(_ sources: [CalendarSource]) -> [CalendarSource] {
        sources.sorted { first, second in
            first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
        }
    }

    public static func selectedSourceIDs(from selectedSourceIDs: Set<String>?, availableSources: [CalendarSource]) -> Set<String> {
        if let selectedSourceIDs {
            return selectedSourceIDs
        }

        return Set(availableSources.map(\.id))
    }

    public static func upcomingEvents(
        from events: [CalendarEvent],
        selectedSourceIDs: Set<String>,
        now: Date,
        through endDate: Date,
        limit: Int = 4
    ) -> [CalendarEvent] {
        events
            .filter { event in
                selectedSourceIDs.contains(event.sourceID)
                    && event.startsAt >= now
                    && event.startsAt <= endDate
            }
            .sorted { first, second in
                if first.startsAt != second.startsAt {
                    return first.startsAt < second.startsAt
                }

                return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    public static func normalizedSelectedSourceIDs(_ sourceIDs: Set<String>?) -> Set<String>? {
        guard let sourceIDs else {
            return nil
        }

        return Set(
            sourceIDs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}

@MainActor
public final class CalendarEventsStore: ObservableObject {
    @Published public private(set) var permissionState: PermissionState = .notDetermined
    @Published public private(set) var sources: [CalendarSource] = []
    @Published public private(set) var events: [CalendarEvent] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastErrorDescription: String?

    private let provider: any CalendarEventProviding
    private let now: () -> Date
    private let eventHorizon: TimeInterval
    private let eventLimit: Int

    public init(
        provider: any CalendarEventProviding,
        now: @escaping () -> Date = Date.init,
        eventHorizon: TimeInterval = 24 * 60 * 60,
        eventLimit: Int = 4
    ) {
        self.provider = provider
        self.now = now
        self.eventHorizon = eventHorizon
        self.eventLimit = eventLimit
    }

    public func refresh(selectedSourceIDs: Set<String>?, requestPermissionIfNeeded: Bool = false) {
        Task {
            await reload(
                selectedSourceIDs: selectedSourceIDs,
                requestPermissionIfNeeded: requestPermissionIfNeeded
            )
        }
    }

    public func reload(selectedSourceIDs: Set<String>?, requestPermissionIfNeeded: Bool = false) async {
        isLoading = true
        lastErrorDescription = nil
        defer { isLoading = false }

        var state = await provider.currentPermissionState()
        if state == .notDetermined, requestPermissionIfNeeded {
            state = await provider.requestPermission()
        }
        permissionState = state

        guard state == .allowed else {
            sources = []
            events = []
            return
        }

        do {
            let loadedSources = CalendarDisplaySupport.orderedSources(try await provider.availableSources())
            let resolvedSourceIDs = CalendarDisplaySupport.selectedSourceIDs(
                from: selectedSourceIDs,
                availableSources: loadedSources
            )
            let startDate = now()
            let endDate = startDate.addingTimeInterval(eventHorizon)
            let loadedEvents = try await provider.events(
                startingAt: startDate,
                endingAt: endDate,
                sourceIDs: resolvedSourceIDs
            )

            sources = loadedSources
            events = CalendarDisplaySupport.upcomingEvents(
                from: loadedEvents,
                selectedSourceIDs: resolvedSourceIDs,
                now: startDate,
                through: endDate,
                limit: eventLimit
            )
        } catch {
            sources = []
            events = []
            lastErrorDescription = error.localizedDescription
        }
    }

    public func openCalendar() {
        provider.openCalendar()
    }
}
