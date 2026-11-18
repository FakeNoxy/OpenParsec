import SwiftUI
import ParsecSDK
import AVFoundation

/// Owns the reconnect/disconnect state machine that was previously inlined in
/// `ParsecStatusBar.poll()` and the `ParsecView`/`ParsecViewMethods` helpers.
/// `ParsecStatusBar` is now pure UI over this object (one `@ObservedObject`).
///
/// Not `@MainActor` on purpose: the `.nextFrame` event is delivered from the
/// renderer's `upload()` (which runs on the main thread in practice, matching
/// the previous `onNextFrame` closure behavior), and keeping this a plain
/// class preserves the exact synchronous timing of the old code.
final class ReconnectController: ObservableObject {
	@Published var metricInfo: String = "Loading..."
	@Published var showDCAlert: Bool = false
	@Published var DCAlertText: String = "Disconnected (reason unknown)"
	@Published var isReconnecting: Bool = false
	@Published var connectionLost: Bool = false
	@Published var waitingForNetwork: Bool = false
	@Published var waitingForStream: Bool = false

	private var networkFailureSince: Date?
	private var frameHeld = false
	private var wasDisconnected: Bool = true
	private var liveSince: CFTimeInterval?
	private var seenInterfaceChanges = NetworkWatcher.shared.interfaceChanges

	weak var parsecViewController: ParsecViewController?
	/// A value copy of the `ContentView` struct; mutating `curView` through it
	/// still reaches the shared `@State` storage (same pattern as the old
	/// `ParsecView.controller`).
	var contentController: ContentView?

	private var eventToken: ParsecBackgroundManager.EventToken?

	/// Wire the controller to a live stream view. Sets the weak references and
	/// registers the single event handler. Idempotent — re-attaching replaces
	/// the previous handler so no duplicates accumulate.
	func attach(viewController: ParsecViewController, contentController: ContentView?) {
		self.parsecViewController = viewController
		self.contentController = contentController
		if let token = eventToken {
			ParsecBackgroundManager.shared.removeEventHandler(token)
		}
		eventToken = ParsecBackgroundManager.shared.addEventHandler { [weak self] event in
			self?.handle(event)
		}
	}

