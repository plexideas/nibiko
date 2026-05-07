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
        #expect(store.settings.markdownStorageDirectory == AppSettings.defaultMarkdownStorageDirectory)
        #expect(store.settings.quickAddHotkey == .default)
        #expect(store.settings.isPomodoroCardVisible)
        #expect(store.settings.pomodoroTemplates == PomodoroTemplate.defaultTemplates)
        #expect(store.settings.selectedPomodoroTemplateID == PomodoroTemplate.defaultFocus.id)
        #expect(store.settings.currentPomodoroSession == nil)
        #expect(store.settings.isCalendarCardVisible)
        #expect(store.settings.selectedCalendarSourceIDs == nil)
        #expect(!store.settings.automaticUpdatesEnabled)
        #expect(!store.settings.launchAtLoginEnabled)
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

    @Test("Markdown storage directory changes persist across store recreation")
    func persistsMarkdownStorageDirectory() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let store = AppSettingsStore(persistence: persistence)

        store.setMarkdownStorageDirectory("/tmp/MenuBarNotesRecords")

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(reloadedStore.settings.markdownStorageDirectory == "/tmp/MenuBarNotesRecords")
    }

    @Test("missing Markdown storage directory uses the default Documents Notes folder")
    func defaultsMissingMarkdownStorageDirectory() throws {
        let data = """
        {
          "appearanceMode": "dark",
          "cardOrder": ["notes", "pomodoro", "calendar"]
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.markdownStorageDirectory == AppSettings.defaultMarkdownStorageDirectory)
    }

    @Test("quick-add hotkey changes persist across store recreation")
    func persistsQuickAddHotkey() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let store = AppSettingsStore(persistence: persistence)

        store.setQuickAddHotkey(.controlOptionSpace)

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(reloadedStore.settings.quickAddHotkey == .controlOptionSpace)
    }

    @Test("Pomodoro visibility changes persist without deleting templates")
    func persistsPomodoroVisibilityWithoutDeletingTemplates() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let store = AppSettingsStore(persistence: persistence)
        let template = PomodoroTemplate(id: "deep", name: "Deep Work", focusDurationSeconds: 2_700)

        store.upsertPomodoroTemplate(template)
        store.setPomodoroCardVisible(false)

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(!reloadedStore.settings.isPomodoroCardVisible)
        #expect(reloadedStore.settings.pomodoroTemplates.contains(template))
    }

    @Test("Pomodoro templates and selection persist across store recreation")
    func persistsPomodoroTemplatesAndSelection() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let store = AppSettingsStore(persistence: persistence)
        let template = PomodoroTemplate(id: "deep", name: "Deep Work", focusDurationSeconds: 2_700)

        store.upsertPomodoroTemplate(template)
        store.setSelectedPomodoroTemplateID(template.id)

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(reloadedStore.settings.pomodoroTemplates.contains(template))
        #expect(reloadedStore.settings.selectedPomodoroTemplateID == template.id)
    }

    @Test("current Pomodoro session persists across store recreation")
    func persistsCurrentPomodoroSession() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let store = AppSettingsStore(persistence: persistence)
        let session = PomodoroSession(
            state: .paused,
            templateID: PomodoroTemplate.defaultFocus.id,
            startedAt: Date(timeIntervalSince1970: 10_000),
            pausedRemainingSeconds: 900
        )

        store.setCurrentPomodoroSession(session)

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(reloadedStore.settings.currentPomodoroSession == session)
    }

    @Test("Calendar visibility changes persist without deleting selected sources")
    func persistsCalendarVisibilityWithoutDeletingSources() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let store = AppSettingsStore(persistence: persistence)

        store.setSelectedCalendarSourceIDs(["work", "home"])
        store.setCalendarCardVisible(false)

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(!reloadedStore.settings.isCalendarCardVisible)
        #expect(reloadedStore.settings.selectedCalendarSourceIDs == Set(["work", "home"]))
    }

    @Test("Calendar source selection changes persist across store recreation")
    func persistsCalendarSourceSelection() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let store = AppSettingsStore(persistence: persistence)

        store.setSelectedCalendarSourceIDs(["work"])

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(reloadedStore.settings.selectedCalendarSourceIDs == Set(["work"]))
    }

    @Test("automatic-update preference changes persist across store recreation")
    func persistsAutomaticUpdatesPreference() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let store = AppSettingsStore(persistence: persistence)

        store.setAutomaticUpdatesEnabled(true)

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(reloadedStore.settings.automaticUpdatesEnabled)
    }

    @Test("launch-at-login preference persists and applies through lifecycle service")
    func persistsAndAppliesLaunchAtLoginPreference() {
        let defaults = isolatedDefaults()
        let persistence = UserDefaultsSettingsPersistence(defaults: defaults)
        let launchAtLoginService = FakeLaunchAtLoginService()
        let store = AppSettingsStore(
            persistence: persistence,
            launchAtLoginService: launchAtLoginService
        )

        store.setLaunchAtLoginEnabled(true)
        store.setLaunchAtLoginEnabled(false)

        let reloadedStore = AppSettingsStore(persistence: persistence)
        #expect(!reloadedStore.settings.launchAtLoginEnabled)
        #expect(launchAtLoginService.appliedValues == [true, false])
    }

    @Test("launch-at-login service errors are reported without dropping the persisted preference")
    func reportsLaunchAtLoginServiceErrors() {
        let defaults = isolatedDefaults()
        let launchAtLoginService = FakeLaunchAtLoginService(error: TestLaunchAtLoginError.failed)
        var receivedError: Error?
        let store = AppSettingsStore(
            persistence: UserDefaultsSettingsPersistence(defaults: defaults),
            launchAtLoginService: launchAtLoginService,
            errorHandler: { receivedError = $0 }
        )

        store.setLaunchAtLoginEnabled(true)

        #expect(store.settings.launchAtLoginEnabled)
        #expect(receivedError is TestLaunchAtLoginError)
    }

    @Test("removing the selected Pomodoro template selects a remaining template")
    func removingSelectedPomodoroTemplateSelectsRemainingTemplate() {
        let defaults = isolatedDefaults()
        let store = AppSettingsStore(persistence: UserDefaultsSettingsPersistence(defaults: defaults))
        let template = PomodoroTemplate(id: "deep", name: "Deep Work", focusDurationSeconds: 2_700)

        store.upsertPomodoroTemplate(template)
        store.setSelectedPomodoroTemplateID(template.id)
        store.removePomodoroTemplate(id: template.id)

        #expect(store.settings.selectedPomodoroTemplateID == PomodoroTemplate.defaultFocus.id)
        #expect(!store.settings.pomodoroTemplates.contains { $0.id == template.id })
    }

    @Test("settings without a stored quick-add hotkey migrate to the default binding")
    func migratesMissingQuickAddHotkey() throws {
        let data = """
        {
          "appearanceMode": "dark",
          "cardOrder": ["notes", "pomodoro", "calendar"],
          "markdownStorageDirectory": "/tmp/MenuBarNotesRecords"
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.appearanceMode == .dark)
        #expect(settings.quickAddHotkey == .default)
    }

    @Test("settings without stored Pomodoro values migrate to visible defaults")
    func migratesMissingPomodoroValues() throws {
        let data = """
        {
          "appearanceMode": "dark",
          "cardOrder": ["notes", "pomodoro", "calendar"],
          "markdownStorageDirectory": "/tmp/MenuBarNotesRecords",
          "quickAddHotkey": {
            "keyCode": 45,
            "modifiers": 3,
            "isEnabled": true
          }
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.isPomodoroCardVisible)
        #expect(settings.pomodoroTemplates == PomodoroTemplate.defaultTemplates)
        #expect(settings.selectedPomodoroTemplateID == PomodoroTemplate.defaultFocus.id)
        #expect(settings.currentPomodoroSession == nil)
        #expect(settings.isCalendarCardVisible)
        #expect(settings.selectedCalendarSourceIDs == nil)
        #expect(!settings.automaticUpdatesEnabled)
        #expect(!settings.launchAtLoginEnabled)
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

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    private let error: Error?
    private(set) var appliedValues: [Bool] = []

    init(error: Error? = nil) {
        self.error = error
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) throws {
        appliedValues.append(isEnabled)
        if let error {
            throw error
        }
    }
}

private enum TestLaunchAtLoginError: Error {
    case failed
}
