import MenuBarNotesCore
import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var recordListStore: RecordListStore
    @ObservedObject var reminderNotificationStore: ReminderNotificationStore
    @ObservedObject var pomodoroTimer: PomodoroTimer
    @ObservedObject var calendarEventsStore: CalendarEventsStore
    let captureService: QuickAddCaptureService
    @State private var draftTitle = ""
    @State private var draftKind: RecordKind = .todo
    @State private var draftReminderAt = Date().addingTimeInterval(3_600)
    @State private var addError: String?

    let localizer: Localizer
    let showSettings: () -> Void
    let requestQuit: () -> Void
    let requestContentResize: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                header

                ForEach(visibleCards) { card in
                    if card == .notes {
                        NotesTodosCard(
                            recordListStore: recordListStore,
                            reminderNotificationStore: reminderNotificationStore,
                            captureService: captureService,
                            localizer: localizer,
                            draftTitle: $draftTitle,
                            draftKind: $draftKind,
                            draftReminderAt: $draftReminderAt,
                            addError: $addError,
                            requestContentResize: requestContentResize
                        )
                    } else if card == .pomodoro {
                        PomodoroCard(
                            settingsStore: settingsStore,
                            pomodoroTimer: pomodoroTimer,
                            localizer: localizer
                        )
                    } else {
                        CalendarCard(
                            settingsStore: settingsStore,
                            calendarEventsStore: calendarEventsStore,
                            localizer: localizer
                        )
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Divider()

            HStack(spacing: 8) {
                Button(localizer.string(.settingsButton), action: showSettings)
                Spacer()
                Button(localizer.string(.exitButton), action: requestQuit)
            }
            .controlSize(.small)
            .font(.system(size: 12))
            .padding(12)
        }
        .frame(width: 340)
    }

    private var header: some View {
        let completedToday = recordListStore.records.filter { record in
            guard let completedAt = record.completedAt else {
                return false
            }
            return Calendar.current.isDateInToday(completedAt)
        }.count
        let progress = String(
            format: localizer.string(.progressSummaryFormat),
            recordListStore.activeCount,
            completedToday
        )

        return VStack(alignment: .leading, spacing: 4) {
            Text(localizer.string(.popoverTitle))
                .font(.system(size: 17, weight: .semibold))

            Text(localizer.string(.popoverSubtitle))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(progress)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }

    private var visibleCards: [MenuCard] {
        MenuCardVisibility.visibleCards(from: settingsStore.settings)
    }
}

private struct NotesTodosCard: View {
    @ObservedObject var recordListStore: RecordListStore
    @ObservedObject var reminderNotificationStore: ReminderNotificationStore
    let captureService: QuickAddCaptureService
    let localizer: Localizer
    @Binding var draftTitle: String
    @Binding var draftKind: RecordKind
    @Binding var draftReminderAt: Date
    @Binding var addError: String?
    @State private var recordDisplayMode: RecordDisplayMode = .active
    let requestContentResize: () -> Void
    @FocusState private var isDraftFocused: Bool
    private let maximumVisibleRows = 5
    private let compactRecordRowHeight: CGFloat = 24
    private let detailedRecordRowHeight: CGFloat = 38
    private let recordRowSpacing: CGFloat = 3
    private let reminderDraftListHeightAllowance: CGFloat = 32
    private let minimumScrollableRecordListHeight: CGFloat = 96

    private var displayedRecords: [Record] {
        switch recordDisplayMode {
        case .active:
            return RecordDisplaySupport.activeRecordsForDisplay(allDisplayableRecords)
        case .history:
            return RecordDisplaySupport.historyRecordsForDisplay(allDisplayableRecords)
        }
    }

