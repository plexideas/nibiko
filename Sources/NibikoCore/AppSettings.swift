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

public enum MenuCardVisibility {
    public static func visibleCards(from settings: AppSettings) -> [MenuCard] {
        settings.cardOrder.filter { card in
            switch card {
            case .notes:
                return true
            case .pomodoro:
                return settings.isPomodoroCardVisible
            case .calendar:
                return settings.isCalendarCardVisible
            }
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public static var defaultVaultStorageDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .path
    }

    public static let defaultVaultName = "notes"
    public static let recordsFileName = "storage.md"
    public static let vaultSettingsFileName = "settings.json"

    public static var defaultVaultDirectory: String {
        URL(fileURLWithPath: defaultVaultStorageDirectory, isDirectory: true)
            .appendingPathComponent(defaultVaultName, isDirectory: true)
            .path
    }

    public static var defaultMarkdownStorageDirectory: String {
        defaultVaultDirectory
    }

    public static let defaultMarkdownStorageFileName = recordsFileName

    public var appearanceMode: AppearanceMode
    public var cardOrder: [MenuCard]
    public var vaultName: String
    public var vaultStorageDirectory: String
    public var vaultStorageBookmarkData: Data?
    public var quickAddHotkey: HotkeyBinding
    public var isPomodoroCardVisible: Bool
    public var pomodoroTemplates: [PomodoroTemplate]
    public var selectedPomodoroTemplateID: String
    public var currentPomodoroSession: PomodoroSession?
    public var isCalendarCardVisible: Bool
    public var selectedCalendarSourceIDs: Set<String>?
    public var automaticUpdatesEnabled: Bool
    public var launchAtLoginEnabled: Bool

    public var markdownStorageDirectory: String? {
        vaultDirectory
    }

    public var markdownStorageFileName: String {
        Self.recordsFileName
    }

    private enum CodingKeys: String, CodingKey {
        case appearanceMode
        case cardOrder
        case vaultName
        case vaultStorageDirectory
        case vaultStorageBookmarkData
        case markdownStorageDirectory
        case markdownStorageFileName
        case quickAddHotkey
        case isPomodoroCardVisible
        case pomodoroTemplates
        case selectedPomodoroTemplateID
        case currentPomodoroSession
        case isCalendarCardVisible
        case selectedCalendarSourceIDs
        case automaticUpdatesEnabled
        case launchAtLoginEnabled
    }

    public init(
        appearanceMode: AppearanceMode = .system,
        cardOrder: [MenuCard] = MenuCard.defaultOrder,
        vaultName: String = Self.defaultVaultName,
        vaultStorageDirectory: String? = nil,
        quickAddHotkey: HotkeyBinding = .default,
        isPomodoroCardVisible: Bool = true,
        pomodoroTemplates: [PomodoroTemplate] = PomodoroTemplate.defaultTemplates,
        selectedPomodoroTemplateID: String = PomodoroTemplate.defaultFocus.id,
        currentPomodoroSession: PomodoroSession? = nil,
        isCalendarCardVisible: Bool = true,
        selectedCalendarSourceIDs: Set<String>? = nil,
        automaticUpdatesEnabled: Bool = false,
        launchAtLoginEnabled: Bool = false
    ) {
        self.appearanceMode = appearanceMode
        self.cardOrder = MenuCard.normalizedOrder(from: cardOrder)
        self.vaultName = Self.normalizedVaultName(vaultName)
        self.vaultStorageDirectory = Self.normalizedVaultStorageDirectory(vaultStorageDirectory)
        self.vaultStorageBookmarkData = nil
        self.quickAddHotkey = quickAddHotkey
        self.isPomodoroCardVisible = isPomodoroCardVisible
        self.pomodoroTemplates = PomodoroTemplate.normalizedTemplates(pomodoroTemplates)
        self.selectedPomodoroTemplateID = Self.normalizedSelectedPomodoroTemplateID(
            selectedPomodoroTemplateID,
            templates: self.pomodoroTemplates
        )
        self.currentPomodoroSession = currentPomodoroSession
        self.isCalendarCardVisible = isCalendarCardVisible
        self.selectedCalendarSourceIDs = CalendarDisplaySupport.normalizedSelectedSourceIDs(selectedCalendarSourceIDs)
        self.automaticUpdatesEnabled = automaticUpdatesEnabled
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }

    public static let `default` = AppSettings()

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        cardOrder = MenuCard.normalizedOrder(
            from: try container.decodeIfPresent([MenuCard].self, forKey: .cardOrder) ?? MenuCard.defaultOrder
        )
        if let decodedVaultName = try container.decodeIfPresent(String.self, forKey: .vaultName) {
            vaultName = Self.normalizedVaultName(decodedVaultName)
            vaultStorageDirectory = Self.normalizedVaultStorageDirectory(
                try container.decodeIfPresent(String.self, forKey: .vaultStorageDirectory)
            )
            vaultStorageBookmarkData = try container.decodeIfPresent(Data.self, forKey: .vaultStorageBookmarkData)
        } else if let legacyDirectory = try container.decodeIfPresent(String.self, forKey: .markdownStorageDirectory) {
            let legacyURL = URL(fileURLWithPath: legacyDirectory, isDirectory: true)
            vaultName = Self.normalizedVaultName(legacyURL.lastPathComponent)
            vaultStorageDirectory = Self.normalizedVaultStorageDirectory(legacyURL.deletingLastPathComponent().path)
            vaultStorageBookmarkData = nil
        } else {
            vaultName = Self.defaultVaultName
            vaultStorageDirectory = Self.defaultVaultStorageDirectory
            vaultStorageBookmarkData = nil
        }
        quickAddHotkey = try container.decodeIfPresent(HotkeyBinding.self, forKey: .quickAddHotkey) ?? .default
        isPomodoroCardVisible = try container.decodeIfPresent(Bool.self, forKey: .isPomodoroCardVisible) ?? true
        pomodoroTemplates = PomodoroTemplate.normalizedTemplates(
            try container.decodeIfPresent([PomodoroTemplate].self, forKey: .pomodoroTemplates)
                ?? PomodoroTemplate.defaultTemplates
        )
        selectedPomodoroTemplateID = Self.normalizedSelectedPomodoroTemplateID(
            try container.decodeIfPresent(String.self, forKey: .selectedPomodoroTemplateID),
            templates: pomodoroTemplates
        )
        currentPomodoroSession = try container.decodeIfPresent(
            PomodoroSession.self,
            forKey: .currentPomodoroSession
        )
        isCalendarCardVisible = try container.decodeIfPresent(Bool.self, forKey: .isCalendarCardVisible) ?? true
        selectedCalendarSourceIDs = CalendarDisplaySupport.normalizedSelectedSourceIDs(
            try container.decodeIfPresent(Set<String>.self, forKey: .selectedCalendarSourceIDs)
        )
        automaticUpdatesEnabled = try container.decodeIfPresent(Bool.self, forKey: .automaticUpdatesEnabled) ?? false
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appearanceMode, forKey: .appearanceMode)
        try container.encode(cardOrder, forKey: .cardOrder)
        try container.encode(vaultName, forKey: .vaultName)
        try container.encode(vaultStorageDirectory, forKey: .vaultStorageDirectory)
        try container.encodeIfPresent(vaultStorageBookmarkData, forKey: .vaultStorageBookmarkData)
        try container.encode(quickAddHotkey, forKey: .quickAddHotkey)
        try container.encode(isPomodoroCardVisible, forKey: .isPomodoroCardVisible)
        try container.encode(pomodoroTemplates, forKey: .pomodoroTemplates)
        try container.encode(selectedPomodoroTemplateID, forKey: .selectedPomodoroTemplateID)
        try container.encodeIfPresent(currentPomodoroSession, forKey: .currentPomodoroSession)
        try container.encode(isCalendarCardVisible, forKey: .isCalendarCardVisible)
        try container.encodeIfPresent(selectedCalendarSourceIDs, forKey: .selectedCalendarSourceIDs)
        try container.encode(automaticUpdatesEnabled, forKey: .automaticUpdatesEnabled)
        try container.encode(launchAtLoginEnabled, forKey: .launchAtLoginEnabled)
    }

    private static func normalizedSelectedPomodoroTemplateID(
        _ selectedTemplateID: String?,
        templates: [PomodoroTemplate]
    ) -> String {
        if let selectedTemplateID, templates.contains(where: { $0.id == selectedTemplateID }) {
            return selectedTemplateID
        }

        return templates[0].id
    }

    public var vaultDirectory: String {
        URL(fileURLWithPath: vaultStorageDirectory, isDirectory: true)
            .appendingPathComponent(vaultName, isDirectory: true)
            .path
    }

    public static func normalizedVaultStorageDirectory(_ directory: String?) -> String {
        let trimmedDirectory = directory?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedDirectory, !trimmedDirectory.isEmpty {
            return trimmedDirectory
        }

        return defaultVaultStorageDirectory
    }

    public static func normalizedMarkdownStorageDirectory(_ directory: String?) -> String {
        let trimmedDirectory = directory?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedDirectory, !trimmedDirectory.isEmpty {
            return trimmedDirectory
        }

        return defaultMarkdownStorageDirectory
    }

    public static func normalizedVaultName(_ name: String?) -> String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedName, !trimmedName.isEmpty else {
            return defaultVaultName
        }

        let baseName = URL(fileURLWithPath: trimmedName, isDirectory: true).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return baseName.isEmpty ? defaultVaultName : baseName
    }

    public static func normalizedMarkdownStorageFileName(_ fileName: String?) -> String {
        recordsFileName
    }
}

