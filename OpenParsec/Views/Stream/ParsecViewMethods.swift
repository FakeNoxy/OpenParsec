import SwiftUI
import ParsecSDK
import Foundation
import AVFoundation

extension ParsecView {
	func post() {
		// Wire the reconnect/disconnect state machine to this live stream view.
		// Registers the single event handler that replaces the former
		// onShouldDisconnect / onEndedInBackground / onResumeEndedSession / onNextFrame.
		reconnect.attach(viewController: parsecViewController, contentController: controller)
		if #available(iOS 15.0, *) {
			PictureInPictureManager.shared.onPiPStopped = { [self] in
				if UIApplication.shared.applicationState != .active {
					ParsecBackgroundManager.shared.renderLoop?.isPaused = true
					CParsec.sendReleaseMessage()
					CParsec.pause()
					ParsecBackgroundManager.shared.isPaused = true
					if UIApplication.shared.applicationState == .background {
						ParsecBackgroundManager.shared.holdSessionInBackground()
					}
				} else {
					if ParsecBackgroundManager.shared.isReconnecting {
						return
					}
					// Check actual Parsec status — timers don't reliably fire in background
					var pcs = ParsecClientStatus()
					let currentStatus = CParsec.getStatusEx(&pcs)
					if currentStatus != PARSEC_OK || ParsecBackgroundManager.shared.isMarkedForReconnect {
						CParsec.disconnect()
						try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
						ParsecBackgroundManager.shared.markForReconnect()
						DispatchQueue.main.async {
							self.reconnect.disconnect(isBackgroundDisconnect: true)
						}
					}
				}
			}
			PictureInPictureManager.shared.onPiPStartFailed = {
				if UIApplication.shared.applicationState != .active {
					ParsecBackgroundManager.shared.renderLoop?.isPaused = true
					CParsec.sendReleaseMessage()
					CParsec.pause()
					ParsecBackgroundManager.shared.isPaused = true
					if UIApplication.shared.applicationState == .background {
						ParsecBackgroundManager.shared.holdSessionInBackground()
					}
				}
			}
		}

		CParsec.applyConfig()
		CParsec.setMuted(muted)
		if muted { CParsec.pause(video: false, audio: true) }
		parsecViewController.setZoomEnabled(zoomEnabled)


		let screenSize: CGSize = self.parsecViewController.view.frame.size
		// iPhone Duo: get scale from the view's screen, not UIScreen.main
		let scaleFactor = self.parsecViewController.view.window?.screen.nativeScale ?? 2.0
		ParsecResolution.updateClientResolution(width: Int(screenSize.width * scaleFactor), height: Int(screenSize.height * scaleFactor))

		ParsecView.getHostUserData()

		hideOverlay = SettingsStore.shared.noOverlay
		hideKeyboardButton = !SettingsStore.shared.showKeyboardButton
		parsecViewController.updateMenuEdgeSwipe(menuHidden: hideOverlay)
		offerHint()

		let overlayHidden = $hideOverlay
		let keyboardButtonHidden = $hideKeyboardButton
		let menuShown = $showMenu
		parsecViewController.onMenuEdgeSwipe = {
			overlayHidden.wrappedValue = false
			keyboardButtonHidden.wrappedValue = !SettingsStore.shared.showKeyboardButton
			menuShown.wrappedValue = true
			ParsecView.getHostUserData()
		}

