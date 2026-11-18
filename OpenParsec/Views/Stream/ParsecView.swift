import SwiftUI
import ParsecSDK
import Foundation
import AVFoundation


struct ParsecView: View {
	var controller: ContentView?

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
	@State var showSettings: Bool = false
	@State var decoderAtOpen: DecoderPref = .h264
	@State var fpsAtOpen: Int = 0
	@State var pipAtOpen: Bool = false
	@State var resolutionAtOpen: ParsecResolution = .client
	@State var bitrateAtOpen: Int = 0

	@State var resolutions: [ParsecResolution]
	@State var bitrates: [Int]

    // Persist the VC across view updates using StateObject.
    // CRITICAL: Changing this to @State or a simple var will break the keyboard after menu interactions.
	@StateObject var session = ParsecSession()

	// Reconnect/disconnect state machine (previously 7 @State vars + an inline poll()).
	@StateObject var reconnect = ReconnectController()

    // Observer shared state for updates
    @ObservedObject var dataModel = StreamSessionState.shared
	@ObservedObject var settingsStore = SettingsStore.shared

    // Computed property for convenience refactoring
    var parsecViewController: ParsecViewController {
        return session.controller
    }

	init(_ controller: ContentView?) {
		self.controller = controller

		_muted = State(initialValue: SettingsStore.shared.startMuted)
		_zoomEnabled = State(initialValue: SettingsStore.shared.zoomEnabled)
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

			ParsecStatusBar(showMenu: $showMenu, controller: reconnect)

			if reconnect.isReconnecting || reconnect.connectionLost || reconnect.waitingForNetwork {
				VStack(spacing: 12) {
					if reconnect.waitingForNetwork {
						Image(systemName: "wifi.slash")
							.font(.system(size: 34, weight: .medium))
							.foregroundColor(.white)
					} else {
						ActivityIndicator(isAnimating: .constant(true), style: .large, tint: .white)
					}
					Text(overlayTitle)
						.font(.system(size: 16, weight: .medium))
						.foregroundColor(.white)
						.id(reconnect.waitingForStream)
						.transition(.opacity)
					if reconnect.waitingForNetwork {
						Text("OpenParsec will reconnect when you're back online")
							.font(.system(size: 13))
							.foregroundColor(.white)
							.opacity(0.7)
					}
					Button(action: { reconnect.disconnect() }) {
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
		.statusBarHidden(SettingsStore.shared.hideStatusBar)
		.alert(isPresented: $reconnect.showDCAlert) {
			Alert(title: Text(reconnect.DCAlertText),
				  primaryButton: .default(Text("Reconnect"), action: {
					guard let peerId = ParsecBackgroundManager.shared.lastPeerId else {
						reconnect.disconnect()
						return
					}
					if NetworkWatcher.shared.noNetwork {
						DispatchQueue.main.async {
							reconnect.DCAlertText = "No network connection"
							reconnect.showDCAlert = true
						}
						return
					}
					reconnect.showDCAlert = false
					reconnect.reconnectTo(peerId)
				  }),
				  secondaryButton: .cancel(Text("Close"), action: {reconnect.disconnect()}))
		}
		.onChange(of: showSettings) { _, newValue in
			if !newValue { applyStreamSettings() }
		}
		.onChange(of: reconnect.isReconnecting) { _, newValue in
			if !newValue {
				CParsec.setMuted(muted)
				if muted { CParsec.pause(video: false, audio: true) }
			}
		}
		.onAppear(perform: post)
		.edgesIgnoringSafeArea(.all)
		.overlay(SettingsView(visible: $showSettings))

	}

	var menuPanel: some View {
		StreamMenuPanel(
			menuRowsHeight: $menuRowsHeight,
			menuWidth: menuWidth,
			muted: muted,
			zoomEnabled: zoomEnabled,
			resolutions: resolutions,
			bitrates: bitrates,
			currentResolutionX: dataModel.resolutionX,
			currentResolutionY: dataModel.resolutionY,
			currentBitrate: settingsStore.bitrate,
			displayConfigs: dataModel.displayConfigs,
			constantFps: dataModel.constantFps,
			cursorMode: settingsStore.cursorMode,
			onDisableOverlay: { disableOverlay() },
			onToggleMute: { toggleMute() },
			onChangeResolution: { changeResolution(res: $0) },
			onChangeBitRate: { changeBitRate(bitrate: $0) },
			onChangeDisplay: { changeDisplay(displayId: $0) },
			onToggleConstantFps: { toggleConstantFps() },
			onToggleZoom: { toggleZoom() },
			onToggleTouchMode: { toggleTouchMode() },
			onOpenSettings: { openSettings() },
			onDisconnect: { reconnect.disconnect() }
		)
	}

	var overlayTitle: String {
		if reconnect.waitingForNetwork {
			return "No network connection"
		}
		if !reconnect.isReconnecting {
			return "Connection lost..."
		}
		if reconnect.waitingForStream {
			return "Reconnected, waiting for the stream..."
		}
		return ParsecBackgroundManager.shared.lastHostname.map { "Reconnecting to \($0)..." } ?? "Reconnecting..."
	}

}
