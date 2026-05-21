import NibikoCore
import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var recordListStore: RecordListStore
    @ObservedObject var appleReminderProvider: EventKitReminderProvider
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
                            appleReminderProvider: appleReminderProvider,
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
        .preferredColorScheme(settingsStore.settings.appearanceMode.colorScheme)
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
    @ObservedObject var appleReminderProvider: EventKitReminderProvider
    @ObservedObject var reminderNotificationStore: ReminderNotificationStore
    let captureService: QuickAddCaptureService
    let localizer: Localizer
    @Binding var draftTitle: String
    @Binding var draftKind: RecordKind
    @Binding var draftReminderAt: Date
    @Binding var addError: String?
    @State private var recordDisplayMode: RecordDisplayMode = .active
    @State private var recordKindFilter: RecordKindFilter = .all
    @State private var currentDate = Date()
    @State private var isRecordKindFilterHovered = false
    @State private var isRecordKindFilterMenuPresented = false
    let requestContentResize: () -> Void
    @FocusState private var isDraftFocused: Bool
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
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
        EventKitReminderProvider
            .mergedRecords(localRecords: recordListStore.records, appleReminderRecords: appleReminderProvider.records)
            .filter { $0.kind == .note || $0.kind == .todo || $0.kind == .reminder }
            .filter { recordKindFilter.includes($0.kind) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.string(.notesCardTitle))
                .font(.system(size: 12, weight: .semibold))

            HStack(spacing: 8) {
                Picker("", selection: $recordDisplayMode) {
                    Text(localizer.string(.activeRecordsMode)).tag(RecordDisplayMode.active)
                    Text(localizer.string(.historyRecordsMode)).tag(RecordDisplayMode.history)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 228, alignment: .leading)

                Spacer(minLength: 0)

                recordKindFilterMenu
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

            VStack(alignment: .leading, spacing: 10) {
                TextField(localizer.string(.addRecordPlaceholder), text: $draftTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .focused($isDraftFocused)
                    .onSubmit(addRecord)
                    .frame(maxWidth: .infinity)

                if isReminderDraft {
                    ReminderDateTimePicker(
                        title: localizer.string(.reminderTimeLabel),
                        selection: $draftReminderAt
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HStack(spacing: 6) {
                    Picker("", selection: $draftKind) {
                        Text(localizer.string(.todoKind)).tag(RecordKind.todo)
                        Text(localizer.string(.noteKind)).tag(RecordKind.note)
                        Text(localizer.string(.reminderKind)).tag(RecordKind.reminder)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)

                    Button(action: addRecord) {
                        Text(addButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(width: 104)
                    .help(addButtonTitle)
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
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.secondary.opacity(0.14),
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 7,
                    bottomTrailingRadius: 7,
                    topTrailingRadius: 0
                )
            )
            .padding(.horizontal, -10)
            .padding(.bottom, -10)
            .animation(.easeInOut(duration: 0.16), value: isReminderDraft)
            .animation(.easeInOut(duration: 0.16), value: addError)
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            isDraftFocused = true
            currentDate = Date()
        }
        .onReceive(clock) { date in
            currentDate = date
        }
        .onChange(of: draftKind) { _, _ in
            requestContentResizeAfterLayout()
        }
        .onChange(of: recordDisplayMode) { _, _ in
            requestContentResizeAfterLayout()
        }
        .onChange(of: recordKindFilter) { _, _ in
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
                    now: currentDate,
                    complete: {
                        if EventKitReminderProvider.isAppleReminderRecordID(record.id) {
                            appleReminderProvider.completeRecord(id: record.id)
                        } else {
                            try? recordListStore.completeRecord(id: record.id)
                        }
                    },
                    delete: {
                        if EventKitReminderProvider.isAppleReminderRecordID(record.id) {
                            appleReminderProvider.deleteRecord(id: record.id)
                        } else {
                            try? recordListStore.deleteRecord(id: record.id)
                        }
                    }
                )
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

    private var recordKindFilterMenu: some View {
        Button {
            isRecordKindFilterMenuPresented.toggle()
        } label: {
            Image(systemName: recordKindFilter.iconName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(recordKindFilter == .all ? Color.secondary : Color.blue)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecordKindFilterHovered ? Color.secondary.opacity(0.10) : Color.clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28, alignment: .center)
        .help(recordKindFilter.title(localizer: localizer))
        .onHover { hovering in
            isRecordKindFilterHovered = hovering
        }
        .popover(isPresented: $isRecordKindFilterMenuPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                filterMenuItem(.all)
                filterMenuItem(.todo)
                filterMenuItem(.note)
                filterMenuItem(.reminder)
            }
            .padding(6)
            .frame(width: 132, alignment: .leading)
        }
    }

    private func filterMenuItem(_ filter: RecordKindFilter) -> some View {
        Button {
            recordKindFilter = filter
            isRecordKindFilterMenuPresented = false
        } label: {
            HStack(spacing: 8) {
                Text(filter.title(localizer: localizer))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if recordKindFilter == filter {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var trimmedTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isReminderDraft: Bool {
        draftKind == .reminder
    }

    private var addButtonTitle: String {
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
            if !recordKindFilter.includes(draftKind) {
                recordKindFilter = .all
            }
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

struct ReminderDateTimePicker: View {
    let title: String
    @Binding var selection: Date
    @State private var isPickerPresented = false
    @State private var visibleMonth = Date()
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.fixed(28), spacing: 8), count: 7)

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            dateTimeButton(dateTimeTitle)
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
            calendarPopover
                .onAppear {
                    visibleMonth = calendar.startOfMonth(for: selection)
                }
        }
    }

    private var calendarPopover: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button {
                    visibleMonth = calendar.startOfMonth(for: Date())
                } label: {
                    Text(monthTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 18)
                }

                ForEach(monthDays, id: \.self) { date in
                    Button {
                        selection = calendar.date(
                            bySettingHour: calendar.component(.hour, from: selection),
                            minute: calendar.component(.minute, from: selection),
                            second: 0,
                            of: date
                        ) ?? date
                    } label: {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 14, weight: isSelected(date) ? .semibold : .regular))
                            .frame(width: 28, height: 28)
                            .foregroundStyle(dayForeground(for: date))
                            .background(dayBackground(for: date))
                    }
                    .buttonStyle(.plain)
                    .disabled(!calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month))
                }
            }

            Divider()

            TimeEntryControl(selection: $selection)
        }
        .padding(16)
        .frame(width: 284)
    }

    private var dateTitle: String {
        selection.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var timeTitle: String {
        selection.formatted(.dateTime.hour().minute())
    }

    private var dateTimeTitle: String {
        "\(dateTitle) \(timeTitle)"
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var monthDays: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
            let monthRange = calendar.range(of: .day, in: .month, for: visibleMonth)
        else {
            return []
        }

        let leadingOffset = weekdayOffset(for: monthInterval.start)
        let leadingDays = (0..<leadingOffset).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - leadingOffset, to: monthInterval.start)
        }
        let currentDays = monthRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        let totalCells = Int(ceil(Double(leadingDays.count + currentDays.count) / 7.0)) * 7
        let trailingCount = max(0, totalCells - leadingDays.count - currentDays.count)
        let trailingDays = (0..<trailingCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monthInterval.end)
        }

        return leadingDays + currentDays + trailingDays
    }

    private func dateTimeButton(_ title: String) -> some View {
        Button {
            isPickerPresented = true
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 12)
                .frame(minHeight: 28)
                .background(.quaternary.opacity(0.8), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func changeMonth(by value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }

    private func weekdayOffset(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selection)
    }

    @ViewBuilder
    private func dayBackground(for date: Date) -> some View {
        if isSelected(date) {
            Circle().fill(.blue)
        } else if calendar.isDateInToday(date) {
            Circle().fill(.blue.opacity(0.12))
        }
    }

    private func dayForeground(for date: Date) -> Color {
        guard calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month) else {
            return .secondary.opacity(0.45)
        }

        if isSelected(date) {
            return .white
        }

        if calendar.isDateInToday(date) {
            return .blue
        }

        return .primary
    }
}

