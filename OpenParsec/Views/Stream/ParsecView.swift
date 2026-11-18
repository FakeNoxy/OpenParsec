import SwiftUI
import ParsecSDK
import Foundation
import AVFoundation


struct ParsecView: View {
	var controller: ContentView?

	@State var showDCAlert: Bool = false
	@State var DCAlertText: String = "Disconnected (reason unknown)"
	@State var metricInfo: String = "Loading..."

	@State var hideOverlay: Bool = false
	@State var hideKeyboardButton: Bool = false
	@AppStorage("keyboardHintShown") var keyboardHintShown: Bool = false
	@AppStorage("keyboardPanHintShown") var keyboardPanHintShown: Bool = false
	@State var hint: String?
	@State var showMenu: Bool = false
	@State var menuRowsHeight: CGFloat = 0
	@ScaledMetric var menuWidth: CGFloat = 230
	@AppStorage("menuSwipeHintShown") var menuSwipeHintShown: Bool = false

	@State var showKeyboard: Bool = false
	@State var zoomEnabled: Bool = false
	@Environment(\.verticalSizeClass) var verticalSizeClass

	@State var muted: Bool = false
	@State var preferH265: Bool = true
	@State var isReconnecting: Bool = false
	@State var connectionLost: Bool = false
	@State var showSettings: Bool = false
	@State var decoderAtOpen: DecoderPref = .h264
	@State var fpsAtOpen: Int = 0
	@State var pipAtOpen: Bool = false
	@State var resolutionAtOpen: ParsecResolution = .client
	@State var bitrateAtOpen: Int = 0
	@State var waitingForNetwork: Bool = false
	@State var waitingForStream: Bool = false

	@State var resolutions: [ParsecResolution]
	@State var bitrates: [Int]

    // Persist the VC across view updates using StateObject.
    // CRITICAL: Changing this to @State or a simple var will break the keyboard after menu interactions.
	@StateObject var session = ParsecSession()

    // Observer shared state for updates
    @ObservedObject var dataModel = DataManager.model
	@ObservedObject var settingsStore = SettingsStore.shared

    // Computed property for convenience refactoring
    var parsecViewController: ParsecViewController {
        return session.controller
    }

	// @State var showDisplays: Bool = false

	init(_ controller: ContentView?) {
		self.controller = controller

		_muted = State(initialValue: SettingsHandler.startMuted)
		_zoomEnabled = State(initialValue: SettingsHandler.zoomEnabled)
		_resolutions = State(initialValue: ParsecResolution.resolutions)
		_bitrates = State(initialValue: ParsecResolution.bitrates)

    }

    // We need to set up the callback somewhere safer than init.
    // 'onAppear' is a good place, or inside the init of ParsecSession if possible (but it doesn't have access to binding).
    // Let's use onAppear/post.

