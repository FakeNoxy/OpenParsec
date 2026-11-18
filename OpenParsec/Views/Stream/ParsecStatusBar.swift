import SwiftUI
import ParsecSDK
import Foundation
import AVFoundation
import Combine

struct ParsecStatusBar: View {
	@Binding var showMenu: Bool
	@ObservedObject var controller: ReconnectController
	let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

	init(showMenu: Binding<Bool>, controller: ReconnectController) {
		_showMenu = showMenu
		self.controller = controller
	}

	var body: some View {
		// Overlay elements
		if showMenu || SettingsStore.shared.alwaysShowStatus {
			VStack {
				Text(controller.metricInfo)
					.frame(minWidth: 200, maxWidth: .infinity, maxHeight: 20)
					.multilineTextAlignment(.leading)
					.font(.system(size: 10))
					.lineSpacing(20)
					.lineLimit(nil)
			}
			.background(Rectangle().fill(Color("BackgroundPrompt").opacity(0.75)))
			.foregroundColor(Color("Foreground"))
			.frame(maxHeight: .infinity, alignment: .top)
			.zIndex(1)
			.edgesIgnoringSafeArea(.all)

		}
		EmptyView()
			.onReceive(timer) { _ in
				controller.poll(showMenu: showMenu)
			}
	}
}