private struct TimeEntryControl: View {
    @Binding var selection: Date
    @State private var hourText = ""
    @State private var minuteText = ""
    @State private var period: TimePeriod = .am
    @State private var prefersExplicit24HourInput = false
    @FocusState private var focusedField: TimeField?
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter time")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    timeField(text: $hourText, field: .hour)
                    Text("Hour")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Text(":")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 10, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    timeField(text: $minuteText, field: .minute)
                    Text("Minute")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                if !uses24HourClock {
                    VStack(spacing: 0) {
                        periodButton("AM", period: .am)
                        periodButton("PM", period: .pm)
                    }
                    .opacity(isUsingExplicit24HourInput ? 0.45 : 1)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    }
                }
            }
        }
        .onAppear {
            syncFromSelection()
        }
        .onChange(of: selection) { _, _ in
            syncFromSelection()
        }
    }

    private func timeField(text: Binding<String>, field: TimeField) -> some View {
        TextField("", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 28, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .frame(width: 72, height: 42)
            .background(fieldBackground(isFocused: focusedField == field))
            .focused($focusedField, equals: field)
            .onChange(of: text.wrappedValue) { _, newValue in
                let filtered = normalizedTimeInput(newValue)
                if filtered != newValue {
                    text.wrappedValue = filtered
                    return
                }
                if field == .hour {
                    updateExplicit24HourPreference(from: filtered)
                }
                applyTime()
            }
    }

    private func normalizedTimeInput(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard digits.count > 2 else {
            return String(digits)
        }

        let withoutLeadingZeros = digits.drop { $0 == "0" }
        let significantDigits = withoutLeadingZeros.isEmpty ? digits.suffix(1) : withoutLeadingZeros
        return String(significantDigits.prefix(2))
    }

    private func periodButton(_ title: String, period targetPeriod: TimePeriod) -> some View {
        Button {
            guard !isUsingExplicit24HourInput else {
                return
            }

            period = targetPeriod
            applyTime()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 44, height: 21)
                .foregroundStyle(period == targetPeriod ? .white : .primary)
                .background(period == targetPeriod ? Color.accentColor : Color.secondary.opacity(0.08))
        }
        .buttonStyle(.plain)
        .disabled(isUsingExplicit24HourInput)
    }

    private func fieldBackground(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isFocused ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
            }
    }

    private var uses24HourClock: Bool {
        let format = DateFormatter.dateFormat(
            fromTemplate: "j",
            options: 0,
            locale: .autoupdatingCurrent
        ) ?? ""
        return !format.contains("a")
    }

    private var isUsingExplicit24HourInput: Bool {
        guard !uses24HourClock else {
            return false
        }

        return prefersExplicit24HourInput
    }

    private func syncFromSelection() {
        let hour24 = calendar.component(.hour, from: selection)
        let minute = calendar.component(.minute, from: selection)
        let displayHour = uses24HourClock || isUsingExplicit24HourInput ? hour24 : (hour24 % 12 == 0 ? 12 : hour24 % 12)
        let nextHourText = String(format: "%02d", displayHour)
        let nextMinuteText = String(format: "%02d", minute)
        let nextPeriod: TimePeriod = hour24 < 12 ? .am : .pm

        if hourText != nextHourText {
            hourText = nextHourText
        }
        if minuteText != nextMinuteText {
            minuteText = nextMinuteText
        }
        if period != nextPeriod {
            period = nextPeriod
        }
    }

    private func updateExplicit24HourPreference(from hourText: String) {
        guard !uses24HourClock, let hourValue = Int(hourText) else {
            prefersExplicit24HourInput = false
            return
        }

        prefersExplicit24HourInput = hourValue > 12
    }

    private func applyTime() {
        guard
            let hourValue = Int(hourText),
            let minuteValue = Int(minuteText)
        else {
            return
        }

        let clampedHour = min(max(hourValue, 1), 12)
        let clampedMinute = min(max(minuteValue, 0), 59)
        let hour24: Int
        if uses24HourClock || hourValue > 12 {
            hour24 = min(max(hourValue, 0), 23)
            period = hour24 < 12 ? .am : .pm
        } else {
            switch period {
            case .am:
                hour24 = clampedHour == 12 ? 0 : clampedHour
            case .pm:
                hour24 = clampedHour == 12 ? 12 : clampedHour + 12
            }
        }

        selection = calendar.date(
            bySettingHour: hour24,
            minute: clampedMinute,
            second: 0,
            of: selection
        ) ?? selection
    }
}

