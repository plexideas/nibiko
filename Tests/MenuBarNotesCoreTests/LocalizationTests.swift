import Foundation
import Testing
@testable import MenuBarNotesCore

@Suite("Localization")
struct LocalizationTests {
    @Test("English strings are available for the pilot")
    func englishStrings() {
        let localizer = Localizer(preferredLanguageIdentifiers: ["en-US"])

        #expect(localizer.language == .english)
        #expect(localizer.string(.settingsTitle) == "Settings")
        #expect(localizer.string(.notesCardTitle) == "Notes / Todos / Reminders")
    }

    @Test("supported pilot languages resolve from preferred identifiers")
    func supportedPilotLanguagesResolve() {
        #expect(Localizer(preferredLanguageIdentifiers: ["de-DE"]).language == .german)
        #expect(Localizer(preferredLanguageIdentifiers: ["ko-KR"]).language == .korean)
        #expect(Localizer(preferredLanguageIdentifiers: ["zh-Hans-CN"]).language == .chineseSimplified)
        #expect(Localizer(preferredLanguageIdentifiers: ["zh-TW"]).language == .chineseSimplified)
    }

    @Test("preferred identifiers use the first supported language")
    func firstSupportedLanguageWins() {
        let localizer = Localizer(preferredLanguageIdentifiers: ["fr-FR", "ko-KR", "de-DE"])

        #expect(localizer.language == .korean)
        #expect(localizer.string(.settingsTitle) == "설정")
    }

    @Test("unsupported languages fall back to English")
    func unsupportedLanguagesFallBackToEnglish() {
        let localizer = Localizer(preferredLanguageIdentifiers: ["fr-FR", "es-ES"])

        #expect(localizer.language == .english)
        #expect(localizer.string(.appearanceSystem) == "System")
    }

    @Test("all pilot localization keys are present for supported languages")
    func allPilotKeysArePresent() {
        for language in SupportedLanguage.allCases {
            let localizer = Localizer(preferredLanguageIdentifiers: [language.rawValue])

            for key in LocalizationKey.allCases {
                let value = localizer.string(key)
                #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(value != key.rawValue)
            }
        }
    }

    @Test("localized format strings compose safely")
    func localizedFormatStringsCompose() {
        for language in SupportedLanguage.allCases {
            let localizer = Localizer(preferredLanguageIdentifiers: [language.rawValue])

            let progress = String(format: localizer.string(.progressSummaryFormat), 3, 2)
            let hotkey = String(format: localizer.string(.quickAddHotkeyStatusRegistered), "⌘⌥N")
            let templateName = String(format: localizer.string(.pomodoroNewTemplateNameFormat), 4)

            #expect(progress.contains("3"))
            #expect(progress.contains("2"))
            #expect(hotkey.contains("⌘⌥N"))
            #expect(templateName.contains("4"))
        }
    }

    @Test("default Pomodoro template display names localize without changing custom names")
    func pomodoroTemplateDisplayNamesLocalize() {
        let german = Localizer(preferredLanguageIdentifiers: ["de-DE"])
        let custom = PomodoroTemplate(id: "custom", name: "Deep Work", focusDurationSeconds: 1_800)

        #expect(german.pomodoroTemplateName(.defaultFocus) == "Fokus 25")
        #expect(german.pomodoroTemplateName(.defaultShortFocus) == "Kurzer Fokus")
        #expect(german.pomodoroTemplateName(custom) == "Deep Work")
    }

    @Test("localized display helpers cover compact UI fallback text")
    func localizedDisplayHelpers() {
        let chinese = Localizer(preferredLanguageIdentifiers: ["zh-Hans-CN"])
        let source = CalendarSource(id: "empty", title: "")
        let event = CalendarEvent(
            id: "empty",
            sourceID: "empty",
            title: "",
            startsAt: Date(timeIntervalSince1970: 1_800_000_000),
            endsAt: Date(timeIntervalSince1970: 1_800_000_900)
        )

        #expect(chinese.hotkeyDisplayString(.controlOptionSpace) == "⌃⌥空格")
        #expect(chinese.calendarSourceTitle(source) == "日历")
        #expect(chinese.calendarEventTitle(event) == "无标题日程")
        #expect(chinese.acknowledgementsText(AppInfo(name: "App", version: "1", build: "1")) == "没有第三方运行时依赖。")
    }
}
