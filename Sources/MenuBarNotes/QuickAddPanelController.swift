import AppKit
import MenuBarNotesCore
import SwiftUI

@MainActor
final class QuickAddPanelController: NSWindowController {
    init(captureService: QuickAddCaptureService, localizer: Localizer) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 190),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = localizer.string(.quickAddTitle)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.center()

        super.init(window: panel)

        panel.contentViewController = NSHostingController(
            rootView: QuickAddPanelView(
                captureService: captureService,
                localizer: localizer,
                close: { [weak self] in self?.close() }
            )
        )
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func showPanel() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct QuickAddPanelView: View {
    let captureService: QuickAddCaptureService
    let localizer: Localizer
    let close: () -> Void

    @State private var draftTitle = ""
    @State private var draftKind: RecordKind = .todo
    @State private var draftReminderAt = Date().addingTimeInterval(3_600)
    @State private var errorText: String?
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                .font(.system(size: 12))
                .controlSize(.small)
            }

            TextField(localizer.string(.addRecordPlaceholder), text: $draftTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .focused($isTitleFocused)
                .onSubmit(capture)

            if let errorText {
                Text(errorText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(localizer.string(.quickAddCancelButton), action: close)
                    .keyboardShortcut(.cancelAction)
                Button(localizer.string(.quickAddSubmitButton), action: capture)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedTitle.isEmpty)
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 360)
        .onAppear {
            isTitleFocused = true
        }
    }

    private var trimmedTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func capture() {
        guard !trimmedTitle.isEmpty else {
            return
        }

        let reminderAt = draftKind == .reminder ? draftReminderAt : nil
        do {
            try captureService.capture(
                QuickAddCaptureRequest(
                    source: .globalHotkey,
                    draft: RecordDraft(
                        kind: draftKind,
                        title: trimmedTitle,
                        dueAt: reminderAt,
                        reminderAt: reminderAt
                    )
                )
            )
            draftTitle = ""
            errorText = nil
            close()
        } catch RecordListStoreError.missingStorageDirectory {
            errorText = localizer.string(.noStorageLocation)
        } catch {
            errorText = localizer.string(.recordAddError)
        }
    }
}