	var body: some View {
		ZStack {

			UIViewControllerWrapper(self.parsecViewController)
				.zIndex(1)
				.prefersPersistentSystemOverlaysHidden()

			ParsecStatusBar(showMenu: $showMenu, showDCAlert: $showDCAlert, DCAlertText: $DCAlertText, parsecViewController: parsecViewController, isReconnecting: $isReconnecting, connectionLost: $connectionLost, waitingForNetwork: $waitingForNetwork, waitingForStream: $waitingForStream, onSilentDisconnect: { disconnect() })

			if isReconnecting || connectionLost || waitingForNetwork {
				VStack(spacing: 12) {
					if waitingForNetwork {
						Image(systemName: "wifi.slash")
							.font(.system(size: 34, weight: .medium))
							.foregroundColor(.white)
					} else {
						ActivityIndicator(isAnimating: .constant(true), style: .large, tint: .white)
					}
					Text(overlayTitle)
						.font(.system(size: 16, weight: .medium))
						.foregroundColor(.white)
						.id(waitingForStream)
						.transition(.opacity)
					if waitingForNetwork {
						Text("OpenParsec will reconnect when you're back online")
							.font(.system(size: 13))
							.foregroundColor(.white)
							.opacity(0.7)
					}
					Button(action: { disconnect() }) {
						Text("Close")
							.font(.system(size: 15, weight: .semibold))
							.foregroundColor(.white)
							.padding(.horizontal, 20)
							.frame(minHeight: 44)
							.background(Color.white.opacity(0.2))
							.cornerRadius(8)
					}
					.padding(.top, 4)
					if settingsStore.showConnectionLog {
						ConnectionLogPanel()
					}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Color.black.opacity(0.6))
				.transition(.asymmetric(insertion: .identity, removal: .opacity))
				.zIndex(10)
			}

			if dataModel.isBlocked {
				Text("Host is using the machine")
					.foregroundColor(.white)
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.background(Color("BackgroundPrompt").opacity(0.85))
					.cornerRadius(8)
					.zIndex(3)
			}

			if let hint = hint {
				Text(hint)
					.multilineTextAlignment(.center)
					.foregroundColor(.white)
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.background(Color("BackgroundPrompt").opacity(0.85))
					.cornerRadius(8)
					.padding(.top, showKeyboard ? 100 : 0)
					.frame(maxHeight: .infinity, alignment: showKeyboard ? .top : .center)
					.allowsHitTesting(false)
					.zIndex(3)
			}

			HStack(alignment: .top, spacing: 0) {
				VStack {
					if !hideOverlay {
						HStack {
							Button(action: {
								if showMenu {
									showMenu = false
								} else {
									showMenu = true
									ParsecView.getHostUserData()
								}
							}) {
								Image("IconTransparent")
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(width: 48, height: 48)
									.background(Rectangle().fill(Color("BackgroundPrompt").opacity(showMenu ? 0.75 : 1)))
									.cornerRadius(8)
									.opacity(showMenu ? 1 : 0.25)
							}
							.padding()
							.edgesIgnoringSafeArea(.all)
							Spacer()
						}
					}
					if !hideKeyboardButton {
						HStack {
							Button(action: toggleKeyboard) {
								Image(systemName: "keyboard")
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(width: 32, height: 32)
									.foregroundColor(Color("Foreground"))
									.padding(8)
									.background(Rectangle().fill(Color("BackgroundPrompt").opacity(showKeyboard ? 0.75 : 0.5)))
									.cornerRadius(8)
							}
							.padding(.leading)
							.edgesIgnoringSafeArea(.all)
							Spacer()
						}
					}
					if showMenu && verticalSizeClass != .compact {
						HStack {
							menuPanel
							Spacer()
						}
						.layoutPriority(1)
					}
					Spacer()
				}
				.fixedSize(horizontal: showMenu && verticalSizeClass == .compact, vertical: false)
				if showMenu && verticalSizeClass == .compact {
					menuPanel
						.padding(.top)
					Spacer()
				}
			}
			.zIndex(2)
		}
		.statusBarHidden(SettingsHandler.hideStatusBar)
		.alert(isPresented: $showDCAlert) {
			Alert(title: Text(DCAlertText),
				  primaryButton: .default(Text("Reconnect"), action: {
					guard let peerId = ParsecBackgroundManager.shared.lastPeerId else {
						disconnect()
						return
					}
					if NetworkWatcher.shared.noNetwork {
						DispatchQueue.main.async {
							DCAlertText = "No network connection"
							showDCAlert = true
						}
						return
					}
					showDCAlert = false
					reconnectTo(peerId)
				  }),
				  secondaryButton: .cancel(Text("Close"), action: {disconnect()}))
		}
		.onChange(of: showSettings) { open in
			if !open { applyStreamSettings() }
		}
		.onChange(of: isReconnecting) { reconnecting in
			if !reconnecting {
				CParsec.setMuted(muted)
				if muted { CParsec.pause(video: false, audio: true) }
			}
		}
		.onAppear(perform: post)
		.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ParsecBackgroundDisconnect"))) { _ in
			if #available(iOS 15.0, *) {
				if PictureInPictureManager.shared.isPiPActive {
					return
				}
			}
			disconnect(isBackgroundDisconnect: true)
		}
		.edgesIgnoringSafeArea(.all)
		.overlay(SettingsView(visible: $showSettings))

	}

	var menuPanel: some View {
		VStack(spacing: 3) {
			ScrollView {
				VStack(spacing: 3) {
					Button(action: disableOverlay) {
						Text("Hide Buttons")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Button(action: toggleMute) {
						Text("Sound: \(muted ? "OFF" : "ON")")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Menu {
						ForEach(resolutions, id: \.self) { resolution in
							Button(action: {
								changeResolution(res: resolution)
							}) {
								if resolution.width == dataModel.resolutionX && resolution.height == dataModel.resolutionY {
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
							changeBitRate(bitrate: 0)
						}) {
							if settingsStore.bitrate == 0 {
								Label("Host Default", systemImage: "checkmark")
							} else {
								Text("Host Default")
							}
						}
						ForEach(bitrates, id: \.self) { bitrate in
							Button(action: {
								changeBitRate(bitrate: bitrate)
							}) {
								if bitrate == settingsStore.bitrate {
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
					if DataManager.model.displayConfigs.count > 1 {
						Menu {
							Button("Auto") {
								changeDisplay(displayId: "none")
							}
							ForEach(DataManager.model.displayConfigs, id: \.self) { config in
								Button("\(config.name) \(config.adapterName)") {
									changeDisplay(displayId: config.id)
								}
							}
						} label: {
							Text("Switch Display")
								.padding(8)
								.frame(maxWidth: .infinity)
								.multilineTextAlignment(.center)
						}
					}

					Button(action: toggleConstantFps) {
						Text("Constant Frame Rate: \(dataModel.constantFps ? "ON" : "OFF")")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Button(action: toggleZoom) {
						Text("Pinch to Zoom: \(zoomEnabled ? "ON" : "OFF")")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Button(action: toggleTouchMode) {
						Text("Touch Mode: \(settingsStore.cursorMode == .direct ? "Direct" : "Touchpad")")
							.padding(8)
							.frame(maxWidth: .infinity)
							.multilineTextAlignment(.center)
					}
					Button(action: openSettings) {
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
			Button(action: { disconnect()}) {
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
		// .edgesIgnoringSafeArea(.all)
	}

	var overlayTitle: String {
		if waitingForNetwork {
			return "No network connection"
		}
		if !isReconnecting {
			return "Connection lost..."
		}
		if waitingForStream {
			return "Reconnected, waiting for the stream..."
		}
		return ParsecBackgroundManager.shared.lastHostname.map { "Reconnecting to \($0)..." } ?? "Reconnecting..."
	}

}
