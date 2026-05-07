import Combine
import Foundation

public struct PomodoroTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var focusDurationSeconds: Int
    public var shortBreakDurationSeconds: Int?
    public var longBreakDurationSeconds: Int?
    public var cycleCount: Int?

    public init(
        id: String = UUID().uuidString,
        name: String,
        focusDurationSeconds: Int,
        shortBreakDurationSeconds: Int? = nil,
        longBreakDurationSeconds: Int? = nil,
        cycleCount: Int? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.focusDurationSeconds = max(1, focusDurationSeconds)
        self.shortBreakDurationSeconds = Self.normalizedOptionalSeconds(shortBreakDurationSeconds)
        self.longBreakDurationSeconds = Self.normalizedOptionalSeconds(longBreakDurationSeconds)
        self.cycleCount = cycleCount.map { max(1, $0) }
    }

    public static let defaultFocus = PomodoroTemplate(
        id: "default-focus",
        name: "Focus 25",
        focusDurationSeconds: 1_500,
        shortBreakDurationSeconds: 300,
        longBreakDurationSeconds: 900,
        cycleCount: 4
    )

    public static let defaultShortFocus = PomodoroTemplate(
        id: "short-focus",
        name: "Quick Focus",
        focusDurationSeconds: 900,
        shortBreakDurationSeconds: 300
    )

    public static let defaultTemplates: [PomodoroTemplate] = [
        .defaultFocus,
        .defaultShortFocus
    ]

    private static func normalizedOptionalSeconds(_ seconds: Int?) -> Int? {
        seconds.map { max(1, $0) }
    }
}

public enum PomodoroSessionState: String, Codable, Equatable, Sendable {
    case idle
    case running
    case paused
    case completed
}

public struct PomodoroSession: Codable, Equatable, Sendable {
    public var state: PomodoroSessionState
    public var templateID: String?
    public var startedAt: Date?
    public var endsAt: Date?
    public var pausedRemainingSeconds: Int?
    public var completedAt: Date?

    public init(
        state: PomodoroSessionState = .idle,
        templateID: String? = nil,
        startedAt: Date? = nil,
        endsAt: Date? = nil,
        pausedRemainingSeconds: Int? = nil,
        completedAt: Date? = nil
    ) {
        self.state = state
        self.templateID = templateID
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.pausedRemainingSeconds = pausedRemainingSeconds
        self.completedAt = completedAt
    }
}

@MainActor
public final class PomodoroTimer: ObservableObject {
    @Published public private(set) var session: PomodoroSession
    @Published public private(set) var selectedTemplate: PomodoroTemplate

    private let clock: () -> Date

    public init(
        selectedTemplate: PomodoroTemplate = .defaultFocus,
        currentSession: PomodoroSession? = nil,
        clock: @escaping () -> Date = Date.init
    ) {
        self.selectedTemplate = selectedTemplate
        self.clock = clock
        self.session = currentSession ?? PomodoroSession(templateID: selectedTemplate.id)
        refresh()
    }

    public var remainingSeconds: Int {
        remainingSeconds(at: clock())
    }

    public var canStart: Bool {
        session.state == .idle || session.state == .completed
    }

    public var canPause: Bool {
        session.state == .running
    }

    public var canResume: Bool {
        session.state == .paused
    }

    public func selectTemplate(_ template: PomodoroTemplate) {
        guard session.state == .idle || session.state == .completed else {
            return
        }

        selectedTemplate = template
        session = PomodoroSession(templateID: template.id)
    }

    public func start(template: PomodoroTemplate? = nil) {
        let nextTemplate = template ?? selectedTemplate
        selectedTemplate = nextTemplate
        let now = clock()
        session = PomodoroSession(
            state: .running,
            templateID: nextTemplate.id,
            startedAt: now,
            endsAt: now.addingTimeInterval(TimeInterval(nextTemplate.focusDurationSeconds))
        )
    }

    public func pause() {
        refresh()
        guard session.state == .running else {
            return
        }

        let remaining = remainingSeconds(at: clock())
        session.state = .paused
        session.pausedRemainingSeconds = remaining
        session.endsAt = nil
    }

    public func resume() {
        guard session.state == .paused else {
            return
        }

        let remaining = max(0, session.pausedRemainingSeconds ?? selectedTemplate.focusDurationSeconds)
        if remaining == 0 {
            complete(at: clock())
            return
        }

        session.state = .running
        session.endsAt = clock().addingTimeInterval(TimeInterval(remaining))
        session.pausedRemainingSeconds = nil
    }

    public func stop() {
        session = PomodoroSession(templateID: selectedTemplate.id)
    }

    public func refresh() {
        guard session.state == .running, remainingSeconds(at: clock()) == 0 else {
            return
        }

        complete(at: clock())
    }

    public func tick() {
        let wasRunning = session.state == .running
        refresh()
        if wasRunning && session.state == .running {
            objectWillChange.send()
        }
    }

    public func resetTemplates(_ templates: [PomodoroTemplate], selectedTemplateID: String?) {
        let normalizedTemplates = PomodoroTemplate.normalizedTemplates(templates)
        let nextTemplate = normalizedTemplates.first { $0.id == selectedTemplateID }
            ?? normalizedTemplates.first { $0.id == selectedTemplate.id }
            ?? normalizedTemplates[0]

        if session.state == .idle || session.state == .completed {
            selectTemplate(nextTemplate)
        } else if selectedTemplate.id == nextTemplate.id {
            selectedTemplate = nextTemplate
        }
    }

    private func remainingSeconds(at now: Date) -> Int {
        switch session.state {
        case .idle:
            return selectedTemplate.focusDurationSeconds
        case .running:
            guard let endsAt = session.endsAt else {
                return selectedTemplate.focusDurationSeconds
            }
            return max(0, Int(ceil(endsAt.timeIntervalSince(now))))
        case .paused:
            return max(0, session.pausedRemainingSeconds ?? selectedTemplate.focusDurationSeconds)
        case .completed:
            return 0
        }
    }

    private func complete(at date: Date) {
        session.state = .completed
        session.endsAt = nil
        session.pausedRemainingSeconds = 0
        session.completedAt = date
    }
}

public extension PomodoroTemplate {
    static func normalizedTemplates(_ templates: [PomodoroTemplate]) -> [PomodoroTemplate] {
        var result: [PomodoroTemplate] = []
        for template in templates where !result.contains(where: { $0.id == template.id }) {
            let name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                continue
            }
            result.append(
                PomodoroTemplate(
                    id: template.id,
                    name: name,
                    focusDurationSeconds: template.focusDurationSeconds,
                    shortBreakDurationSeconds: template.shortBreakDurationSeconds,
                    longBreakDurationSeconds: template.longBreakDurationSeconds,
                    cycleCount: template.cycleCount
                )
            )
        }

        return result.isEmpty ? defaultTemplates : result
    }
}
