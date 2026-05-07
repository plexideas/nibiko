import MenuBarNotesCore
import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var settingsStore: AppSettingsStore

    let localizer: Localizer
    let showSettings: () -> Void
    let showAppInfo: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header

                    ForEach(settingsStore.settings.cardOrder) { card in
                        PlaceholderCard(card: card, localizer: localizer)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(localizer.string(.popoverTitle))
                .font(.system(size: 17, weight: .semibold))

            Text(localizer.string(.popoverSubtitle))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(localizer.string(.progressSummary))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
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