private enum TimeField: Hashable {
    case hour
    case minute
}

private enum TimePeriod {
    case am
    case pm
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}

private struct RecordRow: View {
    let record: Record
    let localizer: Localizer
    let now: Date
    let complete: () -> Void
    let delete: () -> Void
    @State private var isHovered = false
    @State private var isDeleteHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            if record.kind.isActionable {
                Button(action: complete) {
                    Image(systemName: record.status == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(isOverdue ? .red : .primary)
                .help(completeHelpText)
                .disabled(record.status == .completed)
            } else {
                Image(systemName: "note.text")
                    .font(.system(size: 12))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.system(size: 12))
                    .strikethrough(record.status == .completed)
                    .foregroundStyle(titleForegroundStyle)
                    .lineLimit(2)

                if record.status == .completed {
                    Text(localizer.string(.completedTodo))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else if let displayTime = RecordDisplaySupport.displayTime(for: record) {
                    HStack(spacing: 4) {
                        if isOverdue {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        Text(displayTime.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(isOverdue ? .red : .secondary)
                }
            }

            Spacer(minLength: 0)

            Button(action: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(deleteButtonForegroundColor)
            .help(localizer.string(.deleteRecordButton))
            .onHover { hovering in
                isDeleteHovered = hovering
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 0)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackgroundColor)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var completeHelpText: String {
        if record.status == .completed {
            return localizer.string(.completedTodo)
        }

        return localizer.string(record.kind == .reminder ? .completeReminder : .completeTodo)
    }

    private var isOverdue: Bool {
        RecordDisplaySupport.isOverdue(record, now: now)
    }

    private var titleForegroundStyle: AnyShapeStyle {
        if record.status == .completed {
            return AnyShapeStyle(.secondary)
        }

        return isOverdue ? AnyShapeStyle(.red) : AnyShapeStyle(.primary)
    }

    private var rowBackgroundColor: Color {
        if isOverdue {
            return Color.red.opacity(isHovered ? 0.16 : 0.11)
        }

        return isHovered ? Color.secondary.opacity(0.10) : Color.clear
    }

    private var deleteButtonForegroundColor: Color {
        if isDeleteHovered {
            return .red
        }

        return isOverdue ? .red : .secondary
    }
}

private enum RecordDisplayMode: Hashable {
    case active
    case history
}

private enum RecordKindFilter: CaseIterable, Hashable {
    case all
    case todo
    case note
    case reminder

    func includes(_ kind: RecordKind) -> Bool {
        switch self {
        case .all:
            return true
        case .todo:
            return kind == .todo
        case .note:
            return kind == .note
        case .reminder:
            return kind == .reminder
        }
    }

    func title(localizer: Localizer) -> String {
        switch self {
        case .all:
            return localizer.string(.allRecordKinds)
        case .todo:
            return localizer.string(.todoKind)
        case .note:
            return localizer.string(.noteKind)
        case .reminder:
            return localizer.string(.reminderKind)
        }
    }

    var iconName: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .todo, .note, .reminder:
            return "line.3.horizontal.decrease.circle.fill"
        }
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
