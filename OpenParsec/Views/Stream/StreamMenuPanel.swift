import SwiftUI
import ParsecSDK

/// The stream menu panel, extracted verbatim from `ParsecView.menuPanel`.
/// `ParsecView` now returns this view; all state and actions are passed in
/// so the panel stays a pure presentation component.
struct StreamMenuPanel: View {
	@Binding var menuRowsHeight: CGFloat
	let menuWidth: CGFloat
	let muted: Bool
	let zoomEnabled: Bool
	let resolutions: [ParsecResolution]
	let bitrates: [Int]
	let currentResolutionX: Int
	let currentResolutionY: Int
	let currentBitrate: Int
	let displayConfigs: [ParsecDisplayConfig]
	let constantFps: Bool
	let cursorMode: CursorMode

	let onDisableOverlay: () -> Void
	let onToggleMute: () -> Void
	let onChangeResolution: (ParsecResolution) -> Void
	let onChangeBitRate: (Int) -> Void
	let onChangeDisplay: (String) -> Void
	let onToggleConstantFps: () -> Void
	let onToggleZoom: () -> Void
	let onToggleTouchMode: () -> Void
	let onOpenSettings: () -> Void
	let onDisconnect: () -> Void

	var body: some View {
		VStack(spacing: 3) {
			ScrollView {
				VStack(spacing: 3) {
					Button(action: onDisableOverlay) {
						Text("Hide Buttons")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Button(action: onToggleMute) {
						Text("Sound: \(muted ? "OFF" : "ON")")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Menu {
						ForEach(resolutions, id: \.self) { resolution in
							Button(action: {
								onChangeResolution(resolution)
							}) {
								if resolution.width == currentResolutionX && resolution.height == currentResolutionY {
									Label(resolution.desc, systemImage: "checkmark")
								} else {
									Text(resolution.desc)
								}
							}
						}
					} label: {
						Text("Resolution")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Menu {
						Button(action: {
							onChangeBitRate(0)
						}) {
							if currentBitrate == 0 {
								Label("Host Default", systemImage: "checkmark")
							} else {
								Text("Host Default")
							}
						}
						ForEach(bitrates, id: \.self) { bitrate in
							Button(action: {
								onChangeBitRate(bitrate)
							}) {
								if bitrate == currentBitrate {
									Label("\(bitrate) Mbps", systemImage: "checkmark")
								} else {
									Text("\(bitrate) Mbps")
								}
							}
						}
					} label: {
						Text("Bitrate")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					if displayConfigs.count > 1 {
						Menu {
							Button("Auto") {
								onChangeDisplay("none")
							}
							ForEach(displayConfigs, id: \.self) { config in
								Button("\(config.name) \(config.adapterName)") {
									onChangeDisplay(config.id)
								}
							}
						} label: {
							Text("Switch Display")
								.padding(8)
								.frame(maxWidth: .infinity)
								.multilineTextAlignment(.center)
						}
					}

					Button(action: onToggleConstantFps) {
						Text("Constant Frame Rate: \(constantFps ? "ON" : "OFF")")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Button(action: onToggleZoom) {
						Text("Pinch to Zoom: \(zoomEnabled ? "ON" : "OFF")")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Button(action: onToggleTouchMode) {
						Text("Touch Mode: \(cursorMode == .direct ? "Direct" : "Touchpad")")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Button(action: onOpenSettings) {
						Text("Settings")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
				}
				.background(GeometryReader { proxy in
					Color.clear.preference(key: MenuRowsHeightKey.self, value: proxy.size.height)
				})
			}
			.frame(maxHeight: menuRowsHeight)
			.onPreferenceChange(MenuRowsHeightKey.self) { menuRowsHeight = $0 }
			Rectangle()
				.fill(Color("Foreground"))
				.opacity(0.25)
				.frame(height: 1)
			Button(action: { onDisconnect() }) {
				Text("Disconnect")
					.foregroundColor(.red)
					.padding(8)
					.frame(maxWidth: .infinity)
					.multilineTextAlignment(.center)
			}
		}
		.background(Rectangle().fill(Color("BackgroundPrompt").opacity(0.75)))
		.foregroundColor(Color("Foreground"))
		.frame(maxWidth: menuWidth)
		.cornerRadius(8)
		.padding(.horizontal)
	}
}
