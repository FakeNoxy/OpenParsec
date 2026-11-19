import SwiftUI

/// A single host card in the Hosts page.
struct HostCard: View {
	let host: IdentifiableHostInfo
	let onConnect: () -> Void

	var body: some View {
		VStack(spacing: AppSpacing.regular) {
			URLImage(url: URL(string: "https://parsecusercontent.com/cors-resize-image/w=64,h=64,fit=crop,background=white,q=90,f=jpeg/avatars/\(String(host.user.id))/avatar"),
					output:
					{
						$0
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 64, height: 64)
							.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
					},
					placeholder:
					{
						Image("IconTransparent")
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 64, height: 64)
							.background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color("BackgroundPrompt")))
					})

			VStack(spacing: 2) {
				Text(host.hostname)
					.font(.title3.weight(.medium))
					.multilineTextAlignment(.center)
					.lineLimit(2)
				Text("\(host.user.name)#\(String(host.user.id))")
					.font(.subheadline)
					.multilineTextAlignment(.center)
					.opacity(0.5)
			}

			Button(action: onConnect) {
				Text("Connect")
			}
			.buttonStyle(PrimaryButtonStyle(fullWidth: true))
		}
		.padding(AppSpacing.regular)
		.overlay(alignment: .topTrailing) {
			if host.connections > 0 {
				HStack(spacing: 4) {
					Image(systemName: "person.fill")
						.font(.caption)
					Text(String(host.connections))
						.font(.caption.weight(.medium))
				}
				.padding(.horizontal, 10)
				.padding(.vertical, 6)
				.background(Capsule().fill(Color.white.opacity(0.12)))
				.padding(10)
				.foregroundColor(Color("Foreground"))
			}
		}
		.glassCard(fallbackFill: Color("BackgroundCard"))
		.contextMenu {
			Button(action: { UIPasteboard.general.string = host.hostname }) {
				Label("Copy Name", systemImage: "doc.on.doc")
			}
		}
	}
}
