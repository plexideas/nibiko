import AppKit
import MenuBarNotesCore
import SwiftUI

@MainActor
final class AppInfoWindowController: NSWindowController {
    init(appInfo: AppInfo, localizer: Localizer) {
        let contentView = AppInfoView(appInfo: appInfo, localizer: localizer)
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = localizer.string(.appInfoTitle)
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 360, height: 220))
        window.center()

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

struct AppInfoView: View {
    let appInfo: AppInfo
    let localizer: Localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "note.text")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appInfo.name)
                        .font(.system(size: 18, weight: .semibold))
                    Text(localizer.string(.appInfoTitle))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            LabeledContent(localizer.string(.versionLabel), value: appInfo.version)
                .font(.system(size: 12))
            LabeledContent(localizer.string(.buildLabel), value: appInfo.build)
                .font(.system(size: 12))
            LabeledContent(localizer.string(.acknowledgementsLabel)) {
                Text(appInfo.acknowledgements)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 360, height: 220)
    }
}
