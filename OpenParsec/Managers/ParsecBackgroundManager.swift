import UIKit
import AVFoundation

class ParsecBackgroundManager {
	static let shared = ParsecBackgroundManager()

	/// Events the manager can emit to subscribers. Replaces the former seven
	/// separate closure callbacks (`onShouldReconnect`, `onShortcutReconnect`,
	/// `onShouldDisconnect`, `onResumeEndedSession`, `onEndedInBackground`,
	/// `onNextFrame`).
	enum Event {
		case shouldReconnect(peerId: String)
		case shortcutReconnect
		case shouldDisconnect
		case resumeEndedSession
		case endedInBackground
		case nextFrame
	}

	/// Token returned by `addEventHandler`, used to remove a specific handler.
	struct EventToken: Hashable {
		let id = UUID()
	}

	/// Multi-subscriber event registry. Several subscribers may listen at the
	/// same time to different events (e.g. `MainViewModel` handles
	/// `.shouldReconnect`/`.shortcutReconnect` while the stream UI handles
	/// `.endedInBackground`/`.resumeEndedSession`/`.nextFrame`). Each handler
	/// filters for the cases it cares about.
	private var eventHandlers: [UUID: (Event) -> Void] = [:]
	private let eventLock = NSLock()

	/// Convenience single-subscriber accessor. Setting it replaces all existing
	/// handlers; setting `nil` removes all. For the multi-subscriber case the
	/// codebase actually needs, prefer `addEventHandler`/`removeEventHandler`.
	var onEvent: ((Event) -> Void)? {
		get {
			eventLock.lock()
			defer { eventLock.unlock() }
			return eventHandlers.values.first
		}
		set {
			eventLock.lock()
			defer { eventLock.unlock() }
			eventHandlers.removeAll()
			if let handler = newValue {
				eventHandlers[UUID()] = handler
			}
		}
	}

	/// Mirrors the old `onShortcutReconnect != nil` guard the scene delegate used
	/// to decide whether the app shortcut was actionable.
	var canShortcutReconnect = false

	@discardableResult
	func addEventHandler(_ handler: @escaping (Event) -> Void) -> EventToken {
		let token = EventToken()
		eventLock.lock()
		defer { eventLock.unlock() }
		eventHandlers[token.id] = handler
		return token
	}

	func removeEventHandler(_ token: EventToken) {
		eventLock.lock()
		defer { eventLock.unlock() }
		eventHandlers[token.id] = nil
	}

	/// Emit an event to all registered handlers.
	func emit(_ event: Event) {
		eventLock.lock()
		let handlers = Array(eventHandlers.values)
		eventLock.unlock()
		handlers.forEach { $0(event) }
	}

	private(set) var hasActiveConnection = false
	private(set) var endedByUser = false
	private(set) var lastPeerId: String? {
		didSet { UserDefaults.standard.set(lastPeerId, forKey: "lastConnectedPeerId") }
	}
	private(set) var resumeOnLaunch: Bool {
		get { UserDefaults.standard.bool(forKey: "resumeLastHost") }
		set { UserDefaults.standard.set(newValue, forKey: "resumeLastHost") }
	}
	var lastHostname: String? {
		didSet {
			UserDefaults.standard.set(lastHostname, forKey: "lastConnectedHostname")
			updateShortcut()
		}
	}
	private var didDisconnectDueToBackground = false
	private(set) var isReconnecting = false
	var reconnectAttempts = 0
	var reconnectStartTime = Date()
	var resumedAt: Date?
	var isPaused = false
	private var holdTask: UIBackgroundTaskIdentifier = .invalid
	private var backgroundAt: Date?
	private var endedInBackground = false
	/// The active render surface (a `GLKViewController` or an `MTKView`).
	/// Renamed from `glkViewController` — it is not always a GLKViewController.
	weak var renderLoop: RenderLoop?

	var reconnectPending = false
	static let reconnectShortcut = "reconnect"

	var isMarkedForReconnect: Bool {
		return didDisconnectDueToBackground || isReconnecting
	}

	var isPiPActive: Bool {
		if #available(iOS 15.0, *) {
			return PictureInPictureManager.shared.isPiPActive
		}
		return false
	}

	private init() {
		lastPeerId = UserDefaults.standard.string(forKey: "lastConnectedPeerId")
		lastHostname = UserDefaults.standard.string(forKey: "lastConnectedHostname")
	}

	func updateShortcut() {
		UIApplication.shared.shortcutItems = lastHostname.map { [UIApplicationShortcutItem(type: Self.reconnectShortcut, localizedTitle: "Reconnect to \($0)", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "arrow.clockwise"), userInfo: nil)] }
	}

	func connectionDidStart() {
		hasActiveConnection = true
		didDisconnectDueToBackground = false
		isReconnecting = false
		isPaused = false
	}

	func connectionDidGoLive(peerId: String, hostname: String) {
		endedByUser = false
		lastPeerId = peerId
		lastHostname = hostname
		resumeOnLaunch = true
	}

	func connectionDidEnd() {
		hasActiveConnection = false
		isPaused = false
	}

	func sceneWillResignActive() {
	}

	func sceneDidBecomeActive() {
		// Takes priority over isPiPActive check because stopPiP() is async
		if didDisconnectDueToBackground, let peerId = lastPeerId {
			didDisconnectDueToBackground = false
			isReconnecting = true

			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
				self?.emit(.shouldReconnect(peerId: peerId))
			}
		}
	}

	func sceneDidEnterBackground() {
		if hasActiveConnection && !isPaused {
			var pipAttempted = false
			if #available(iOS 15.0, *) {
				pipAttempted = isPiPActive || PictureInPictureManager.shared.isStarting
			}
			if !pipAttempted {
				didDisconnectDueToBackground = true
			}
		}
	}

	func holdSessionInBackground() {
		guard holdTask == .invalid else { return }
		backgroundAt = Date()
		holdTask = UIApplication.shared.beginBackgroundTask(withName: "stream") { [weak self] in
			self?.endSessionInBackground("background time ran out")
		}
		guard holdTask != .invalid else {
			endSessionInBackground("no background time")
			return
		}
		appNote("[background] holding stream")
	}

	private func endSessionInBackground(_ reason: String) {
		if hasActiveConnection && !endedInBackground {
			appNote("[background] \(reason), ending stream")
			CParsec.disconnect()
			isPaused = true
			endedInBackground = true
			emit(.endedInBackground)
			RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
			for scene in UIApplication.shared.connectedScenes {
				UIApplication.shared.requestSceneSessionRefresh(scene.session)
			}
		}
		endHoldTask()
	}

	private func endHoldTask() {
		guard holdTask != .invalid else { return }
		UIApplication.shared.endBackgroundTask(holdTask)
		holdTask = .invalid
	}

	func sceneWillEnterForeground() {
		guard backgroundAt != nil else { return }
		backgroundAt = nil
		endHoldTask()
		if endedInBackground {
			endedInBackground = false
			isPaused = false
			appNote("[foreground] stream ended in the background")
			renderLoop?.isPaused = false
			emit(.resumeEndedSession)
		} else if hasActiveConnection {
			appNote("[foreground] stream held, resuming")
		}
	}

	func markForReconnect() {
		guard lastPeerId != nil else { return }
		didDisconnectDueToBackground = true
	}

	func endSession() {
		didDisconnectDueToBackground = false
		endedByUser = true
		endedInBackground = false
		isReconnecting = false
		reconnectAttempts = 0
		resumeOnLaunch = false
	}

	func disableAutoReconnect() {
		endSession()
		lastPeerId = nil
		lastHostname = nil
	}
}
