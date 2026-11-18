import SwiftUI
import ParsecSDK
import Foundation
import AVFoundation

extension ParsecView {
	func post() {
		ParsecBackgroundManager.shared.onShouldDisconnect = {
			NotificationCenter.default.post(name: NSNotification.Name("ParsecBackgroundDisconnect"), object: nil)
		}
		ParsecBackgroundManager.shared.onEndedInBackground = { [self] in
			ParsecBackgroundManager.shared.onNextFrame = nil
			waitingForStream = false
			if showDCAlert || waitingForNetwork { return }
			isReconnecting = true
		}
		ParsecBackgroundManager.shared.onResumeEndedSession = { [self] in
			if showDCAlert || waitingForNetwork { return }
			guard let peerId = ParsecBackgroundManager.shared.lastPeerId else { return }
			appNote("[reconnect] back from the background, reconnecting")
			reconnectTo(peerId)
			ParsecBackgroundManager.shared.reconnectAttempts = 1
		}
		if #available(iOS 15.0, *) {
			PictureInPictureManager.shared.onPiPStopped = { [self] in
				if UIApplication.shared.applicationState != .active {
					ParsecBackgroundManager.shared.glkViewController?.isPaused = true
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
							self.disconnect(isBackgroundDisconnect: true)
						}
					}
				}
			}
			PictureInPictureManager.shared.onPiPStartFailed = {
				if UIApplication.shared.applicationState != .active {
					ParsecBackgroundManager.shared.glkViewController?.isPaused = true
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

		hideOverlay = SettingsHandler.noOverlay
		hideKeyboardButton = !SettingsHandler.showKeyboardButton
		parsecViewController.updateMenuEdgeSwipe(menuHidden: hideOverlay)
		offerHint()

		let overlayHidden = $hideOverlay
		let keyboardButtonHidden = $hideKeyboardButton
		let menuShown = $showMenu
		parsecViewController.onMenuEdgeSwipe = {
			overlayHidden.wrappedValue = false
			keyboardButtonHidden.wrappedValue = !SettingsHandler.showKeyboardButton
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
		decoderAtOpen = SettingsHandler.decoder
		fpsAtOpen = SettingsHandler.preferredFramesPerSecond
		pipAtOpen = SettingsHandler.enablePiP
		resolutionAtOpen = SettingsHandler.resolution
		bitrateAtOpen = SettingsHandler.bitrate
		showMenu = false
		if showKeyboard { toggleKeyboard() }
		withAnimation(.easeInOut(duration: 0.24)) { showSettings = true }
	}

	func applyStreamSettings() {
		zoomEnabled = SettingsHandler.zoomEnabled
		parsecViewController.setZoomEnabled(zoomEnabled)
		parsecViewController.updatePanHandle()
		parsecViewController.positionCursorOverlay()
		hideOverlay = SettingsHandler.noOverlay
		hideKeyboardButton = !SettingsHandler.showKeyboardButton
		parsecViewController.updateMenuEdgeSwipe(menuHidden: hideOverlay)
		offerHint()

		var hostConfigChanged = false
		if SettingsHandler.resolution != resolutionAtOpen {
			DataManager.model.resolutionX = SettingsHandler.resolution.width
			DataManager.model.resolutionY = SettingsHandler.resolution.height
			hostConfigChanged = true
		}
		if SettingsHandler.constantFps != DataManager.model.constantFps {
			DataManager.model.constantFps = SettingsHandler.constantFps
			hostConfigChanged = true
		}
		if hostConfigChanged { CParsec.updateHostVideoConfig() }
		if SettingsHandler.bitrate != bitrateAtOpen { applyBitrate() }
		if SettingsHandler.preferredFramesPerSecond != fpsAtOpen { parsecViewController.applyFrameRate() }
		if SettingsHandler.enablePiP != pipAtOpen {
			ParsecBackgroundManager.shared.reconnectPending = true
			disconnect()
		} else if SettingsHandler.decoder != decoderAtOpen {
			reconnectToApply()
		}
	}

	func reconnectToApply() {
		guard let peerId = ParsecBackgroundManager.shared.lastPeerId else { return }
		appNote("[reconnect] to apply settings")
		reconnectTo(peerId)
	}

	func reconnectTo(_ peerId: String) {
		isReconnecting = true
		ParsecBackgroundManager.shared.reconnectAttempts = 0
		parsecViewController.resetKeyState()
		CParsec.reconnect(peerId)
		ParsecBackgroundManager.shared.reconnectStartTime = Date()
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

		/*func genDisplaySheet() -> ActionSheet
	{
		let len:Int = 16
		var outputs = [ParsecOutput?](repeating:nil, count:len)
		ParsecGetOutputs(&outputs, UInt32(len))
		print("Listing \(outputs.count) displays")

		func getDeviceName(_ output:ParsecOutput) -> String
		{
			return withUnsafePointer(to:output.device)
			{
				$0.withMemoryRebound(to: UInt8.self, capacity:MemoryLayout.size(ofValue:$0))
				{
					String(cString:$0)
				}
			}
		}

		let buttons = outputs.enumerated().map
		{ i, output in
			Alert.Button.default(Text("\(i) - \(getDeviceName(output))"), action:{print("Selected device \(i)")})
		}
		return ActionSheet(title: Text("Select a Display:"), buttons:buttons + [Alert.Button.cancel()])
	}*/

	func disconnect(isBackgroundDisconnect: Bool = false) {
		appNote("[stream] disconnect\(isBackgroundDisconnect ? " in the background" : "")")
		if !isBackgroundDisconnect {
			ParsecBackgroundManager.shared.endSession()
		}
		ParsecBackgroundManager.shared.onResumeEndedSession = nil
		ParsecBackgroundManager.shared.onEndedInBackground = nil
		ParsecBackgroundManager.shared.onNextFrame = nil

		if #available(iOS 15.0, *) {
			PictureInPictureManager.shared.teardown()
		}

		CParsec.sendReleaseMessage()
		CParsec.disconnect()
		DataManager.model.output = "none"
		CParsec.drawRate = 0
		self.parsecViewController.glkView.cleanUp()

		parsecViewController.scrollView.zoomScale = 1.0
		parsecViewController.scrollView.contentOffset = .zero

		if let c = controller {
			c.setView(.main)
		}
	}

	func changeResolution(res: ParsecResolution) {
        SettingsHandler.resolution = res
		DispatchQueue.main.async {
			DataManager.model.resolutionX = res.width
			DataManager.model.resolutionY = res.height
			CParsec.updateHostVideoConfig()
		}
	}

	func changeBitRate(bitrate: Int) {
		SettingsHandler.bitrate = bitrate
		applyBitrate()
	}

	func applyBitrate() {
		let target = SettingsHandler.bitrate > 0 ? SettingsHandler.bitrate : DataManager.model.hostDefaultBitrate
		guard target > 0, target != DataManager.model.bitrate else { return }
		DataManager.model.bitrate = target
		CParsec.updateHostVideoConfig()
	}

	func toggleConstantFps() {
		DispatchQueue.main.async {
			DataManager.model.constantFps.toggle()
			CParsec.updateHostVideoConfig()
			SettingsHandler.constantFps = DataManager.model.constantFps
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
			SettingsHandler.zoomEnabled = zoomEnabled
		}
	}

	func toggleTouchMode() {
		DispatchQueue.main.async {
			SettingsHandler.cursorMode = SettingsHandler.cursorMode == .direct ? .touchpad : .direct
			parsecViewController.updatePanHandle()
		}
	}

	func changeDisplay(displayId: String) {
		DispatchQueue.main.async {
			DataManager.model.output = displayId
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

extension View {
	func prefersPersistentSystemOverlaysHidden() -> some View {
		if #available(iOS 16, *) {
			return self.persistentSystemOverlays(.hidden)
		} else {
			return self
		}
	}
}
