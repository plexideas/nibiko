import Foundation
import Testing
@testable import MenuBarNotesCore

@MainActor
@Suite("App settings persistence")
struct AppSettingsStoreTests {
    @Test("defaults use system appearance and the Phase 1 card order")
    func defaultSettings() {
        let defaults = isolatedDefaults()
        let store = AppSettingsStore(persistence: UserDefaultsSettingsPersistence(defaults: defaults))

        #expect(store.settings.appearanceMode == .system)
        #expect(store.settings.cardOrder == [.notes, .pomodoro, .calendar])
    }

    @Test("appearance changes persist across store recreation")
    func persistsAppearance() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let store = AppSettingsStore(persistence: persistence)

        store.setAppearanceMode(.dark)

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(reloadedStore.settings.appearanceMode == .dark)
    }

    @Test("card order changes persist across store recreation")
    func persistsCardOrder() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let store = AppSettingsStore(persistence: persistence)

        store.moveCard(.calendar, direction: .up)
        store.moveCard(.calendar, direction: .up)

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(reloadedStore.settings.cardOrder == [.calendar, .notes, .pomodoro])
    }

    @Test("card order normalization preserves every Phase 1 card once")
    func normalizesCardOrder() {
        let settings = AppSettings(cardOrder: [.calendar, .calendar])

        #expect(settings.cardOrder == [.calendar, .notes, .pomodoro])
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "MenuBarNotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
