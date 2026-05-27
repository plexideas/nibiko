import Combine
import Foundation

public protocol SettingsPersistence {
    func loadSettings() throws -> AppSettings?
    func saveSettings(_ settings: AppSettings) throws
}

@MainActor
public protocol LaunchAtLoginServicing: AnyObject {
    func setLaunchAtLoginEnabled(_ isEnabled: Bool) throws
}

public struct UserDefaultsSettingsPersistence: SettingsPersistence {
    private let defaults: UserDefaults
    private let key: String
    private let legacyKeys: [String]

    public init(
        defaults: UserDefaults = .standard,
        key: String = "nibiko.settings.v1",
        legacyKeys: [String] = ["menuBarNotes.settings.v1"]
    ) {
        self.defaults = defaults
        self.key = key
        self.legacyKeys = legacyKeys
    }

    public func loadSettings() throws -> AppSettings? {
        if let data = defaults.data(forKey: key) {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        }

        for legacyKey in legacyKeys {
            if let data = defaults.data(forKey: legacyKey) {
                return try JSONDecoder().decode(AppSettings.self, from: data)
            }
        }

        return nil
    }

    public func saveSettings(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: key)
    }
}

@MainActor
public final class AppSettingsStore: ObservableObject {
    @Published public private(set) var settings: AppSettings

    private let persistence: SettingsPersistence
    private let vaultSettingsStore: VaultSettingsStore
    private let usesVaultSettings: Bool
    private let launchAtLoginService: (any LaunchAtLoginServicing)?
    private let errorHandler: @MainActor (Error) -> Void
    private var vaultStorageAccess: SecurityScopedResourceAccess?

    public init(
        persistence: SettingsPersistence = UserDefaultsSettingsPersistence(),
        vaultSettingsStore: VaultSettingsStore = VaultSettingsStore(),
        usesVaultSettings: Bool = false,
        launchAtLoginService: (any LaunchAtLoginServicing)? = nil,
        errorHandler: @escaping @MainActor (Error) -> Void = { _ in }
    ) {
        self.persistence = persistence
        self.vaultSettingsStore = vaultSettingsStore
        self.usesVaultSettings = usesVaultSettings
        self.launchAtLoginService = launchAtLoginService
        self.errorHandler = errorHandler

        do {
            var loadedSettings = try persistence.loadSettings() ?? .default
            self.vaultStorageAccess = try Self.securityScopedAccess(from: loadedSettings)
            if let resolvedStorageURL = vaultStorageAccess?.url,
               resolvedStorageURL.path != loadedSettings.vaultStorageDirectory {
                loadedSettings.vaultStorageDirectory = AppSettings.normalizedVaultStorageDirectory(
                    resolvedStorageURL.path
                )
            }
            if usesVaultSettings,
               let vaultSettings = try vaultSettingsStore.loadSettings(
                   in: Self.vaultURL(from: loadedSettings, storageURL: vaultStorageAccess?.url)
               ) {
                loadedSettings.apply(vaultSettings.pomodoro)
            }
            self.settings = loadedSettings
        } catch {
            self.settings = .default
            errorHandler(error)
        }
    }

    public var vaultDirectoryURL: URL {
        Self.vaultURL(from: settings, storageURL: vaultStorageAccess?.url)
    }

    public func setAppearanceMode(_ appearanceMode: AppearanceMode) {
        update { settings in
            settings.appearanceMode = appearanceMode
        }
    }

    public func setMarkdownStorageDirectory(_ directory: String?) {
        update { settings in
            let normalizedDirectory = AppSettings.normalizedMarkdownStorageDirectory(directory)
            let directoryURL = URL(fileURLWithPath: normalizedDirectory, isDirectory: true)
            settings.vaultName = AppSettings.normalizedVaultName(directoryURL.lastPathComponent)
            settings.vaultStorageDirectory = AppSettings.normalizedVaultStorageDirectory(
                directoryURL.deletingLastPathComponent().path
            )
            settings.vaultStorageBookmarkData = nil
        }
    }