        let keyboardShown = $showKeyboard
        parsecViewController.onKeyboardVisibilityChanged = { visible in
            keyboardShown.wrappedValue = visible
        }
		let hint = $hint
		let panHintShown = $keyboardPanHintShown
		parsecViewController.onKeyboardCoversPicture = {
			guard !panHintShown.wrappedValue else { return }
			panHintShown.wrappedValue = true
			withAnimation { hint.wrappedValue = "Part of the screen is under the keyboard\nDrag ↕\u{FE0E} to move it into view" }
			DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
				withAnimation { hint.wrappedValue = nil }
			}
		}

		parsecViewController.setKeyboardVisible(showKeyboard)
	}

	func openSettings() {
		decoderAtOpen = SettingsStore.shared.decoder
		fpsAtOpen = SettingsStore.shared.preferredFramesPerSecond
		pipAtOpen = SettingsStore.shared.enablePiP
		resolutionAtOpen = SettingsStore.shared.resolution
		bitrateAtOpen = SettingsStore.shared.bitrate
		showMenu = false
		if showKeyboard { toggleKeyboard() }
		withAnimation(.easeInOut(duration: 0.24)) { showSettings = true }
	}

	func applyStreamSettings() {
		zoomEnabled = SettingsStore.shared.zoomEnabled
		parsecViewController.setZoomEnabled(zoomEnabled)
		parsecViewController.updatePanHandle()
		parsecViewController.positionCursorOverlay()
		hideOverlay = SettingsStore.shared.noOverlay
		hideKeyboardButton = !SettingsStore.shared.showKeyboardButton
		parsecViewController.updateMenuEdgeSwipe(menuHidden: hideOverlay)
		offerHint()

		var hostConfigChanged = false
		if SettingsStore.shared.resolution != resolutionAtOpen {
			StreamSessionState.shared.resolutionX = SettingsStore.shared.resolution.width
			StreamSessionState.shared.resolutionY = SettingsStore.shared.resolution.height
			hostConfigChanged = true
		}
		if SettingsStore.shared.constantFps != StreamSessionState.shared.constantFps {
			StreamSessionState.shared.constantFps = SettingsStore.shared.constantFps
			hostConfigChanged = true
		}
		if hostConfigChanged { CParsec.updateHostVideoConfig() }
		if SettingsStore.shared.bitrate != bitrateAtOpen { applyBitrate() }
		if SettingsStore.shared.preferredFramesPerSecond != fpsAtOpen { parsecViewController.applyFrameRate() }
		if SettingsStore.shared.enablePiP != pipAtOpen {
			ParsecBackgroundManager.shared.reconnectPending = true
			reconnect.disconnect()
		} else if SettingsStore.shared.decoder != decoderAtOpen {
			reconnectToApply()
		}
	}

	func reconnectToApply() {
		guard let peerId = ParsecBackgroundManager.shared.lastPeerId else { return }
		appNote("[reconnect] to apply settings")
		reconnect.reconnectTo(peerId)
	}

	func disableOverlay() {
		hideOverlay = true
		hideKeyboardButton = true
		showMenu = false
		parsecViewController.updateMenuEdgeSwipe(menuHidden: true)
		offerHint(always: true)
	}

	func offerHint(always: Bool = false) {
		let menu = hideOverlay && (always || !menuSwipeHintShown)
		let keyboard = hideKeyboardButton && (always || !keyboardHintShown)
		guard menu || keyboard else { return }
		if menu { menuSwipeHintShown = true }
		if keyboard { keyboardHintShown = true }
		let text = [menu ? "Swipe from the left edge for the menu" : nil, keyboard ? "Tap with three fingers to show or hide the keyboard" : nil].compactMap { $0 }.joined(separator: "\n")
		withAnimation { hint = text }
		DispatchQueue.main.asyncAfter(deadline: .now() + (menu && keyboard ? 6 : 4)) {
			withAnimation { hint = nil }
		}
	}

	func toggleMute() {
		muted.toggle()
		CParsec.setMuted(muted)
		if muted {
			CParsec.pause(video: false, audio: true)
		} else {
			CParsec.resume()
		}
	}


	func changeResolution(res: ParsecResolution) {
        SettingsStore.shared.resolution = res
		DispatchQueue.main.async {
			StreamSessionState.shared.resolutionX = res.width
			StreamSessionState.shared.resolutionY = res.height
			CParsec.updateHostVideoConfig()
		}
	}

	func changeBitRate(bitrate: Int) {
		SettingsStore.shared.bitrate = bitrate
		applyBitrate()
	}

	func applyBitrate() {
		let target = SettingsStore.shared.bitrate > 0 ? SettingsStore.shared.bitrate : StreamSessionState.shared.hostDefaultBitrate
		guard target > 0, target != StreamSessionState.shared.bitrate else { return }
		StreamSessionState.shared.bitrate = target
		CParsec.updateHostVideoConfig()
	}

	func toggleConstantFps() {
		DispatchQueue.main.async {
			StreamSessionState.shared.constantFps.toggle()
			CParsec.updateHostVideoConfig()
			SettingsStore.shared.constantFps = StreamSessionState.shared.constantFps
		}
	}

	func toggleKeyboard() {
		DispatchQueue.main.async {
			showKeyboard.toggle()
			parsecViewController.setKeyboardVisible(showKeyboard)
		}
	}

	func toggleZoom() {
		DispatchQueue.main.async {
			zoomEnabled.toggle()
			parsecViewController.setZoomEnabled(zoomEnabled)
			SettingsStore.shared.zoomEnabled = zoomEnabled
		}
	}

	func toggleTouchMode() {
		DispatchQueue.main.async {
			SettingsStore.shared.cursorMode = SettingsStore.shared.cursorMode == .direct ? .touchpad : .direct
			parsecViewController.updatePanHandle()
		}
	}

	func changeDisplay(displayId: String) {
		DispatchQueue.main.async {
			StreamSessionState.shared.output = displayId
			CParsec.updateHostVideoConfig()
		}
	}

	static func getHostUserData() {
		let data = Data()
		CParsec.sendUserData(type: .getVideoConfig, message: data)
		CParsec.sendUserData(type: .getAdapterInfo, message: data)
	}


// from https://github.com/utmapp/UTM/blob/117e3a962f2f46f7d847632d65fa7a85a2bb0cfa/Platform/iOS/VMWindowView.swift#L314
}