    private var allDisplayableRecords: [Record] {
        recordListStore.records.filter { $0.kind == .note || $0.kind == .todo || $0.kind == .reminder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.string(.notesCardTitle))
                .font(.system(size: 12, weight: .semibold))

            Picker("", selection: $recordDisplayMode) {
                Text(localizer.string(.activeRecordsMode)).tag(RecordDisplayMode.active)
                Text(localizer.string(.historyRecordsMode)).tag(RecordDisplayMode.history)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)

            if let notificationStatusText {
                Text(notificationStatusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            recordListContent
                .frame(height: recordListHeight, alignment: .top)
                .animation(.easeInOut(duration: 0.16), value: recordListHeight)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: $draftKind) {
                    Text(localizer.string(.todoKind)).tag(RecordKind.todo)
                    Text(localizer.string(.noteKind)).tag(RecordKind.note)
                    Text(localizer.string(.reminderKind)).tag(RecordKind.reminder)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)

                if isReminderDraft {
                    DatePicker(
                        localizer.string(.reminderTimeLabel),
                        selection: $draftReminderAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(.system(size: 11))
                    .controlSize(.small)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HStack(spacing: 6) {
                    TextField(localizer.string(.addRecordPlaceholder), text: $draftTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .focused($isDraftFocused)
                        .onSubmit(addRecord)

                    Button(action: addRecord) {
                        Image(systemName: "plus")
                    }
                    .help(addButtonHelp)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedTitle.isEmpty || recordListStore.lastErrorDescription != nil)
                }
                .controlSize(.small)

                if let addError {
                    Text(addError)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.16), value: isReminderDraft)
            .animation(.easeInOut(duration: 0.16), value: addError)
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            isDraftFocused = true
        }
        .onChange(of: draftKind) { _, _ in
            requestContentResizeAfterLayout()
        }
        .onChange(of: recordDisplayMode) { _, _ in
            requestContentResizeAfterLayout()
        }
        .onChange(of: reminderNotificationStore.status) { _, _ in
            requestContentResizeAfterLayout()
        }
        .onChange(of: addError) { _, _ in
            requestContentResizeAfterLayout()
        }
        .onChange(of: recordListStore.lastErrorDescription) { _, _ in
            requestContentResizeAfterLayout()
        }
    }

    private var recordListHeight: CGFloat {
        let stableListHeight = cappedListHeight(
            rowHeights: Array(repeating: detailedRecordRowHeight, count: maximumVisibleRows),
            spacing: recordRowSpacing
        )
        guard isReminderDraft else {
            return stableListHeight
        }

        return max(stableListHeight - reminderDraftListHeightAllowance, minimumScrollableRecordListHeight)
    }

    @ViewBuilder
    private var recordListContent: some View {
        if recordListStore.lastErrorDescription != nil {
            Text(localizer.string(.recordAddError))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if displayedRecords.isEmpty {
            Text(emptyText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                recordRows
            }
        }
    }

    private var recordRows: some View {
        VStack(spacing: recordRowSpacing) {
            ForEach(displayedRecords) { record in
                RecordRow(
                    record: record,
                    localizer: localizer,
                    complete: {
                        try? recordListStore.completeRecord(id: record.id)
                    },
                    delete: {
                        try? recordListStore.deleteRecord(id: record.id)
                    }
                )
                .frame(minHeight: recordRowHeight(for: record))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cappedListHeight(rowHeights: [CGFloat], spacing: CGFloat) -> CGFloat {
        guard !rowHeights.isEmpty else {
            return 0
        }

        let visibleGaps = max(rowHeights.count - 1, 0)
        return rowHeights.reduce(0, +) + CGFloat(visibleGaps) * spacing
    }

    private func recordRowHeight(for record: Record) -> CGFloat {
        if record.status == .completed || RecordDisplaySupport.displayTime(for: record) != nil {
            return detailedRecordRowHeight
        }

        return compactRecordRowHeight
    }

    private var emptyText: String {
        guard recordListStore.hasStorageDirectory else {
            return localizer.string(.noStorageLocation)
        }

        switch recordDisplayMode {
        case .active:
            return localizer.string(.notesPlaceholder)
        case .history:
            return localizer.string(.historyPlaceholder)
        }
    }

    private var trimmedTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isReminderDraft: Bool {
        draftKind == .reminder
    }

    private var addButtonHelp: String {
        switch draftKind {
        case .note:
            return localizer.string(.addNoteButton)
        case .todo:
            return localizer.string(.addTodoButton)
        case .reminder:
            return localizer.string(.addReminderButton)
        }
    }

    private var notificationStatusText: String? {
        switch reminderNotificationStore.status {
        case .denied:
            return localizer.string(.notificationsDeniedStatus)
        case .unavailable:
            return localizer.string(.notificationsUnavailableStatus)
        case .failed:
            return localizer.string(.notificationsFailedStatus)
        case .idle, .scheduled:
            return nil
        }
    }

    private func addRecord() {
        guard !trimmedTitle.isEmpty else {
            return
        }

        do {
            let reminderAt = draftKind == .reminder ? draftReminderAt : nil
            try captureService.capture(
                QuickAddCaptureRequest(
                    source: .popover,
                    draft: RecordDraft(
                        kind: draftKind,
                        title: trimmedTitle,
                        dueAt: reminderAt,
                        reminderAt: reminderAt
                    )
                )
            )
            draftTitle = ""
            addError = nil
            recordDisplayMode = .active
        } catch RecordListStoreError.missingStorageDirectory {
            addError = localizer.string(.noStorageLocation)
        } catch {
            addError = localizer.string(.recordAddError)
        }
    }

    private func requestContentResizeAfterLayout() {
        Task { @MainActor in
            await Task.yield()
            requestContentResize()
        }
    }
}

private struct RecordRow: View {
    let record: Record
    let localizer: Localizer
    let complete: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if record.kind.isActionable {
                Button(action: complete) {
                    Image(systemName: record.status == .completed ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(completeHelpText)
                .disabled(record.status == .completed)
            } else {
                Image(systemName: "note.text")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.system(size: 12))
                    .strikethrough(record.status == .completed)
                    .foregroundStyle(record.status == .completed ? .secondary : .primary)
                    .lineLimit(2)

                if record.status == .completed {
                    Text(localizer.string(.completedTodo))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else if let displayTime = RecordDisplaySupport.displayTime(for: record) {
                    Text(displayTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Button(action: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help(localizer.string(.deleteRecordButton))
        }
    }

    private var completeHelpText: String {
        if record.status == .completed {
            return localizer.string(.completedTodo)
        }

        return localizer.string(record.kind == .reminder ? .completeReminder : .completeTodo)
    }
}

private enum RecordDisplayMode: Hashable {
    case active
    case history
}

private struct PomodoroCard: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var pomodoroTimer: PomodoroTimer
    let localizer: Localizer

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(localizer.string(.pomodoroCardTitle))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Picker(localizer.string(.pomodoroTemplateLabel), selection: selectedTemplateIDBinding) {
                ForEach(settingsStore.settings.pomodoroTemplates) { template in
                    Text(localizer.pomodoroTemplateName(template)).tag(template.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .disabled(!pomodoroTimer.canStart)

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizer.string(.pomodoroRemainingLabel))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(formattedRemaining)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .contentTransition(.numericText())
                }

                Spacer()

                HStack(spacing: 6) {
                    if pomodoroTimer.canStart {
                        PomodoroControlButton(
                            systemName: "play.fill",
                            helpText: localizer.string(.pomodoroStart),
                            prominence: .primary,
                            action: start
                        )
                    }

                    if pomodoroTimer.canPause {
                        PomodoroControlButton(
                            systemName: "pause.fill",
                            helpText: localizer.string(.pomodoroPause),
                            prominence: .primary,
                            action: pomodoroTimer.pause
                        )
                    }

                    if pomodoroTimer.canResume {
                        PomodoroControlButton(
                            systemName: "play.fill",
                            helpText: localizer.string(.pomodoroResume),
                            prominence: .primary,
                            action: pomodoroTimer.resume
                        )
                    }

                    PomodoroControlButton(
                        systemName: "stop.fill",
                        helpText: localizer.string(.pomodoroStop),
                        prominence: .destructive,
                        action: pomodoroTimer.stop
                    )
                    .disabled(pomodoroTimer.session.state == .idle)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .onReceive(ticker) { _ in
            pomodoroTimer.tick()
        }
    }

    private var selectedTemplateIDBinding: Binding<String> {
        Binding(
            get: { settingsStore.settings.selectedPomodoroTemplateID },
            set: { templateID in
                settingsStore.setSelectedPomodoroTemplateID(templateID)
                if let template = settingsStore.settings.pomodoroTemplates.first(where: { $0.id == templateID }) {
                    pomodoroTimer.selectTemplate(template)
                }
            }
        )
    }

    private var selectedTemplate: PomodoroTemplate {
        settingsStore.settings.pomodoroTemplates.first {
            $0.id == settingsStore.settings.selectedPomodoroTemplateID
        } ?? settingsStore.settings.pomodoroTemplates[0]
    }

    private var formattedRemaining: String {
        let remaining = pomodoroTimer.remainingSeconds
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private var statusText: String {
        switch pomodoroTimer.session.state {
        case .idle:
            return localizer.string(.pomodoroIdleStatus)
        case .running:
            return localizer.string(.pomodoroRunningStatus)
        case .paused:
            return localizer.string(.pomodoroPausedStatus)
        case .completed:
            return localizer.string(.pomodoroCompletedStatus)
        }
    }

    private func start() {
        pomodoroTimer.start(template: selectedTemplate)
    }
}

private enum PomodoroControlButtonProminence {
    case primary
    case destructive
}

private struct PomodoroControlButton: View {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    let systemName: String
    let helpText: String
    let prominence: PomodoroControlButtonProminence
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(Circle().fill(backgroundColor))
                .overlay(Circle().strokeBorder(borderColor, lineWidth: 1))
                .shadow(color: shadowColor, radius: isHovered && isEnabled ? 4 : 0, y: 1)
                .scaleEffect(isHovered && isEnabled ? 1.04 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(Text(helpText))
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.easeInOut(duration: 0.12), value: isEnabled)
    }

    private var backgroundColor: Color {
        switch prominence {
        case .primary:
            return Color.accentColor.opacity(isEnabled ? 0.92 : 0.22)
        case .destructive:
            return Color.red.opacity(isEnabled ? 0.88 : 0.05)
        }
    }

    private var iconColor: Color {
        switch prominence {
        case .primary:
            return Color.white.opacity(isEnabled ? 0.96 : 0.45)
        case .destructive:
            return isEnabled ? Color.white.opacity(0.96) : Color.secondary.opacity(0.45)
        }
    }

    private var borderColor: Color {
        switch prominence {
        case .primary:
            return Color.white.opacity(isEnabled ? 0.20 : 0.08)
        case .destructive:
            return isEnabled ? Color.white.opacity(0.22) : Color.primary.opacity(0.06)
        }
    }

    private var shadowColor: Color {
        switch prominence {
        case .primary:
            return Color.accentColor.opacity(0.28)
        case .destructive:
            return Color.red.opacity(0.24)
        }
    }
}

private struct CalendarCard: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var calendarEventsStore: CalendarEventsStore
    let localizer: Localizer
    private let maximumVisibleRows = 5
    private let eventRowHeight: CGFloat = 34
    private let eventRowSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(localizer.string(.calendarCardTitle))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: calendarEventsStore.openCalendar) {
                    Image(systemName: "calendar")
                }
                .help(localizer.string(.calendarOpenFullApp))
                .buttonStyle(.borderless)
            }

            content
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            calendarEventsStore.refresh(selectedSourceIDs: settingsStore.settings.selectedCalendarSourceIDs)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch calendarEventsStore.permissionState {
        case .notDetermined:
            statusWithAction(
                localizer.string(.calendarAccessNotDeterminedStatus),
                actionTitle: localizer.string(.calendarEnableAccess),
                action: requestCalendarAccess
            )
        case .denied:
            statusText(localizer.string(.calendarAccessDeniedStatus))
        case .unavailable:
            statusText(localizer.string(.calendarAccessUnavailableStatus))
        case .allowed:
            if calendarEventsStore.isLoading {
                statusText(localizer.string(.calendarLoadingStatus))
            } else if calendarEventsStore.lastErrorDescription != nil {
                statusText(localizer.string(.calendarAccessUnavailableStatus))
            } else if calendarEventsStore.events.isEmpty {
                statusText(localizer.string(.calendarNoEvents))
            } else if calendarEventsStore.events.count > maximumVisibleRows {
                ScrollView(.vertical, showsIndicators: false) {
                    eventRows
                }
                .frame(height: eventListHeight)
            } else {
                eventRows
            }
        }
    }

    private var eventListHeight: CGFloat {
        cappedListHeight(count: calendarEventsStore.events.count, rowHeight: eventRowHeight, spacing: eventRowSpacing)
    }

    private var eventRows: some View {
        LazyVStack(spacing: eventRowSpacing) {
            ForEach(calendarEventsStore.events) { event in
                CalendarEventRow(event: event, localizer: localizer)
                    .frame(minHeight: eventRowHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cappedListHeight(count: Int, rowHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        let visibleRows = min(count, maximumVisibleRows)
        let visibleGaps = max(visibleRows - 1, 0)
        return CGFloat(visibleRows) * rowHeight + CGFloat(visibleGaps) * spacing
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusWithAction(_ text: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            statusText(text)
            Button(actionTitle, action: action)
                .controlSize(.small)
        }
    }

    private func requestCalendarAccess() {
        calendarEventsStore.refresh(
            selectedSourceIDs: settingsStore.settings.selectedCalendarSourceIDs,
            requestPermissionIfNeeded: true
        )
    }
}

private struct CalendarEventRow: View {
    let event: CalendarEvent
    let localizer: Localizer

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.startsAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                Text(durationText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 58, alignment: .leading)

            Text(localizer.calendarEventTitle(event))
                .font(.system(size: 12))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var durationText: String {
        let minutes = max(1, Int(event.durationSeconds / 60))
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }
}
