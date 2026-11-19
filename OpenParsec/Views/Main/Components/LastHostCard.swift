import SwiftUI

/// The "Last connected" hero card at the top of the Hosts page.
struct LastHostCard: View {
	let hostname: String
	let onReconnect: () -> Void
	let onClear: () -> Void

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: AppSpacing.regular) {
				VStack(alignment: .leading, spacing: 4) {
					Label("Last connected", systemImage: "clock.arrow.circlepath")
						.font(.footnote)
						.opacity(0.6)
					Text(hostname)
						.font(.title3.weight(.semibold))
						.lineLimit(1)
				}
				Spacer()
				Button(action: onClear) {
					Image(systemName: "xmark")
						.foregroundColor(Color("Foreground"))
						.opacity(0.5)
						.frame(width: 44, height: 44)
						.contentShape(Rectangle())
				}
			}
			.padding(AppSpacing.regular)

			Button(action: onReconnect) {
				Text("Reconnect")
			}
			.buttonStyle(PrimaryButtonStyle(fullWidth: true))
			.padding([.horizontal, .bottom], AppSpacing.regular)
			.padding(.top, AppSpacing.tight)

			HStack {
				Toggle("Reconnect on app launch", isOn: Binding(
					get: { SettingsStore.shared.autoConnectOnLaunch },
					set: { SettingsStore.shared.autoConnectOnLaunch = $0 }
				))
				.font(.footnote)
				.opacity(0.7)
			}
			.padding(.horizontal, AppSpacing.regular)
			.padding(.bottom, AppSpacing.regular)
		}
		.glassCard(fallbackFill: Color("BackgroundCard"))
	}
}
