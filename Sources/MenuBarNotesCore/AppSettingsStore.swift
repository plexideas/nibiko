import Combine
import Foundation

public protocol SettingsPersistence {
    func loadSettings() throws -> AppSettings?
    func saveSettings(_ settings: AppSettings) throws
}

public struct UserDefaultsSettingsPersistence: SettingsPersistence {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "menuBarNotes.settings.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func loadSettings() throws -> AppSettings? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try JSONDecoder().decode(AppSettings.self, from: data)
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
    private let errorHandler: @MainActor (Error) -> Void

    public init(
        persistence: SettingsPersistence = UserDefaultsSettingsPersistence(),
        errorHandler: @escaping @MainActor (Error) -> Void = { _ in }
    ) {
        self.persistence = persistence
        self.errorHandler = errorHandler

        do {
            self.settings = try persistence.loadSettings() ?? .default
        } catch {
            self.settings = .default
            errorHandler(error)
        }
    }

    public func setAppearanceMode(_ appearanceMode: AppearanceMode) {
        update { settings in
            settings.appearanceMode = appearanceMode
        }
    }

    public func setMarkdownStorageDirectory(_ directory: String?) {
        update { settings in
            settings.markdownStorageDirectory = directory
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

    public func setSelectedPomodoroTemplateID(_ templateID: String) {
        update { settings in
            guard settings.pomodoroTemplates.contains(where: { $0.id == templateID }) else {
                return
            }
            settings.selectedPomodoroTemplateID = templateID
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
        nextSettings.markdownStorageDirectory = nextSettings.markdownStorageDirectory?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if nextSettings.markdownStorageDirectory?.isEmpty == true {
            nextSettings.markdownStorageDirectory = nil
        }
        nextSettings.pomodoroTemplates = PomodoroTemplate.normalizedTemplates(nextSettings.pomodoroTemplates)
        if !nextSettings.pomodoroTemplates.contains(where: { $0.id == nextSettings.selectedPomodoroTemplateID }) {
            nextSettings.selectedPomodoroTemplateID = nextSettings.pomodoroTemplates[0].id
        }
        settings = nextSettings

        do {
            try persistence.saveSettings(nextSettings)
        } catch {
            errorHandler(error)
        }
    }
}

public enum CardMoveDirection: Sendable {
    case up
    case down
}