    public func setVaultStorageDirectory(_ directory: String?) {
        update { settings in
            settings.vaultStorageDirectory = AppSettings.normalizedVaultStorageDirectory(directory)
            settings.vaultStorageBookmarkData = nil
        }
    }

    public func setVaultStorageDirectory(_ directoryURL: URL) {
        let bookmarkData = securityScopedBookmarkData(for: directoryURL)
        update { settings in
            settings.vaultStorageDirectory = AppSettings.normalizedVaultStorageDirectory(directoryURL.path)
            settings.vaultStorageBookmarkData = bookmarkData
        }
    }

    public func setVault(name: String?, storageDirectory directoryURL: URL) {
        let bookmarkData = securityScopedBookmarkData(for: directoryURL)
        update { settings in
            settings.vaultName = AppSettings.normalizedVaultName(name)
            settings.vaultStorageDirectory = AppSettings.normalizedVaultStorageDirectory(directoryURL.path)
            settings.vaultStorageBookmarkData = bookmarkData
        }
    }

    public func setMarkdownStorageFileName(_ fileName: String?) {
        setVaultName(fileName.map { ($0 as NSString).deletingPathExtension })
    }

    public func setVaultName(_ name: String?) {
        update { settings in
            settings.vaultName = AppSettings.normalizedVaultName(name)
        }
    }

    public func setQuickAddHotkey(_ binding: HotkeyBinding) {
        update { settings in
            settings.quickAddHotkey = binding
        }
    }

    public func setPomodoroCardVisible(_ isVisible: Bool) {
        update { settings in
            settings.isPomodoroCardVisible = isVisible
        }
    }

    public func setCalendarCardVisible(_ isVisible: Bool) {
        update { settings in
            settings.isCalendarCardVisible = isVisible
        }
    }

    public func setAutomaticUpdatesEnabled(_ isEnabled: Bool) {
        update { settings in
            settings.automaticUpdatesEnabled = isEnabled
        }
    }

