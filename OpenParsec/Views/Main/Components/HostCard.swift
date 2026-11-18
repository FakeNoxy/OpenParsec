import SwiftUI

/// A single host row in the Hosts page, extracted verbatim from `MainView`.
struct HostCard: View {
	let host: IdentifiableHostInfo
	let onConnect: () -> Void

	var body: some View {
		ZStack {
			VStack {
				URLImage(url: URL(string: "https://parsecusercontent.com/cors-resize-image/w=64,h=64,fit=crop,background=white,q=90,f=jpeg/avatars/\(String(host.user.id))/avatar"),
						output:
						{
							$0
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(width: 64, height: 64)
								.cornerRadius(8)
						},
						placeholder:
						{
							Image("IconTransparent")
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(width: 64, height: 64)
								.background(Rectangle().fill(Color("BackgroundPrompt")))
								.cornerRadius(8)
						})
				Text(host.hostname)
					.font(.system(size: 20, weight: .medium))
					.multilineTextAlignment(.center)
				Text("\(host.user.name)#\(String(host.user.id))")
					.font(.system(size: 16, weight: .medium))
					.multilineTextAlignment(.center)
					.opacity(0.5)
				Button(action: onConnect) {
					Text("Connect")
						.lineLimit(1)
						.fixedSize()
						.foregroundColor(.white)
						.padding(.horizontal, 28)
						.frame(minHeight: 44)
						.background(Color("AccentColor"))
						.cornerRadius(8)
				}
			}

			if host.connections > 0 {
				VStack {
					HStack {
						Image(systemName: "person.fill")
						Text(String(host.connections))
							.font(.system(size: 16, weight: .medium))
						Spacer()
					}
					Spacer()
				}
			}
		}
		.padding()
		.frame(maxWidth: 400)
		.background(Rectangle().fill(Color("BackgroundCard")))
		.cornerRadius(8)
		.contextMenu {
			Button(action: { UIPasteboard.general.string = host.hostname }) {
				Label("Copy Name", systemImage: "doc.on.doc")
			}
		}
	}
}
