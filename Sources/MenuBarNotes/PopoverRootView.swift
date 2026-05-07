import MenuBarNotesCore
import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var recordListStore: RecordListStore
    @State private var draftTitle = ""
    @State private var draftKind: RecordKind = .todo
    @State private var addError: String?

    let localizer: Localizer
    let showSettings: () -> Void
    let showAppInfo: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header

                    ForEach(settingsStore.settings.cardOrder) { card in
                        if card == .notes {
                            NotesTodosCard(
                                recordListStore: recordListStore,
                                localizer: localizer,
                                draftTitle: $draftTitle,
                                draftKind: $draftKind,
                                addError: $addError
                            )
                        } else {
                            PlaceholderCard(card: card, localizer: localizer)
                        }
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 420)

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

            Text(progress)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }
}

private struct NotesTodosCard: View {
    @ObservedObject var recordListStore: RecordListStore
    let localizer: Localizer
    @Binding var draftTitle: String
    @Binding var draftKind: RecordKind
    @Binding var addError: String?

    private var displayedRecords: [Record] {
        recordListStore.records.filter { $0.kind == .note || $0.kind == .todo }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.string(.notesCardTitle))
                .font(.system(size: 12, weight: .semibold))

            if recordListStore.lastErrorDescription != nil {
                Text(localizer.string(.recordAddError))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else if displayedRecords.isEmpty {
                Text(emptyText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 6) {
                    ForEach(displayedRecords) { record in
                        RecordRow(record: record, localizer: localizer) {
                            try? recordListStore.completeTodo(id: record.id)
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Picker("", selection: $draftKind) {
                    Text(localizer.string(.addTodoButton)).tag(RecordKind.todo)
                    Text(localizer.string(.addNoteButton)).tag(RecordKind.note)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)

                HStack(spacing: 6) {
                    TextField(localizer.string(.addRecordPlaceholder), text: $draftTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onSubmit(addRecord)

                    Button(action: addRecord) {
                        Image(systemName: "plus")
                    }
                    .help(localizer.string(draftKind == .todo ? .addTodoButton : .addNoteButton))
                    .disabled(trimmedTitle.isEmpty || recordListStore.lastErrorDescription != nil)
                }
                .controlSize(.small)

                if let addError {
                    Text(addError)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyText: String {
        recordListStore.hasStorageDirectory
            ? localizer.string(.notesPlaceholder)
            : localizer.string(.noStorageLocation)
    }

    private var trimmedTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addRecord() {
        guard !trimmedTitle.isEmpty else {
            return
        }

        do {
            switch draftKind {
            case .note:
                try recordListStore.addNote(title: trimmedTitle)
            case .todo:
                try recordListStore.addTodo(title: trimmedTitle)
            case .reminder:
                return
            }
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
            if record.kind == .todo {
                Button(action: complete) {
                    Image(systemName: record.status == .completed ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.borderless)
                .help(localizer.string(record.status == .completed ? .completedTodo : .completeTodo))
                .disabled(record.status == .completed)
            } else {
                Image(systemName: "note.text")
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
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct PlaceholderCard: View {
    let card: MenuCard
    let localizer: Localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizer.string(card.titleKey))
                .font(.system(size: 12, weight: .semibold))

            Text(localizer.string(card.placeholderKey))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}
