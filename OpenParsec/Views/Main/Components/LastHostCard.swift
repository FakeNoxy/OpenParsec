import SwiftUI

/// The "Last connected" card in the Hosts page, extracted verbatim from `MainView`.
struct LastHostCard: View {
	let hostname: String
	let onReconnect: () -> Void
	let onClear: () -> Void

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				VStack(alignment: .leading, spacing: 4) {
					Text("Last connected")
						.font(.system(size: 12))
						.opacity(0.5)
					Text(hostname)
						.font(.system(size: 16, weight: .medium))
				}
				Spacer()
				Button(action: onReconnect) {
					Text("Reconnect")
						.lineLimit(1)
						.fixedSize()
						.foregroundColor(.white)
						.padding(.horizontal, 16)
						.frame(minHeight: 44)
						.background(Color("AccentColor"))
						.cornerRadius(8)
				}
				Button(action: onClear) {
					Image(systemName: "xmark")
						.foregroundColor(Color("Foreground"))
						.opacity(0.5)
						.frame(width: 44, height: 44)
						.contentShape(Rectangle())
				}
			}
			.padding()
			HStack {
				Toggle("Reconnect on app launch", isOn: Binding(
					get: { SettingsStore.shared.autoConnectOnLaunch },
					set: { SettingsStore.shared.autoConnectOnLaunch = $0 }
				))
				.font(.system(size: 13))
				.opacity(0.7)
			}
			.padding(.horizontal)
			.padding(.bottom, 10)
		}
		.frame(maxWidth: 400)
		.background(Rectangle().fill(Color("BackgroundCard")))
		.cornerRadius(8)
	}
}
