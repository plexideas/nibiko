import Combine
import Foundation

public enum ReminderNotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

public struct ReminderNotificationRequest: Equatable, Sendable {
    public var identifier: String
    public var title: String
    public var body: String
    public var scheduledAt: Date

    public init(identifier: String, title: String, body: String = "", scheduledAt: Date) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.scheduledAt = scheduledAt
    }
}

public enum ReminderNotificationDecision: Equatable, Sendable {
    case noNotificationNeeded
    case requestPermission(ReminderNotificationRequest)
    case schedule(ReminderNotificationRequest)
    case denied
    case unavailable
}

public enum ReminderNotificationStatus: Equatable, Sendable {
    case idle
    case scheduled(Date)
    case denied
    case unavailable
    case failed
}

public protocol ReminderNotificationScheduling: Sendable {
    func currentAuthorization() async -> ReminderNotificationAuthorization
    func requestAuthorization() async -> ReminderNotificationAuthorization
    func scheduleReminderNotification(_ request: ReminderNotificationRequest) async throws
}

public enum ReminderNotificationPlanner {
    public static func decision(
        for record: Record,
        authorization: ReminderNotificationAuthorization,
        now: Date = Date()
    ) -> ReminderNotificationDecision {
        guard
            record.kind == .reminder,
            record.status == .active,
            let scheduledAt = RecordDisplaySupport.displayTime(for: record),
            scheduledAt > now
        else {
            return .noNotificationNeeded
        }

        let request = ReminderNotificationRequest(
            identifier: "record-\(record.id)",
            title: record.title,
            body: record.body,
            scheduledAt: scheduledAt
        )

        switch authorization {
        case .notDetermined:
            return .requestPermission(request)
        case .authorized:
            return .schedule(request)
        case .denied:
            return .denied
        case .unavailable:
            return .unavailable
        }
    }
}

@MainActor
public final class ReminderNotificationStore: ObservableObject {
    @Published public private(set) var status: ReminderNotificationStatus = .idle

    private let scheduler: any ReminderNotificationScheduling

    public init(scheduler: any ReminderNotificationScheduling) {
        self.scheduler = scheduler
    }

    public func scheduleIfNeeded(for record: Record, now: Date = Date()) {
        Task {
            let authorization = await scheduler.currentAuthorization()
            var decision = ReminderNotificationPlanner.decision(
                for: record,
                authorization: authorization,
                now: now
            )

            if case let .requestPermission(request) = decision {
                let requestedAuthorization = await scheduler.requestAuthorization()
                decision = ReminderNotificationPlanner.decision(
                    for: record,
                    authorization: requestedAuthorization,
                    now: now
                )

                if case .schedule = decision {
                    decision = .schedule(request)
                }
            }

            let newStatus = await resolve(decision)
            status = newStatus
        }
    }

    private func resolve(_ decision: ReminderNotificationDecision) async -> ReminderNotificationStatus {
        switch decision {
        case .noNotificationNeeded:
            return .idle
        case .requestPermission:
            return .failed
        case let .schedule(request):
            do {
                try await scheduler.scheduleReminderNotification(request)
                return .scheduled(request.scheduledAt)
            } catch {
                return .failed
            }
        case .denied:
            return .denied
        case .unavailable:
            return .unavailable
        }
    }
}