public struct HotkeyBinding: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var keyCode: UInt32
    public var modifiers: HotkeyModifiers
    public var isEnabled: Bool

    public var id: String {
        "\(keyCode)-\(modifiers.rawValue)-\(isEnabled)"
    }

    public init(keyCode: UInt32, modifiers: HotkeyModifiers, isEnabled: Bool = true) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }

    public static let disabled = HotkeyBinding(keyCode: 45, modifiers: [.command, .option], isEnabled: false)
    public static let `default` = HotkeyBinding(keyCode: 45, modifiers: [.command, .option])
    public static let commandShiftN = HotkeyBinding(keyCode: 45, modifiers: [.command, .shift])
    public static let controlOptionSpace = HotkeyBinding(keyCode: 49, modifiers: [.control, .option])

    public static let configurableBindings: [HotkeyBinding] = [
        .default,
        .commandShiftN,
        .controlOptionSpace
    ]

    public var displayString: String {
        let keyName: String
        switch keyCode {
        case 45:
            keyName = "N"
        case 49:
            keyName = "Space"
        default:
            keyName = "Key \(keyCode)"
        }

        return "\(modifiers.displayString)\(keyName)"
    }
}

public struct HotkeyModifiers: OptionSet, Codable, Equatable, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let command = HotkeyModifiers(rawValue: 1 << 0)
    public static let option = HotkeyModifiers(rawValue: 1 << 1)
    public static let control = HotkeyModifiers(rawValue: 1 << 2)
    public static let shift = HotkeyModifiers(rawValue: 1 << 3)

    public var displayString: String {
        var parts: [String] = []
        if contains(.control) {
            parts.append("Control")
        }
        if contains(.option) {
            parts.append("Option")
        }
        if contains(.shift) {
            parts.append("Shift")
        }
        if contains(.command) {
            parts.append("Command")
        }

        return parts.map { "\($0)-" }.joined()
    }

    public var symbolDisplayString: String {
        var parts: [String] = []
        if contains(.control) {
            parts.append("⌃")
        }
        if contains(.option) {
            parts.append("⌥")
        }
        if contains(.shift) {
            parts.append("⇧")
        }
        if contains(.command) {
            parts.append("⌘")
        }

        return parts.joined()
    }
}

public enum HotkeyRegistrationStatus: Equatable, Sendable {
    case disabled
    case registered(HotkeyBinding)
    case conflict(HotkeyBinding)
    case failed(HotkeyBinding)

    public var localizationKey: LocalizationKey {
        switch self {
        case .disabled:
            return .quickAddHotkeyStatusDisabled
        case .registered:
            return .quickAddHotkeyStatusRegistered
        case .conflict:
            return .quickAddHotkeyStatusConflict
        case .failed:
            return .quickAddHotkeyStatusFailed
        }
    }
}

public enum HotkeyRegistrationStatusMapper {
    public static func status(
        for binding: HotkeyBinding,
        registrationResult: Int32,
        successCode: Int32 = 0,
        conflictCodes: Set<Int32>
    ) -> HotkeyRegistrationStatus {
        guard binding.isEnabled else {
            return .disabled
        }

        if registrationResult == successCode {
            return .registered(binding)
        }

        if conflictCodes.contains(registrationResult) {
            return .conflict(binding)
        }

        return .failed(binding)
    }
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
