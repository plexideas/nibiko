import Foundation

public struct VaultPomodoroSettings: Codable, Equatable, Sendable {
    public var isPomodoroCardVisible: Bool
    public var pomodoroTemplates: [PomodoroTemplate]
    public var selectedPomodoroTemplateID: String
    public var currentPomodoroSession: PomodoroSession?

    public init(
        isPomodoroCardVisible: Bool,
        pomodoroTemplates: [PomodoroTemplate],
        selectedPomodoroTemplateID: String,
        currentPomodoroSession: PomodoroSession?
    ) {
        let normalizedTemplates = PomodoroTemplate.normalizedTemplates(pomodoroTemplates)
        self.isPomodoroCardVisible = isPomodoroCardVisible
        self.pomodoroTemplates = normalizedTemplates
        self.selectedPomodoroTemplateID = normalizedTemplates.contains { $0.id == selectedPomodoroTemplateID }
            ? selectedPomodoroTemplateID
            : normalizedTemplates[0].id
        self.currentPomodoroSession = currentPomodoroSession
    }
}

public struct VaultSettings: Codable, Equatable, Sendable {
    public var pomodoro: VaultPomodoroSettings

    public init(pomodoro: VaultPomodoroSettings) {
        self.pomodoro = pomodoro
    }
}

public struct VaultSettingsStore: Sendable {
    public init() {}

    public func loadSettings(in vaultDirectory: URL) throws -> VaultSettings? {
        let fileURL = settingsURL(in: vaultDirectory)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(VaultSettings.self, from: data)
    }

    public func saveSettings(_ settings: VaultSettings, in vaultDirectory: URL) throws {
        try FileManager.default.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL(in: vaultDirectory), options: .atomic)
    }

    private func settingsURL(in vaultDirectory: URL) -> URL {
        vaultDirectory.appendingPathComponent(AppSettings.vaultSettingsFileName)
    }
}