	private func handle(_ event: ParsecBackgroundManager.Event) {
		switch event {
		case .nextFrame:
			pictureBack()
		case .shouldDisconnect:
			if #available(iOS 15.0, *) {
				if PictureInPictureManager.shared.isPiPActive { return }
			}
			disconnect(isBackgroundDisconnect: true)
		case .endedInBackground:
			waitingForStream = false
			if showDCAlert || waitingForNetwork { return }
			isReconnecting = true
		case .resumeEndedSession:
			if showDCAlert || waitingForNetwork { return }
			guard let peerId = ParsecBackgroundManager.shared.lastPeerId else { return }
			appNote("[reconnect] back from the background, reconnecting")
			reconnectTo(peerId)
			ParsecBackgroundManager.shared.reconnectAttempts = 1
		default:
			break
		}
	}

	func holdFrame(_ hold: Bool) {
		var pumping = false
		if #available(iOS 15.0, *) { pumping = PictureInPictureManager.shared.isPumping }
		if hold {
			frameHeld = true
			if !pumping { ParsecBackgroundManager.shared.renderLoop?.isPaused = true }
		} else if frameHeld {
			frameHeld = false
			if !pumping { ParsecBackgroundManager.shared.renderLoop?.isPaused = false }
		}
	}

	func pictureBack() {
		guard isReconnecting, liveSince != nil else { return }
		liveSince = nil
		withAnimation(.easeOut(duration: 0.3)) {
			isReconnecting = false
			waitingForStream = false
		}
		appNote("[reconnect] picture back")
	}

	func poll(showMenu: Bool) {
		if showDCAlert || ParsecBackgroundManager.shared.isPaused || ParsecBackgroundManager.shared.endedByUser {
			return
		}

		var pcs = ParsecClientStatus()
		var status = CParsec.getStatusEx(&pcs)

		var pipActive = false
		if #available(iOS 15.0, *) {
			pipActive = PictureInPictureManager.shared.isPiPActive
		}
		let offline = NetworkWatcher.shared.noNetwork

		if waitingForNetwork {
			if offline {
				holdFrame(true)
				return
			}
			waitingForNetwork = false
			ParsecBackgroundManager.shared.resumedAt = Date()
			if let peerId = ParsecBackgroundManager.shared.lastPeerId {
				let mgr = ParsecBackgroundManager.shared
				mgr.reconnectAttempts = 1
				appNote("[reconnect] network back, reconnecting")
				isReconnecting = true
				parsecViewController?.resetKeyState()
				CParsec.reconnect(peerId)
				mgr.reconnectStartTime = Date()
				return
			}
		}

		if status == PARSEC_OK && !isReconnecting && !pipActive {
			if offline {
				appNote("[stream] no network, not waiting on sdk")
				status = NETWORK_ERR_INTERRUPTED
			} else if SettingsStore.shared.autoReconnect && NetworkWatcher.shared.interfaceChanges != seenInterfaceChanges {
				appNote("[stream] network interface changed, reconnecting")
				status = NETWORK_ERR_INTERRUPTED
			}
		}
		seenInterfaceChanges = NetworkWatcher.shared.interfaceChanges

		if status == PARSEC_OK && pcs.networkFailure && !isReconnecting && !pipActive {
			if networkFailureSince == nil { networkFailureSince = Date() }
			let lost = Date().timeIntervalSince(networkFailureSince!)
			let justResumed = Date().timeIntervalSince(ParsecBackgroundManager.shared.resumedAt ?? .distantPast) < 10
			connectionLost = true
			if lost >= 3 || justResumed {
				networkFailureSince = nil
				connectionLost = false
				ParsecBackgroundManager.shared.resumedAt = nil
				status = NETWORK_ERR_INTERRUPTED
				appNote("[stream] network failure held, treating it as a lost connection")
			}
		} else {
			networkFailureSince = nil
			connectionLost = false
		}

		if status != PARSEC_OK {
			liveSince = nil
			waitingForStream = false
			holdFrame(true)
			if ParsecBackgroundManager.shared.isMarkedForReconnect {
				return
			}

			if offline && !pipActive {
				isReconnecting = false
				connectionLost = false
				if SettingsStore.shared.autoReconnect && ParsecBackgroundManager.shared.lastPeerId != nil {
					ParsecBackgroundManager.shared.reconnectAttempts = 0
					waitingForNetwork = true
					appNote("[stream] no network, waiting")
					return
				}
				appNote("[stream] ended, no network, alert")
				DCAlertText = "No network connection"
				showDCAlert = true
				return
			}

			let setupFailure = isReconnecting ? CParsec.setupError.flatMap { $0.at > ParsecBackgroundManager.shared.reconnectStartTime ? $0.line : nil } : nil

			if status == PARSEC_CONNECTING && isReconnecting && setupFailure == nil {
				if Date().timeIntervalSince(ParsecBackgroundManager.shared.reconnectStartTime) < 15 {
					return
				}
			}

			if status == CONNECT_WRN_APPROVAL && isReconnecting && setupFailure == nil {
				if Date().timeIntervalSince(ParsecBackgroundManager.shared.reconnectStartTime) < 60 {
					return
				}
			}

			// PiP: connection died (screen lock killed GPU). Kill connection+audio once,
			// subsequent polls exit via isMarkedForReconnect above.
			if pipActive {
				appNote("[stream] lost during picture in picture, status \(status.rawValue), reconnect owed")
				CParsec.disconnect()
				try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
				ParsecBackgroundManager.shared.connectionDidEnd()
				ParsecBackgroundManager.shared.markForReconnect()
				wasDisconnected = true
				return
			}

			if SettingsStore.shared.autoReconnect, !status.isPermanentFailure || (status == CONNECT_WRN_APPROVAL && setupFailure != nil), let peerId = ParsecBackgroundManager.shared.lastPeerId {
				let mgr = ParsecBackgroundManager.shared
				if mgr.reconnectAttempts < 3 {
					let gap: TimeInterval = mgr.reconnectAttempts == 0 ? 0 : mgr.reconnectAttempts == 1 ? 2 : 5
					if Date().timeIntervalSince(mgr.reconnectStartTime) < gap {
						return
					}
					mgr.reconnectAttempts += 1
					appNote("[reconnect] attempt \(mgr.reconnectAttempts) after status \(status.rawValue)\(setupFailure.map { ", sdk setup failed: \($0)" } ?? "")")
					isReconnecting = true
					parsecViewController?.resetKeyState()
					CParsec.reconnect(peerId)
					mgr.reconnectStartTime = Date()
					return
				}
				mgr.reconnectAttempts = 0
			}

			isReconnecting = false
			wasDisconnected = true
			let silent = SettingsStore.shared.autoReconnect && !SettingsStore.shared.errorPrompts && !status.isPermanentFailure
			appNote("[stream] ended, status \(status.rawValue), \(silent ? "silent" : "alert")")
			if silent {
				// silent: auto-reconnect spent its retries, dont nag with an alert
				disconnect()
			} else {
				DCAlertText = status.readable()
				showDCAlert = true
			}
			return
		}

		holdFrame(connectionLost)

		if isReconnecting {
			if liveSince == nil {
				liveSince = CACurrentMediaTime()
				withAnimation(.easeInOut(duration: 0.2)) { waitingForStream = true }
				ParsecBackgroundManager.shared.reconnectAttempts = 0
				appNote("[reconnect] live again")
				ParsecView.getHostUserData()
				// SDK forgets stream dims on reconnect, re-send them so the frame fills not corners
				if let vc = parsecViewController {

					// iPhone Duo: get scale from the view's screen, not UIScreen.main
					let scale = vc.view.window?.screen.scale ?? 2.0
					CParsec.setFrame(vc.view.bounds.width, vc.view.bounds.height, scale)
				}
			}
			if CParsec.runningRenderer != .metal || CACurrentMediaTime() - liveSince! > 6 {
				pictureBack()
			}
		}

		if showMenu || SettingsStore.shared.alwaysShowStatus {
			let str = String.fromBuffer(&pcs.decoder.0.name.0, length: 16)
			metricInfo = "Decode \(String(format: "%.2f", pcs.`self`.metrics.0.decodeLatency))ms    Encode \(String(format: "%.2f", pcs.`self`.metrics.0.encodeLatency))ms    Network \(String(format: "%.2f", pcs.`self`.metrics.0.networkLatency))ms    Bitrate \(String(format: "%.2f", pcs.`self`.metrics.0.bitrate))Mbps    RTx \(pcs.`self`.metrics.0.fastRTs + pcs.`self`.metrics.0.slowRTs)    Queue \(pcs.`self`.metrics.0.queuedFrames)    Draw \(String(format: "%.0f", CParsec.drawRate))fps \(CParsec.rendererName)    \(pcs.decoder.0.h265 ? "H265" : "H264") \(pcs.decoder.0.width)x\(pcs.decoder.0.height) \(pcs.decoder.0.color444 ? "4:4:4" : "4:2:0") \(str)"
		}
	}

	func reconnectTo(_ peerId: String) {
		isReconnecting = true
		ParsecBackgroundManager.shared.reconnectAttempts = 0
		parsecViewController?.resetKeyState()
		CParsec.reconnect(peerId)
		ParsecBackgroundManager.shared.reconnectStartTime = Date()
	}

	func disconnect(isBackgroundDisconnect: Bool = false) {
		appNote("[stream] disconnect\(isBackgroundDisconnect ? " in the background" : "")")
		if !isBackgroundDisconnect {
			ParsecBackgroundManager.shared.endSession()
		}
		if let token = eventToken {
			ParsecBackgroundManager.shared.removeEventHandler(token)
			eventToken = nil
		}

		if #available(iOS 15.0, *) {
			PictureInPictureManager.shared.teardown()
		}

		CParsec.sendReleaseMessage()
		CParsec.disconnect()
		StreamSessionState.shared.output = "none"
		CParsec.drawRate = 0
		parsecViewController?.glkView.cleanUp()

		parsecViewController?.scrollView.zoomScale = 1.0
		parsecViewController?.scrollView.contentOffset = .zero

		contentController?.setView(.main)
	}
}
