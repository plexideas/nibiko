import AppKit
import NibikoCore
import SwiftUI

@MainActor
final class QuickAddPanelController: NSWindowController {
    init(settingsStore: AppSettingsStore, captureService: QuickAddCaptureService, localizer: Localizer) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 172),
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
                settingsStore: settingsStore,
                captureService: captureService,
                localizer: localizer,
                close: { [weak self] in self?.close() },
                requestContentResize: { [weak self] in self?.resizeToContent() }
            )
        )
        shouldCascadeWindows = false
        applyAppearance(settingsStore.settings.appearanceMode)
        resizeToContent()
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

    func applyAppearance(_ mode: AppearanceMode) {
        applyWindowAppearance(mode, to: window)
    }

    private func resizeToContent() {
        guard let window, let contentView = window.contentViewController?.view else {
            return
        }

        Task { @MainActor in
            await Task.yield()
            let fittingSize = contentView.fittingSize
            let contentSize = NSSize(width: 340, height: max(172, fittingSize.height))
            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
            frame.origin.x = window.frame.midX - frame.width / 2
            frame.origin.y = window.frame.maxY - frame.height
            window.setFrame(frame, display: true, animate: false)
        }
    }
}

private struct QuickAddPanelView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    let captureService: QuickAddCaptureService
    let localizer: Localizer
    let close: () -> Void
    let requestContentResize: () -> Void

    @State private var draftTitle = ""
    @State private var draftKind: RecordKind = .todo
    @State private var draftReminderAt = Date().addingTimeInterval(3_600)
    @State private var errorText: String?
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(localizer.string(.addRecordPlaceholder), text: $draftTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .focused($isTitleFocused)
                .onSubmit(capture)
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

                Button(action: capture) {
                    Text(addButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .frame(width: 104)
                .help(addButtonTitle)
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedTitle.isEmpty)
            }
            .controlSize(.small)

            if let errorText {
                Text(errorText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .frame(width: 340)
        .animation(.easeInOut(duration: 0.16), value: isReminderDraft)
        .animation(.easeInOut(duration: 0.16), value: errorText)
        .onAppear {
            isTitleFocused = true
            requestContentResize()
        }
        .onChange(of: draftKind) { _, _ in
            requestContentResize()
        }
        .onChange(of: errorText) { _, _ in
            requestContentResize()
        }
        .preferredColorScheme(settingsStore.settings.appearanceMode.colorScheme)
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
