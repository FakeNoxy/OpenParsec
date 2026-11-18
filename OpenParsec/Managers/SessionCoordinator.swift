import UIKit

/// Owns the scene-lifecycle fan-out for background/PiP/reconnect behavior.
/// Absorbs the logic previously inlined in `SceneDelegate` so the state
/// machine is testable without a `UIScene`. `SceneDelegate` is now a thin
/// forwarder.
final class SessionCoordinator {
	static let shared = SessionCoordinator()

	private var pendingUnpause: DispatchWorkItem?

	private init() {}

	/// Called from `scene(_:willConnectTo:options:)`.
	func sceneWillConnect(shortcutType: String?) {
		if shortcutType == ParsecBackgroundManager.reconnectShortcut {
			ParsecBackgroundManager.shared.reconnectPending = true
		}
		ParsecBackgroundManager.shared.updateShortcut()
	}

	/// Called from `windowScene(_:performActionFor:completionHandler:)`.
	/// Returns whether the shortcut was actionable (and dispatched).
	func handleReconnectShortcut() -> Bool {
		let mgr = ParsecBackgroundManager.shared
		guard mgr.canShortcutReconnect, !mgr.hasActiveConnection, !mgr.isMarkedForReconnect else {
			return false
		}
		mgr.emit(.shortcutReconnect)
		return true
	}

	func sceneDidDisconnect() {
		if ParsecBackgroundManager.shared.hasActiveConnection {
			CParsec.sendReleaseMessage()
			CParsec.disconnect()
		}
	}

	func sceneDidBecomeActive() {
		if #available(iOS 15.0, *) {
			PictureInPictureManager.shared.stopPiP()
			if PictureInPictureManager.shared.stopFramePump() {
				ParsecBackgroundManager.shared.renderLoop?.isPaused = false
			}
		}
		if ParsecBackgroundManager.shared.isPaused {
			ParsecBackgroundManager.shared.renderLoop?.isPaused = false
			CParsec.resume()
			ParsecBackgroundManager.shared.resumedAt = Date()
			pendingUnpause?.cancel()
			let unpause = DispatchWorkItem { ParsecBackgroundManager.shared.isPaused = false }
			pendingUnpause = unpause
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: unpause)
		}
		// drop any input the host still thinks is held, a stuck modifier survives the resume
		if ParsecBackgroundManager.shared.hasActiveConnection {
			CParsec.sendReleaseMessage()
		}
		ParsecBackgroundManager.shared.sceneDidBecomeActive()
	}

	func sceneWillResignActive() {
		if ParsecBackgroundManager.shared.hasActiveConnection {
			CParsec.sendReleaseMessage()
		}
		ParsecBackgroundManager.shared.sceneWillResignActive()
	}

	func sceneWillEnterForeground() {
		ParsecBackgroundManager.shared.sceneWillEnterForeground()
	}

	func sceneDidEnterBackground() {
		pendingUnpause?.cancel()
		pendingUnpause = nil
		var pipAttempted = false
		if #available(iOS 15.0, *) {
			if ParsecBackgroundManager.shared.hasActiveConnection && SettingsStore.shared.enablePiP {
				PictureInPictureManager.shared.startPiP()
				pipAttempted = PictureInPictureManager.shared.isPiPActive || PictureInPictureManager.shared.isStarting
			}
		}

		if pipAttempted {
			ParsecBackgroundManager.shared.isPaused = false
			if #available(iOS 15.0, *) {
				ParsecBackgroundManager.shared.renderLoop?.isPaused = true
				PictureInPictureManager.shared.startFramePump()
			}
		}

		if !pipAttempted && ParsecBackgroundManager.shared.hasActiveConnection {
			ParsecBackgroundManager.shared.renderLoop?.isPaused = true
			CParsec.sendReleaseMessage()
			CParsec.pause()
			ParsecBackgroundManager.shared.isPaused = true
			ParsecBackgroundManager.shared.holdSessionInBackground()
		}

		if ParsecBackgroundManager.shared.hasActiveConnection {
			appNote("[background] picture in picture \(pipAttempted ? "starting" : "off"), stream \(pipAttempted ? "running" : "paused")")
		}
		ParsecBackgroundManager.shared.sceneDidEnterBackground()
	}
}
