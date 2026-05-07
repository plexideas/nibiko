import Testing
@testable import MenuBarNotesCore

@Suite("Localization")
struct LocalizationTests {
    @Test("English strings are available for the Phase 1 shell")
    func englishStrings() {
        let localizer = Localizer(preferredLanguageIdentifiers: ["en-US"])

        #expect(localizer.language == .english)
        #expect(localizer.string(.settingsTitle) == "Settings")
        #expect(localizer.string(.notesCardTitle) == "Notes / Todos / Reminders")
    }

    @Test("unsupported languages fall back to English")
    func unsupportedLanguagesFallBackToEnglish() {
        let localizer = Localizer(preferredLanguageIdentifiers: ["fr-FR", "es-ES"])

        #expect(localizer.language == .english)
        #expect(localizer.string(.appearanceSystem) == "System")
    }
}
