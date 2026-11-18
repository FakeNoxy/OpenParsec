import SwiftUI

/// A single friend row in the Friends page, extracted verbatim from `MainView`.
struct FriendRow: View {
	let friend: IdentifiableUserInfo

	var body: some View {
		HStack {
			URLImage(url: URL(string: "https://parsecusercontent.com/cors-resize-image/w=48,h=48,fit=crop,background=white,q=90,f=jpeg/avatars/\(String(friend.id))/avatar"),
				output:
				{
					$0
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 48, height: 48)
						.cornerRadius(6)
				},
				placeholder:
				{
					Image("IconTransparent")
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 48, height: 48)
						.background(Rectangle().fill(Color("BackgroundPrompt")))
						.cornerRadius(6)
				})
			Text("\(friend.username)#\(String(friend.id))")
				.font(.system(size: 16, weight: .medium))
				.multilineTextAlignment(.center)
			Spacer()
 //			Button(action:{ }, label:{ Image(systemName:"ellipsis.circle.fill") })
 //				.font(.system(size:20))
 //				.foregroundColor(Color("AccentColor"))
 //				.padding(8)
		}
		.padding(8)
		.background(Color("BackgroundCard"))
		.cornerRadius(12)
	}
}
