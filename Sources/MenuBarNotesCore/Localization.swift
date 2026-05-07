import Foundation

public enum LocalizationKey: String, CaseIterable, Sendable {
    case appName
    case statusItemDescription
    case popoverTitle
    case popoverSubtitle
    case progressSummaryFormat
    case notesCardTitle
    case notesPlaceholder
    case historyPlaceholder
    case activeRecordsMode
    case historyRecordsMode
    case noteKind
    case todoKind
    case reminderKind
    case addRecordPlaceholder
    case addNoteButton
    case addTodoButton
    case addReminderButton
    case deleteRecordButton
    case completeTodo
    case completeReminder
    case completedTodo
    case reminderTimeLabel
    case notificationsDeniedStatus
    case notificationsUnavailableStatus
    case notificationsFailedStatus
    case noStorageLocation
    case recordAddError
    case pomodoroCardTitle
    case pomodoroPlaceholder
    case pomodoroTemplateLabel
    case pomodoroDefaultFocusName
    case pomodoroQuickFocusName
    case pomodoroNewTemplateNameFormat
    case pomodoroRemainingLabel
    case pomodoroIdleStatus
    case pomodoroRunningStatus
    case pomodoroPausedStatus
    case pomodoroCompletedStatus
    case pomodoroStart
    case pomodoroPause
    case pomodoroResume
    case pomodoroStop
    case pomodoroVisibleLabel
    case pomodoroTemplatesLabel
    case pomodoroTemplateNamePlaceholder
    case pomodoroFocusMinutesLabel
    case pomodoroAddTemplate
    case pomodoroRemoveTemplate
    case calendarCardTitle
    case calendarPlaceholder
    case calendarVisibleLabel
    case calendarEnableAccess
    case calendarOpenFullApp
    case calendarAccessNotDeterminedStatus
    case calendarAccessDeniedStatus
    case calendarAccessUnavailableStatus
    case calendarLoadingStatus
    case calendarNoEvents
    case calendarFallbackSourceTitle
    case calendarUntitledEvent
    case calendarSourcesLabel
    case calendarNoSources
    case calendarRefreshSources
    case settingsButton
    case exitButton
    case exitConfirmationTitle
    case exitConfirmationMessage
    case cancelButton
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
    case automaticUpdatesLabel
    case launchAtLoginLabel
    case markdownStorageLocationLabel
    case chooseMarkdownStorageLocation
    case markdownStorageLocationHelp
    case quickAddHotkeyLabel
    case quickAddHotkeyDisabled
    case quickAddHotkeyStatusDisabled
    case quickAddHotkeyStatusRegistered
    case quickAddHotkeyStatusConflict
    case quickAddHotkeyStatusFailed
    case hotkeySpaceKey
    case hotkeyUnknownKeyFormat
    case quickAddTitle
    case quickAddSubmitButton
    case quickAddCancelButton
    case moveUp
    case moveDown
    case featureComingSoon
    case appInfoTitle
    case versionLabel
    case buildLabel
    case acknowledgementsLabel
    case noThirdPartyRuntimeDependencies
    case close
}

