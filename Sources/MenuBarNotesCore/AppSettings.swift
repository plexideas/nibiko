import Foundation

public enum AppearanceMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var localizationKey: LocalizationKey {
        switch self {
        case .system:
            return .appearanceSystem
        case .light:
            return .appearanceLight
        case .dark:
            return .appearanceDark
        }
    }
}

public enum MenuCard: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case notes
    case pomodoro
    case calendar

    public var id: String { rawValue }

    public var titleKey: LocalizationKey {
        switch self {
        case .notes:
            return .notesCardTitle
        case .pomodoro:
            return .pomodoroCardTitle
        case .calendar:
            return .calendarCardTitle
        }
    }

    public var placeholderKey: LocalizationKey {
        switch self {
        case .notes:
            return .notesPlaceholder
        case .pomodoro:
            return .pomodoroPlaceholder
        case .calendar:
            return .calendarPlaceholder
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var appearanceMode: AppearanceMode
    public var cardOrder: [MenuCard]

    public init(
        appearanceMode: AppearanceMode = .system,
        cardOrder: [MenuCard] = MenuCard.defaultOrder
    ) {
        self.appearanceMode = appearanceMode
        self.cardOrder = MenuCard.normalizedOrder(from: cardOrder)
    }

    public static let `default` = AppSettings()
}

public extension MenuCard {
    static let defaultOrder: [MenuCard] = [.notes, .pomodoro, .calendar]

    static func normalizedOrder(from cards: [MenuCard]) -> [MenuCard] {
        var result: [MenuCard] = []
        for card in cards where !result.contains(card) {
            result.append(card)
        }

        for card in defaultOrder where !result.contains(card) {
            result.append(card)
        }

        return result
    }
}
