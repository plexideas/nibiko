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
    let showAppInfo: () -> Void

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
                            addError: $addError
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
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()

            HStack(spacing: 8) {
                Button(localizer.string(.settingsButton), action: showSettings)
                Spacer()
                Button(localizer.string(.appInfoButton), action: showAppInfo)
            }
            .controlSize(.small)
            .font(.system(size: 12))
            .padding(12)
        }
        .frame(width: 340, height: 540)
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
    @FocusState private var isDraftFocused: Bool
    private let maximumVisibleRows = 5
    private let recordRowHeight: CGFloat = 24
    private let recordRowSpacing: CGFloat = 3

    private var displayedRecords: [Record] {
        RecordDisplaySupport.recordsForDisplay(
            recordListStore.records.filter { $0.kind == .note || $0.kind == .todo || $0.kind == .reminder }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.string(.notesCardTitle))
                .font(.system(size: 12, weight: .semibold))

            if let notificationStatusText {
                Text(notificationStatusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if recordListStore.lastErrorDescription != nil {
                Text(localizer.string(.recordAddError))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if displayedRecords.isEmpty {
                Text(emptyText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if displayedRecords.count > maximumVisibleRows {
                ScrollView {
                    recordRows
                }
                .frame(height: recordListHeight)
            } else {
                recordRows
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Picker("", selection: $draftKind) {
                    Text(localizer.string(.todoKind)).tag(RecordKind.todo)
                    Text(localizer.string(.noteKind)).tag(RecordKind.note)
                    Text(localizer.string(.reminderKind)).tag(RecordKind.reminder)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)

                if draftKind == .reminder {
                    DatePicker(
                        localizer.string(.reminderTimeLabel),
                        selection: $draftReminderAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(.system(size: 11))
                    .controlSize(.small)
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
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            isDraftFocused = true
        }
    }

    private var recordListHeight: CGFloat {
        cappedListHeight(count: displayedRecords.count, rowHeight: recordRowHeight, spacing: recordRowSpacing)
    }

    private var recordRows: some View {
        VStack(spacing: recordRowSpacing) {
            ForEach(displayedRecords) { record in
                RecordRow(record: record, localizer: localizer) {
                    try? recordListStore.completeRecord(id: record.id)
                }
                .frame(minHeight: recordRowHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cappedListHeight(count: Int, rowHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        let visibleRows = min(count, maximumVisibleRows)
        let visibleGaps = max(visibleRows - 1, 0)
        return CGFloat(visibleRows) * rowHeight + CGFloat(visibleGaps) * spacing
    }

    private var emptyText: String {
        recordListStore.hasStorageDirectory
            ? localizer.string(.notesPlaceholder)
            : localizer.string(.noStorageLocation)
    }

    private var trimmedTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
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
        } catch RecordListStoreError.missingStorageDirectory {
            addError = localizer.string(.noStorageLocation)
        } catch {
            addError = localizer.string(.recordAddError)
        }
    }
}

private struct RecordRow: View {
    let record: Record
    let localizer: Localizer
    let complete: () -> Void

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
        }
    }

    private var completeHelpText: String {
        if record.status == .completed {
            return localizer.string(.completedTodo)
        }

        return localizer.string(record.kind == .reminder ? .completeReminder : .completeTodo)
    }
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
                        Button(action: start) {
                            Image(systemName: "play.fill")
                        }
                        .help(localizer.string(.pomodoroStart))
                    }

                    if pomodoroTimer.canPause {
                        Button(action: pomodoroTimer.pause) {
                            Image(systemName: "pause.fill")
                        }
                        .help(localizer.string(.pomodoroPause))
                    }

                    if pomodoroTimer.canResume {
                        Button(action: pomodoroTimer.resume) {
                            Image(systemName: "play.fill")
                        }
                        .help(localizer.string(.pomodoroResume))
                    }

                    Button(action: pomodoroTimer.stop) {
                        Image(systemName: "stop.fill")
                    }
                    .help(localizer.string(.pomodoroStop))
                    .disabled(pomodoroTimer.session.state == .idle)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
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
                ScrollView {
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
