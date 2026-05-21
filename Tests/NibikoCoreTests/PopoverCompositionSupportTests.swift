import Testing
@testable import NibikoCore

@Suite("Popover composition support")
struct PopoverCompositionSupportTests {
    @Test("visible cards preserve configured order and hidden feature cards")
    func visibleCardsRespectOrderAndFeatureVisibility() {
        let settings = AppSettings(
            cardOrder: [.calendar, .notes, .pomodoro],
            isPomodoroCardVisible: false,
            isCalendarCardVisible: true
        )

        #expect(MenuCardVisibility.visibleCards(from: settings) == [.calendar, .notes])
    }

    @Test("complete popover card titles localize for supported pilot languages")
    func cardTitlesLocalizeForSupportedPilotLanguages() {
        for language in SupportedLanguage.allCases {
            let localizer = Localizer(preferredLanguageIdentifiers: [language.rawValue])
            let settings = AppSettings(cardOrder: [.notes, .pomodoro, .calendar])

            let titles = MenuCardVisibility.visibleCards(from: settings).map { card in
                localizer.string(card.titleKey)
            }

            #expect(titles.count == 3)
            #expect(titles.allSatisfy { !$0.isEmpty })
            #expect(titles.allSatisfy { !$0.contains("placeholder") })
        }
    }
}