    public func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        update { settings in
            settings.launchAtLoginEnabled = isEnabled
        }
        applyLaunchAtLoginPreference()
    }

    public func applyLaunchAtLoginPreference() {
        do {
            try launchAtLoginService?.setLaunchAtLoginEnabled(settings.launchAtLoginEnabled)
        } catch {
            errorHandler(error)
        }
    }

    public func setSelectedCalendarSourceIDs(_ sourceIDs: Set<String>?) {
        update { settings in
            settings.selectedCalendarSourceIDs = sourceIDs
        }
    }

    public func setSelectedPomodoroTemplateID(_ templateID: String) {
        update { settings in
            guard settings.pomodoroTemplates.contains(where: { $0.id == templateID }) else {
                return
            }
            settings.selectedPomodoroTemplateID = templateID
        }
    }

    public func setCurrentPomodoroSession(_ session: PomodoroSession?) {
        update { settings in
            settings.currentPomodoroSession = session
        }
    }

    public func upsertPomodoroTemplate(_ template: PomodoroTemplate) {
        update { settings in
            let normalizedTemplate = PomodoroTemplate.normalizedTemplates([template])[0]
            if let index = settings.pomodoroTemplates.firstIndex(where: { $0.id == normalizedTemplate.id }) {
                settings.pomodoroTemplates[index] = normalizedTemplate
            } else {
                settings.pomodoroTemplates.append(normalizedTemplate)
                settings.selectedPomodoroTemplateID = normalizedTemplate.id
            }
        }
    }

    public func removePomodoroTemplate(id: String) {
        update { settings in
            settings.pomodoroTemplates.removeAll { $0.id == id }
            if settings.pomodoroTemplates.isEmpty {
                settings.pomodoroTemplates = PomodoroTemplate.defaultTemplates
            }
            if !settings.pomodoroTemplates.contains(where: { $0.id == settings.selectedPomodoroTemplateID }) {
                settings.selectedPomodoroTemplateID = settings.pomodoroTemplates[0].id
            }
        }
    }

    public func moveCard(_ card: MenuCard, direction: CardMoveDirection) {
        update { settings in
            guard let index = settings.cardOrder.firstIndex(of: card) else {
                settings.cardOrder = MenuCard.normalizedOrder(from: settings.cardOrder)
                return
            }

            let destination: Int
            switch direction {
            case .up:
                destination = settings.cardOrder.index(before: index)
            case .down:
                destination = settings.cardOrder.index(after: index)
            }

            guard settings.cardOrder.indices.contains(destination) else {
                return
            }

            settings.cardOrder.swapAt(index, destination)
        }
    }

    private func update(_ mutation: (inout AppSettings) -> Void) {
        var nextSettings = settings
        mutation(&nextSettings)
        nextSettings.cardOrder = MenuCard.normalizedOrder(from: nextSettings.cardOrder)
        nextSettings.vaultName = AppSettings.normalizedVaultName(nextSettings.vaultName)
        nextSettings.vaultStorageDirectory = AppSettings.normalizedVaultStorageDirectory(
            nextSettings.vaultStorageDirectory
        )
        nextSettings.pomodoroTemplates = PomodoroTemplate.normalizedTemplates(nextSettings.pomodoroTemplates)
        if !nextSettings.pomodoroTemplates.contains(where: { $0.id == nextSettings.selectedPomodoroTemplateID }) {
            nextSettings.selectedPomodoroTemplateID = nextSettings.pomodoroTemplates[0].id
        }
        nextSettings.selectedCalendarSourceIDs = CalendarDisplaySupport.normalizedSelectedSourceIDs(
            nextSettings.selectedCalendarSourceIDs
        )
        settings = nextSettings

        do {
            try persistence.saveSettings(nextSettings)
            vaultStorageAccess = try Self.securityScopedAccess(from: nextSettings)
            if usesVaultSettings {
                try vaultSettingsStore.saveSettings(
                    nextSettings.vaultSettings,
                    in: Self.vaultURL(from: nextSettings, storageURL: vaultStorageAccess?.url)
                )
            }
        } catch {
            errorHandler(error)
        }
    }

    private func securityScopedBookmarkData(for directoryURL: URL) -> Data? {
        do {
            return try directoryURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            errorHandler(error)
            return nil
        }
    }

    private static func securityScopedAccess(from settings: AppSettings) throws -> SecurityScopedResourceAccess? {
        guard let bookmarkData = settings.vaultStorageBookmarkData else {
            return nil
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        return SecurityScopedResourceAccess(url: url)
    }

    private static func vaultURL(from settings: AppSettings, storageURL: URL?) -> URL {
        let resolvedStorageURL = storageURL ?? URL(fileURLWithPath: settings.vaultStorageDirectory, isDirectory: true)
        return resolvedStorageURL.appendingPathComponent(settings.vaultName, isDirectory: true)
    }
}

private final class SecurityScopedResourceAccess {
    let url: URL
    private let didStartAccessing: Bool

    init(url: URL) {
        self.url = url
        didStartAccessing = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

public enum CardMoveDirection: Sendable {
    case up
    case down
}

private extension AppSettings {
    var vaultSettings: VaultSettings {
        VaultSettings(
            pomodoro: VaultPomodoroSettings(
                isPomodoroCardVisible: isPomodoroCardVisible,
                pomodoroTemplates: pomodoroTemplates,
                selectedPomodoroTemplateID: selectedPomodoroTemplateID,
                currentPomodoroSession: currentPomodoroSession
            )
        )
    }

    mutating func apply(_ pomodoroSettings: VaultPomodoroSettings) {
        isPomodoroCardVisible = pomodoroSettings.isPomodoroCardVisible
        pomodoroTemplates = PomodoroTemplate.normalizedTemplates(pomodoroSettings.pomodoroTemplates)
        selectedPomodoroTemplateID = pomodoroTemplates.contains { $0.id == pomodoroSettings.selectedPomodoroTemplateID }
            ? pomodoroSettings.selectedPomodoroTemplateID
            : pomodoroTemplates[0].id
        currentPomodoroSession = pomodoroSettings.currentPomodoroSession
    }
}
