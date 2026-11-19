import SwiftUI

/// A single friend row in the Friends page.
struct FriendRow: View {
	let friend: IdentifiableUserInfo

	var body: some View {
		HStack(spacing: AppSpacing.regular) {
			URLImage(url: URL(string: "https://parsecusercontent.com/cors-resize-image/w=48,h=48,fit=crop,background=white,q=90,f=jpeg/avatars/\(String(friend.id))/avatar"),
				output:
				{
					$0
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 44, height: 44)
						.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
				},
				placeholder:
				{
					Image("IconTransparent")
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 44, height: 44)
						.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color("BackgroundPrompt")))
				})
			Text("\(friend.username)#\(String(friend.id))")
				.font(.body.weight(.medium))
				.multilineTextAlignment(.leading)
			Spacer()
		}
		.padding(AppSpacing.regular)
		.glassCard(cornerRadius: 14, fallbackFill: Color("BackgroundCard"))
	}
}