public enum SupportedLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case german = "de"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"

    public static func resolve(from preferredLanguageIdentifiers: [String]) -> SupportedLanguage {
        for identifier in preferredLanguageIdentifiers {
            let languageCode = Locale(identifier: identifier).language.languageCode?.identifier
            if languageCode == english.rawValue {
                return .english
            }
            if languageCode == german.rawValue {
                return .german
            }
            if languageCode == korean.rawValue {
                return .korean
            }
            if languageCode == "zh" {
                return .chineseSimplified
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
        Self.localizedStrings[language]?[key] ?? Self.englishStrings[key] ?? key.rawValue
    }

    public func pomodoroTemplateName(_ template: PomodoroTemplate) -> String {
        switch template.id {
        case PomodoroTemplate.defaultFocus.id:
            return string(.pomodoroDefaultFocusName)
        case PomodoroTemplate.defaultShortFocus.id:
            return string(.pomodoroQuickFocusName)
        default:
            return template.name
        }
    }

    public func hotkeyDisplayString(_ binding: HotkeyBinding) -> String {
        "\(binding.modifiers.symbolDisplayString)\(hotkeyKeyName(for: binding.keyCode))"
    }

    public func calendarSourceTitle(_ source: CalendarSource) -> String {
        source.title == CalendarSource.fallbackTitle
            ? string(.calendarFallbackSourceTitle)
            : source.title
    }

    public func calendarEventTitle(_ event: CalendarEvent) -> String {
        event.title == CalendarEvent.fallbackTitle
            ? string(.calendarUntitledEvent)
            : event.title
    }

    public func acknowledgementsText(_ appInfo: AppInfo) -> String {
        appInfo.acknowledgements == AppInfo.noThirdPartyRuntimeDependencies
            ? string(.noThirdPartyRuntimeDependencies)
            : appInfo.acknowledgements
    }

    private func hotkeyKeyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 45:
            return "N"
        case 49:
            return string(.hotkeySpaceKey)
        default:
            return String(format: string(.hotkeyUnknownKeyFormat), keyCode)
        }
    }

    private static let englishStrings: [LocalizationKey: String] = [
        .appName: "Menu Bar Notes",
        .statusItemDescription: "Menu Bar Notes",
        .popoverTitle: "Today",
        .popoverSubtitle: "Quietly ready from the menu bar.",
        .progressSummaryFormat: "%d active items - %d completed today",
        .notesCardTitle: "Notes / Todos / Reminders",
        .notesPlaceholder: "No active records yet.",
        .historyPlaceholder: "No completed records yet.",
        .activeRecordsMode: "Active",
        .historyRecordsMode: "History",
        .noteKind: "Note",
        .todoKind: "Todo",
        .reminderKind: "Reminder",
        .addRecordPlaceholder: "Add a note, todo, or reminder",
        .addNoteButton: "Add Note",
        .addTodoButton: "Add Todo",
        .addReminderButton: "Add Reminder",
        .deleteRecordButton: "Delete record",
        .completeTodo: "Complete todo",
        .completeReminder: "Complete reminder",
        .completedTodo: "Completed",
        .reminderTimeLabel: "Reminder time",
        .notificationsDeniedStatus: "Notifications are off. Reminders still appear here.",
        .notificationsUnavailableStatus: "Notifications are unavailable. Reminders still appear here.",
        .notificationsFailedStatus: "Notification could not be scheduled. Reminder stays listed.",
        .noStorageLocation: "Using the default Markdown folder. Choose another in Settings if needed.",
        .recordAddError: "Could not save the record.",
        .pomodoroCardTitle: "Pomodoro",
        .pomodoroPlaceholder: "Focus timer is hidden.",
        .pomodoroTemplateLabel: "Template",
        .pomodoroDefaultFocusName: "Focus 25",
        .pomodoroQuickFocusName: "Quick Focus",
        .pomodoroNewTemplateNameFormat: "Focus %d",
        .pomodoroRemainingLabel: "Remaining",
        .pomodoroIdleStatus: "Ready",
        .pomodoroRunningStatus: "Focusing",
        .pomodoroPausedStatus: "Paused",
        .pomodoroCompletedStatus: "Complete",
        .pomodoroStart: "Start",
        .pomodoroPause: "Pause",
        .pomodoroResume: "Resume",
        .pomodoroStop: "Stop",
        .pomodoroVisibleLabel: "Show Pomodoro card",
        .pomodoroTemplatesLabel: "Timer Templates",
        .pomodoroTemplateNamePlaceholder: "Template name",
        .pomodoroFocusMinutesLabel: "Focus minutes",
        .pomodoroAddTemplate: "Add Template",
        .pomodoroRemoveTemplate: "Remove Template",
        .calendarCardTitle: "Calendar",
        .calendarPlaceholder: "Upcoming events will appear here.",
        .calendarVisibleLabel: "Show Calendar card",
        .calendarEnableAccess: "Show Events",
        .calendarOpenFullApp: "Open Calendar",
        .calendarAccessNotDeterminedStatus: "Calendar access is off until you show events.",
        .calendarAccessDeniedStatus: "Calendar access is denied. The rest of the app still works.",
        .calendarAccessUnavailableStatus: "Calendar events are unavailable on this Mac.",
        .calendarLoadingStatus: "Loading calendar events...",
        .calendarNoEvents: "No upcoming events.",
        .calendarFallbackSourceTitle: "Calendar",
        .calendarUntitledEvent: "Untitled Event",
        .calendarSourcesLabel: "Calendar Sources",
        .calendarNoSources: "No calendars are available.",
        .calendarRefreshSources: "Refresh Calendars",
        .settingsButton: "Settings",
        .exitButton: "Exit",
        .exitConfirmationTitle: "Quit Menu Bar Notes?",
        .exitConfirmationMessage: "Are you sure you want to quit %@?",
        .cancelButton: "Cancel",
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
        .automaticUpdatesLabel: "Automatic Updates",
        .launchAtLoginLabel: "Launch at Login",
        .markdownStorageLocationLabel: "Markdown Storage Location",
        .chooseMarkdownStorageLocation: "Choose Folder...",
        .markdownStorageLocationHelp: "Notes, todos, and reminders are saved to one Markdown file in this folder.",
        .quickAddHotkeyLabel: "Quick Add Hotkey",
        .quickAddHotkeyDisabled: "Disabled",
        .quickAddHotkeyStatusDisabled: "Quick Add is disabled.",
        .quickAddHotkeyStatusRegistered: "Quick Add is ready: %@.",
        .quickAddHotkeyStatusConflict: "That shortcut is already in use. Choose another hotkey.",
        .quickAddHotkeyStatusFailed: "Quick Add could not register this shortcut.",
        .hotkeySpaceKey: "Space",
        .hotkeyUnknownKeyFormat: "Key %d",
        .quickAddTitle: "Quick Add",
        .quickAddSubmitButton: "Add",
        .quickAddCancelButton: "Cancel",
        .moveUp: "Move Up",
        .moveDown: "Move Down",
        .featureComingSoon: "Configuration for this area arrives in a later phase.",
        .appInfoTitle: "App Information",
        .versionLabel: "Version",
        .buildLabel: "Build",
        .acknowledgementsLabel: "Acknowledgements",
        .noThirdPartyRuntimeDependencies: "No third-party runtime dependencies.",
        .close: "Close"
    ]

    private static let germanStrings: [LocalizationKey: String] = [
        .appName: "Menu Bar Notes",
        .statusItemDescription: "Menu Bar Notes",
        .popoverTitle: "Heute",
        .popoverSubtitle: "Leise aus der Menüleiste bereit.",
        .progressSummaryFormat: "%d aktive Einträge - %d heute erledigt",
        .notesCardTitle: "Notizen / Aufgaben / Erinnerungen",
        .notesPlaceholder: "Noch keine aktiven Einträge.",
        .historyPlaceholder: "Noch keine erledigten Einträge.",
        .activeRecordsMode: "Aktiv",
        .historyRecordsMode: "Verlauf",
        .noteKind: "Notiz",
        .todoKind: "Aufgabe",
        .reminderKind: "Erinnerung",
        .addRecordPlaceholder: "Notiz, Aufgabe oder Erinnerung hinzufügen",
        .addNoteButton: "Notiz hinzufügen",
        .addTodoButton: "Aufgabe hinzufügen",
        .addReminderButton: "Erinnerung hinzufügen",
        .deleteRecordButton: "Eintrag löschen",
        .completeTodo: "Aufgabe erledigen",
        .completeReminder: "Erinnerung erledigen",
        .completedTodo: "Erledigt",
        .reminderTimeLabel: "Erinnerungszeit",
        .notificationsDeniedStatus: "Mitteilungen sind aus. Erinnerungen bleiben hier sichtbar.",
        .notificationsUnavailableStatus: "Mitteilungen sind nicht verfügbar. Erinnerungen bleiben hier sichtbar.",
        .notificationsFailedStatus: "Mitteilung konnte nicht geplant werden. Die Erinnerung bleibt sichtbar.",
        .noStorageLocation: "Der Standard-Markdown-Ordner wird verwendet. Wähle bei Bedarf einen anderen in den Einstellungen.",
        .recordAddError: "Eintrag konnte nicht gespeichert werden.",
        .pomodoroCardTitle: "Pomodoro",
        .pomodoroPlaceholder: "Fokus-Timer ist ausgeblendet.",
        .pomodoroTemplateLabel: "Vorlage",
        .pomodoroDefaultFocusName: "Fokus 25",
        .pomodoroQuickFocusName: "Kurzer Fokus",
        .pomodoroNewTemplateNameFormat: "Fokus %d",
        .pomodoroRemainingLabel: "Verbleibend",
        .pomodoroIdleStatus: "Bereit",
        .pomodoroRunningStatus: "Fokus",
        .pomodoroPausedStatus: "Pausiert",
        .pomodoroCompletedStatus: "Fertig",
        .pomodoroStart: "Starten",
        .pomodoroPause: "Pausieren",
        .pomodoroResume: "Fortsetzen",
        .pomodoroStop: "Stoppen",
        .pomodoroVisibleLabel: "Pomodoro-Karte anzeigen",
        .pomodoroTemplatesLabel: "Timer-Vorlagen",
        .pomodoroTemplateNamePlaceholder: "Vorlagenname",
        .pomodoroFocusMinutesLabel: "Fokusminuten",
        .pomodoroAddTemplate: "Vorlage hinzufügen",
        .pomodoroRemoveTemplate: "Vorlage entfernen",
        .calendarCardTitle: "Kalender",
        .calendarPlaceholder: "Anstehende Termine erscheinen hier.",
        .calendarVisibleLabel: "Kalenderkarte anzeigen",
        .calendarEnableAccess: "Termine anzeigen",
        .calendarOpenFullApp: "Kalender öffnen",
        .calendarAccessNotDeterminedStatus: "Kalenderzugriff bleibt aus, bis Termine angezeigt werden.",
        .calendarAccessDeniedStatus: "Kalenderzugriff ist verweigert. Der Rest der App funktioniert weiter.",
        .calendarAccessUnavailableStatus: "Kalendertermine sind auf diesem Mac nicht verfügbar.",
        .calendarLoadingStatus: "Kalendertermine werden geladen...",
        .calendarNoEvents: "Keine anstehenden Termine.",
        .calendarFallbackSourceTitle: "Kalender",
        .calendarUntitledEvent: "Unbenannter Termin",
        .calendarSourcesLabel: "Kalenderquellen",
        .calendarNoSources: "Keine Kalender verfügbar.",
        .calendarRefreshSources: "Kalender aktualisieren",
        .settingsButton: "Einstellungen",
        .exitButton: "Beenden",
        .exitConfirmationTitle: "Menu Bar Notes beenden?",
        .exitConfirmationMessage: "Möchtest du %@ wirklich beenden?",
        .cancelButton: "Abbrechen",
        .appInfoButton: "App-Info",
        .settingsTitle: "Einstellungen",
        .generalTab: "Allgemein",
        .notesTodosTab: "Notizen/Aufgaben",
        .pomodoroTab: "Pomodoro",
        .calendarTab: "Kalender",
        .appearanceLabel: "Erscheinungsbild",
        .appearanceSystem: "System",
        .appearanceLight: "Hell",
        .appearanceDark: "Dunkel",
        .cardOrderLabel: "Kartenreihenfolge",
        .automaticUpdatesLabel: "Automatische Updates",
        .launchAtLoginLabel: "Beim Anmelden starten",
        .markdownStorageLocationLabel: "Markdown-Speicherort",
        .chooseMarkdownStorageLocation: "Ordner wählen...",
        .markdownStorageLocationHelp: "Notizen, Aufgaben und Erinnerungen werden in einer Markdown-Datei in diesem Ordner gespeichert.",
        .quickAddHotkeyLabel: "Schnellerfassung-Tastenkürzel",
        .quickAddHotkeyDisabled: "Deaktiviert",
        .quickAddHotkeyStatusDisabled: "Schnellerfassung ist deaktiviert.",
        .quickAddHotkeyStatusRegistered: "Schnellerfassung ist bereit: %@.",
        .quickAddHotkeyStatusConflict: "Dieses Kürzel wird bereits verwendet. Wähle ein anderes.",
        .quickAddHotkeyStatusFailed: "Schnellerfassung konnte dieses Kürzel nicht registrieren.",
        .hotkeySpaceKey: "Leertaste",
        .hotkeyUnknownKeyFormat: "Taste %d",
        .quickAddTitle: "Schnellerfassung",
        .quickAddSubmitButton: "Hinzufügen",
        .quickAddCancelButton: "Abbrechen",
        .moveUp: "Nach oben",
        .moveDown: "Nach unten",
        .featureComingSoon: "Die Konfiguration für diesen Bereich kommt in einer späteren Phase.",
        .appInfoTitle: "App-Informationen",
        .versionLabel: "Version",
        .buildLabel: "Build",
        .acknowledgementsLabel: "Danksagungen",
        .noThirdPartyRuntimeDependencies: "Keine Laufzeitabhängigkeiten von Drittanbietern.",
        .close: "Schließen"
    ]

    private static let koreanStrings: [LocalizationKey: String] = [
        .appName: "Menu Bar Notes",
        .statusItemDescription: "Menu Bar Notes",
        .popoverTitle: "오늘",
        .popoverSubtitle: "메뉴 막대에서 조용히 대기합니다.",
        .progressSummaryFormat: "활성 항목 %d개 - 오늘 완료 %d개",
        .notesCardTitle: "노트 / 할 일 / 미리 알림",
        .notesPlaceholder: "아직 활성 기록이 없습니다.",
        .historyPlaceholder: "아직 완료된 기록이 없습니다.",
        .activeRecordsMode: "활성",
        .historyRecordsMode: "기록",
        .noteKind: "노트",
        .todoKind: "할 일",
        .reminderKind: "알림",
        .addRecordPlaceholder: "노트, 할 일 또는 알림 추가",
        .addNoteButton: "노트 추가",
        .addTodoButton: "할 일 추가",
        .addReminderButton: "알림 추가",
        .deleteRecordButton: "기록 삭제",
        .completeTodo: "할 일 완료",
        .completeReminder: "알림 완료",
        .completedTodo: "완료됨",
        .reminderTimeLabel: "알림 시간",
        .notificationsDeniedStatus: "알림이 꺼져 있습니다. 알림 항목은 계속 여기에 표시됩니다.",
        .notificationsUnavailableStatus: "알림을 사용할 수 없습니다. 알림 항목은 계속 여기에 표시됩니다.",
        .notificationsFailedStatus: "알림을 예약하지 못했습니다. 알림 항목은 계속 표시됩니다.",
        .noStorageLocation: "기본 Markdown 폴더를 사용합니다. 필요하면 설정에서 다른 폴더를 선택하세요.",
        .recordAddError: "기록을 저장할 수 없습니다.",
        .pomodoroCardTitle: "포모도로",
        .pomodoroPlaceholder: "집중 타이머가 숨겨져 있습니다.",
        .pomodoroTemplateLabel: "템플릿",
        .pomodoroDefaultFocusName: "집중 25",
        .pomodoroQuickFocusName: "짧은 집중",
        .pomodoroNewTemplateNameFormat: "집중 %d",
        .pomodoroRemainingLabel: "남은 시간",
        .pomodoroIdleStatus: "준비됨",
        .pomodoroRunningStatus: "집중 중",
        .pomodoroPausedStatus: "일시 정지",
        .pomodoroCompletedStatus: "완료",
        .pomodoroStart: "시작",
        .pomodoroPause: "일시 정지",
        .pomodoroResume: "재개",
        .pomodoroStop: "중지",
        .pomodoroVisibleLabel: "포모도로 카드 표시",
        .pomodoroTemplatesLabel: "타이머 템플릿",
        .pomodoroTemplateNamePlaceholder: "템플릿 이름",
        .pomodoroFocusMinutesLabel: "집중 시간(분)",
        .pomodoroAddTemplate: "템플릿 추가",
        .pomodoroRemoveTemplate: "템플릿 제거",
        .calendarCardTitle: "캘린더",
        .calendarPlaceholder: "예정된 일정이 여기에 표시됩니다.",
        .calendarVisibleLabel: "캘린더 카드 표시",
        .calendarEnableAccess: "일정 표시",
        .calendarOpenFullApp: "캘린더 열기",
        .calendarAccessNotDeterminedStatus: "일정을 표시하기 전까지 캘린더 접근은 꺼져 있습니다.",
        .calendarAccessDeniedStatus: "캘린더 접근이 거부되었습니다. 앱의 다른 기능은 계속 작동합니다.",
        .calendarAccessUnavailableStatus: "이 Mac에서는 캘린더 일정을 사용할 수 없습니다.",
        .calendarLoadingStatus: "캘린더 일정을 불러오는 중...",
        .calendarNoEvents: "예정된 일정이 없습니다.",
        .calendarFallbackSourceTitle: "캘린더",
        .calendarUntitledEvent: "제목 없는 일정",
        .calendarSourcesLabel: "캘린더 소스",
        .calendarNoSources: "사용 가능한 캘린더가 없습니다.",
        .calendarRefreshSources: "캘린더 새로 고침",
        .settingsButton: "설정",
        .exitButton: "종료",
        .exitConfirmationTitle: "Menu Bar Notes를 종료할까요?",
        .exitConfirmationMessage: "정말 %@을 종료하시겠습니까?",
        .cancelButton: "취소",
        .appInfoButton: "앱 정보",
        .settingsTitle: "설정",
        .generalTab: "일반",
        .notesTodosTab: "노트/할 일",
        .pomodoroTab: "포모도로",
        .calendarTab: "캘린더",
        .appearanceLabel: "화면 모드",
        .appearanceSystem: "시스템",
        .appearanceLight: "라이트",
        .appearanceDark: "다크",
        .cardOrderLabel: "카드 순서",
        .automaticUpdatesLabel: "자동 업데이트",
        .launchAtLoginLabel: "로그인 시 실행",
        .markdownStorageLocationLabel: "Markdown 저장 위치",
        .chooseMarkdownStorageLocation: "폴더 선택...",
        .markdownStorageLocationHelp: "노트, 할 일, 리마인더는 이 폴더의 Markdown 파일 하나에 저장됩니다.",
        .quickAddHotkeyLabel: "빠른 추가 단축키",
        .quickAddHotkeyDisabled: "사용 안 함",
        .quickAddHotkeyStatusDisabled: "빠른 추가가 꺼져 있습니다.",
        .quickAddHotkeyStatusRegistered: "빠른 추가 준비됨: %@.",
        .quickAddHotkeyStatusConflict: "이미 사용 중인 단축키입니다. 다른 단축키를 선택하세요.",
        .quickAddHotkeyStatusFailed: "이 단축키를 빠른 추가에 등록할 수 없습니다.",
        .hotkeySpaceKey: "스페이스",
        .hotkeyUnknownKeyFormat: "키 %d",
        .quickAddTitle: "빠른 추가",
        .quickAddSubmitButton: "추가",
        .quickAddCancelButton: "취소",
        .moveUp: "위로 이동",
        .moveDown: "아래로 이동",
        .featureComingSoon: "이 영역의 구성은 이후 단계에서 제공됩니다.",
        .appInfoTitle: "앱 정보",
        .versionLabel: "버전",
        .buildLabel: "빌드",
        .acknowledgementsLabel: "감사의 말",
        .noThirdPartyRuntimeDependencies: "타사 런타임 의존성이 없습니다.",
        .close: "닫기"
    ]

    private static let chineseSimplifiedStrings: [LocalizationKey: String] = [
        .appName: "Menu Bar Notes",
        .statusItemDescription: "Menu Bar Notes",
        .popoverTitle: "今天",
        .popoverSubtitle: "在菜单栏中安静待命。",
        .progressSummaryFormat: "%d 个活跃项目 - 今日完成 %d 个",
        .notesCardTitle: "笔记 / 待办 / 提醒",
        .notesPlaceholder: "还没有活跃记录。",
        .historyPlaceholder: "还没有已完成记录。",
        .activeRecordsMode: "活跃",
        .historyRecordsMode: "历史",
        .noteKind: "笔记",
        .todoKind: "待办",
        .reminderKind: "提醒",
        .addRecordPlaceholder: "添加笔记、待办或提醒",
        .addNoteButton: "添加笔记",
        .addTodoButton: "添加待办",
        .addReminderButton: "添加提醒",
        .deleteRecordButton: "删除记录",
        .completeTodo: "完成待办",
        .completeReminder: "完成提醒",
        .completedTodo: "已完成",
        .reminderTimeLabel: "提醒时间",
        .notificationsDeniedStatus: "通知已关闭。提醒仍会显示在这里。",
        .notificationsUnavailableStatus: "通知不可用。提醒仍会显示在这里。",
        .notificationsFailedStatus: "通知无法安排。提醒仍会保留显示。",
        .noStorageLocation: "正在使用默认 Markdown 文件夹。如有需要，可在设置中选择其他文件夹。",
        .recordAddError: "无法保存记录。",
        .pomodoroCardTitle: "番茄钟",
        .pomodoroPlaceholder: "专注计时器已隐藏。",
        .pomodoroTemplateLabel: "模板",
        .pomodoroDefaultFocusName: "专注 25",
        .pomodoroQuickFocusName: "快速专注",
        .pomodoroNewTemplateNameFormat: "专注 %d",
        .pomodoroRemainingLabel: "剩余",
        .pomodoroIdleStatus: "就绪",
        .pomodoroRunningStatus: "专注中",
        .pomodoroPausedStatus: "已暂停",
        .pomodoroCompletedStatus: "完成",
        .pomodoroStart: "开始",
        .pomodoroPause: "暂停",
        .pomodoroResume: "继续",
        .pomodoroStop: "停止",
        .pomodoroVisibleLabel: "显示番茄钟卡片",
        .pomodoroTemplatesLabel: "计时器模板",
        .pomodoroTemplateNamePlaceholder: "模板名称",
        .pomodoroFocusMinutesLabel: "专注分钟",
        .pomodoroAddTemplate: "添加模板",
        .pomodoroRemoveTemplate: "移除模板",
        .calendarCardTitle: "日历",
        .calendarPlaceholder: "即将开始的日程会显示在这里。",
        .calendarVisibleLabel: "显示日历卡片",
        .calendarEnableAccess: "显示日程",
        .calendarOpenFullApp: "打开日历",
        .calendarAccessNotDeterminedStatus: "显示日程前，日历访问保持关闭。",
        .calendarAccessDeniedStatus: "日历访问已被拒绝。应用其他功能仍可使用。",
        .calendarAccessUnavailableStatus: "这台 Mac 上无法使用日历日程。",
        .calendarLoadingStatus: "正在加载日历日程...",
        .calendarNoEvents: "没有即将开始的日程。",
        .calendarFallbackSourceTitle: "日历",
        .calendarUntitledEvent: "无标题日程",
        .calendarSourcesLabel: "日历来源",
        .calendarNoSources: "没有可用日历。",
        .calendarRefreshSources: "刷新日历",
        .settingsButton: "设置",
        .exitButton: "退出",
        .exitConfirmationTitle: "退出 Menu Bar Notes？",
        .exitConfirmationMessage: "确定要退出 %@ 吗？",
        .cancelButton: "取消",
        .appInfoButton: "应用信息",
        .settingsTitle: "设置",
        .generalTab: "通用",
        .notesTodosTab: "笔记/待办",
        .pomodoroTab: "番茄钟",
        .calendarTab: "日历",
        .appearanceLabel: "外观",
        .appearanceSystem: "系统",
        .appearanceLight: "浅色",
        .appearanceDark: "深色",
        .cardOrderLabel: "卡片顺序",
        .automaticUpdatesLabel: "自动更新",
        .launchAtLoginLabel: "登录时启动",
        .markdownStorageLocationLabel: "Markdown 存储位置",
        .chooseMarkdownStorageLocation: "选择文件夹...",
        .markdownStorageLocationHelp: "笔记、待办和提醒会保存在此文件夹中的一个 Markdown 文件里。",
        .quickAddHotkeyLabel: "快速添加快捷键",
        .quickAddHotkeyDisabled: "已禁用",
        .quickAddHotkeyStatusDisabled: "快速添加已关闭。",
        .quickAddHotkeyStatusRegistered: "快速添加已就绪：%@。",
        .quickAddHotkeyStatusConflict: "该快捷键已被占用。请选择其他快捷键。",
        .quickAddHotkeyStatusFailed: "快速添加无法注册此快捷键。",
        .hotkeySpaceKey: "空格",
        .hotkeyUnknownKeyFormat: "按键 %d",
        .quickAddTitle: "快速添加",
        .quickAddSubmitButton: "添加",
        .quickAddCancelButton: "取消",
        .moveUp: "上移",
        .moveDown: "下移",
        .featureComingSoon: "此区域的配置将在后续阶段提供。",
        .appInfoTitle: "应用信息",
        .versionLabel: "版本",
        .buildLabel: "构建",
        .acknowledgementsLabel: "致谢",
        .noThirdPartyRuntimeDependencies: "没有第三方运行时依赖。",
        .close: "关闭"
    ]

    private static let localizedStrings: [SupportedLanguage: [LocalizationKey: String]] = [
        .english: englishStrings,
        .german: germanStrings,
        .korean: koreanStrings,
        .chineseSimplified: chineseSimplifiedStrings
    ]
}
