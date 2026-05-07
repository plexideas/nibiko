import Foundation

public enum LocalizationKey: String, CaseIterable, Sendable {
    case appName
    case statusItemDescription
    case popoverTitle
    case popoverSubtitle
    case progressSummary
    case notesCardTitle
    case notesPlaceholder
    case pomodoroCardTitle
    case pomodoroPlaceholder
    case calendarCardTitle
    case calendarPlaceholder
    case settingsButton
    case appInfoButton
    case settingsTitle
    case generalTab
    case notesTodosTab
    case pomodoroTab
    case calendarTab
    case appearanceLabel
    case appearanceSystem
    case appearanceLight
    case appearanceDark
    case cardOrderLabel
    case moveUp
    case moveDown
    case featureComingSoon
    case appInfoTitle
    case versionLabel
    case buildLabel
    case close
}

public enum SupportedLanguage: String, CaseIterable, Sendable {
    case english = "en"

    public static func resolve(from preferredLanguageIdentifiers: [String]) -> SupportedLanguage {
        for identifier in preferredLanguageIdentifiers {
            let languageCode = Locale(identifier: identifier).language.languageCode?.identifier
            if languageCode == english.rawValue {
                return .english
            }
        }

        return .english
    }
}

public struct Localizer: Sendable {
    public let language: SupportedLanguage

    public init(preferredLanguageIdentifiers: [String] = Locale.preferredLanguages) {
        self.language = SupportedLanguage.resolve(from: preferredLanguageIdentifiers)
    }

    public func string(_ key: LocalizationKey) -> String {
        Self.englishStrings[key] ?? key.rawValue
    }

    private static let englishStrings: [LocalizationKey: String] = [
        .appName: "Menu Bar Notes",
        .statusItemDescription: "Menu Bar Notes",
        .popoverTitle: "Today",
        .popoverSubtitle: "Quietly ready from the menu bar.",
        .progressSummary: "0 active items - 0 completed today",
        .notesCardTitle: "Notes / Todos / Reminders",
        .notesPlaceholder: "No active records yet.",
        .pomodoroCardTitle: "Pomodoro",
        .pomodoroPlaceholder: "Focus timer is ready for a later phase.",
        .calendarCardTitle: "Calendar",
        .calendarPlaceholder: "Upcoming events will appear here.",
        .settingsButton: "Settings",
        .appInfoButton: "App Info",
        .settingsTitle: "Settings",
        .generalTab: "General",
        .notesTodosTab: "Notes/Todos",
        .pomodoroTab: "Pomodoro",
        .calendarTab: "Calendar",
        .appearanceLabel: "Appearance",
        .appearanceSystem: "System",
        .appearanceLight: "Light",
        .appearanceDark: "Dark",
        .cardOrderLabel: "Card Order",
        .moveUp: "Move Up",
        .moveDown: "Move Down",
        .featureComingSoon: "Configuration for this area arrives in a later phase.",
        .appInfoTitle: "App Information",
        .versionLabel: "Version",
        .buildLabel: "Build",
        .close: "Close"
    ]
}
