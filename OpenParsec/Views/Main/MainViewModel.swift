import SwiftUI
import UIKit
import ParsecSDK

/// Owns the main-screen state and logic: hosts/self/friends refresh,
/// connect polling, reconnect, and logout.
/// `MainView` is UI-only; all logic lives here.
@MainActor
final class MainViewModel: ObservableObject {
	// Host page
	@Published var hostCountStr = "0 hosts"
	@Published var refreshTime = ""
	@Published var hosts: [IdentifiableHostInfo] = []

	// Friend page
	@Published var friendCountStr = "0 friends"
	@Published var userInfo: IdentifiableUserInfo?
	@Published var friends: [IdentifiableUserInfo] = []

	// Global
	@Published var showBaseAlert = false
	@Published var baseAlertText = ""

	@Published var isConnecting = false
	@Published var waitingForApproval = false
	@Published var retryingConnect = false
	@Published var connectPolls = 0
	@Published var connectingToName = ""
	@Published var approvalStartedAt: Date?
	@Published var connectStartedAt = Date()

	@Published var isRefreshing = false
	@Published var refreshError: String?

	@Published var sessionExpired = false
	@Published var lastHostShown: String?

	/// Invoked after a successful connect so the caller can navigate to the stream.
	var onConnected: (() -> Void)?
	/// Invoked after logout so the caller can navigate to the login screen.
	var onLogout: (() -> Void)?

	private var pollTask: Task<Void, Never>?
	private var eventToken: ParsecBackgroundManager.EventToken?

	func initView() {
		lastHostShown = ParsecBackgroundManager.shared.lastPeerId != nil ? ParsecBackgroundManager.shared.lastHostname : nil
		refreshHosts()
		refreshSelf()
		refreshFriends()

		let mgr = ParsecBackgroundManager.shared
		// Arm the app-shortcut guard (was: onShortcutReconnect != nil).
		mgr.canShortcutReconnect = true
		// .shouldReconnect / .shortcutReconnect handlers. Re-arming on every
		// initView() replaces the previous last-writer-wins closure assignment.
		if let old = self.eventToken { mgr.removeEventHandler(old) }
		self.eventToken = mgr.addEventHandler { [weak self] event in
			switch event {
			case .shouldReconnect(let peerId):
				Task { @MainActor in
					guard let self else { return }
					if let host = self.hosts.first(where: { $0.id == peerId }) {
						self.connectTo(host)
					} else {
						self.refreshHosts()
					}
				}
			case .shortcutReconnect:
				Task { @MainActor in
					guard let self, !self.isConnecting else { return }
					self.reconnectLastHost()
				}
			default:
				break
			}
		}

		NetworkWatcher.shared.onReturn = {
			guard SessionStore.clinfo != nil, !ParsecBackgroundManager.shared.hasActiveConnection else { return }
			Task { @MainActor in
				self.refreshHosts()
				self.refreshFriends()
			}
		}
		NetworkWatcher.shared.start()

		let pending = ParsecBackgroundManager.shared.reconnectPending
		ParsecBackgroundManager.shared.reconnectPending = false

		NetworkWatcher.shared.whenKnown {
			Task { @MainActor in
				if (SettingsStore.shared.autoConnectOnLaunch && ParsecBackgroundManager.shared.resumeOnLaunch || pending) && !self.isConnecting && !ParsecBackgroundManager.shared.hasActiveConnection, ParsecBackgroundManager.shared.lastPeerId != nil {
					self.reconnectLastHost()
				}
			}
		}
	}

	func reconnectLastHost() {
		guard let peerId = ParsecBackgroundManager.shared.lastPeerId else { return }
		let hostname = ParsecBackgroundManager.shared.lastHostname ?? peerId
		let user = UserInfo(id: 0, name: "", warp: false, team_id: "")
		let stub = IdentifiableHostInfo(id: peerId, hostname: hostname, user: user, connections: 0)
		appNote("[connect] last host from the saved id, host list \(hosts.isEmpty ? "not loaded yet" : "loaded")")
		connectTo(stub)
	}

	func clearLastHost() {
		ParsecBackgroundManager.shared.disableAutoReconnect()
		lastHostShown = nil
	}

	func refreshHosts() {
		guard !isRefreshing else { return }
		withAnimation { isRefreshing = true }

		guard SessionStore.clinfo != nil else {
			isRefreshing = false
			sessionExpired = true
			return
		}

		Task { @MainActor in
			defer { isRefreshing = false }

			do {
				let response = try await ParsecAPI.shared.hosts()
				sessionExpired = false

				guard let datas = response.data.data else {
					refreshError = "Couldn't refresh hosts: bad response"
					return
				}
				refreshError = nil
				hosts.removeAll()
				datas.forEach { h in
					hosts.append(IdentifiableHostInfo(id: h.peer_id, hostname: h.name, user: h.user, connections: h.players))
				}
				if let lastId = ParsecBackgroundManager.shared.lastPeerId, let current = hosts.first(where: { $0.id == lastId }), current.hostname != ParsecBackgroundManager.shared.lastHostname {
					ParsecBackgroundManager.shared.lastHostname = current.hostname
					if lastHostShown != nil { lastHostShown = current.hostname }
				}

				var grammar: String = "hosts"
				if hosts.count == 1 { grammar = "host" }
				hostCountStr = "\(hosts.count) \(grammar)"

				let formatter = DateFormatter()
				formatter.dateStyle = .short
				formatter.timeStyle = .short
				refreshTime = "Last refreshed at \(formatter.string(from: Date()))"
			} catch let APIError.http(status, data) {
				if status == 401 {
					refreshError = nil
					sessionExpired = true
				} else if status == 403, let info: ErrorInfo = try? JSONDecoder().decode(ErrorInfo.self, from: data) {
					refreshError = "Couldn't refresh hosts: \(info.error)"
				} else {
					refreshError = "Couldn't refresh hosts (HTTP \(status))"
				}
			} catch APIError.decoding(_) {
				refreshError = "Couldn't refresh hosts: bad response"
			} catch {
				refreshError = "Can't reach Parsec"
			}
		}
	}

	func refreshSelf() {
		guard SessionStore.clinfo != nil else { return }

		Task { @MainActor in
			do {
				let response = try await ParsecAPI.shared.selfInfo()
				userInfo = IdentifiableUserInfo(id: response.data.data.id, username: response.data.data.name)
			} catch let APIError.http(status, data) {
				if status == 401 {
					sessionExpired = true
				} else if let info: ErrorInfo = try? JSONDecoder().decode(ErrorInfo.self, from: data) {
					baseAlertText = "Error gathering user info: \(info.error)"
					showBaseAlert = true
				}
			} catch {
				// silent, matching the original behavior
			}
		}
	}

	func refreshFriends() {
		guard SessionStore.clinfo != nil else { return }

		Task { @MainActor in
			do {
				let response = try await ParsecAPI.shared.friends()
				friends.removeAll()
				if let datas = response.data.data {
					datas.forEach { f in
						friends.append(IdentifiableUserInfo(id: f.user_id, username: f.user_name))
					}
				}

				var grammar: String = "friends"
				if friends.count == 1 { grammar = "friend" }
				friendCountStr = "\(friends.count) \(grammar)"
			} catch let APIError.http(status, data) {
				if status == 401 {
					sessionExpired = true
				} else if let info: ErrorInfo = try? JSONDecoder().decode(ErrorInfo.self, from: data) {
					baseAlertText = "Error gathering friends: \(info.error)"
					showBaseAlert = true
				}
			} catch {
				// silent, matching the original behavior
			}
		}
	}

	func connectTo(_ who: IdentifiableHostInfo, retried: Bool = false) {
		if NetworkWatcher.shared.noNetwork {
			appNote("[connect] no network, not trying")
			withAnimation {
				isConnecting = false
				waitingForApproval = false
				retryingConnect = false
			}
			baseAlertText = "No network connection"
			showBaseAlert = true
			return
		}

		if let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) {
			let scale = window.screen.nativeScale
			ParsecResolution.updateClientResolution(width: Int(window.bounds.width * scale), height: Int(window.bounds.height * scale))
		} else {
			// iPhone Duo: no key window yet on a launch reconnect, use view bounds fallback
			// without this it asks the host for 3840x2160
			if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
				let scale = scene.screen.nativeScale
				let size = scene.screen.bounds.size
				ParsecResolution.updateClientResolution(width: Int(size.width * scale), height: Int(size.height * scale))
			}
		}

		pollTask?.cancel()
		pollTask = nil
		CParsec.initialize()
		StreamSessionState.shared.reset()
		ParsecBackgroundManager.shared.reconnectAttempts = 0
		connectingToName = who.hostname
		retryingConnect = retried
		withAnimation { isConnecting = true }

		connectStartedAt = Date()
		let status = CParsec.connect(who.id)
		appNote("[connect] started, status \(status.rawValue)")
		connectPolls = 0
		approvalStartedAt = nil

		// Polling status (1s cadence, same as the old Timer)
		pollTask = Task { @MainActor [weak self] in
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 1_000_000_000)
				if Task.isCancelled { break }
				self?.pollConnect(who)
			}
		}
	}

	func pollConnect(_ who: IdentifiableHostInfo) {
		let status = CParsec.getStatus()
		connectPolls += 1

		if let err = CParsec.setupError, err.at > connectStartedAt, status == PARSEC_CONNECTING || status == CONNECT_WRN_APPROVAL {
			CParsec.setupError = nil
			appNote("[connect] sdk setup failed after \(connectPolls) polls, retried \(retryingConnect): \(err.line)")
			retryOrGiveUp(who)
			return
		}

		if status == PARSEC_CONNECTING { return } // wait

		if status == CONNECT_WRN_APPROVAL {
			if approvalStartedAt == nil {
				appNote("[connect] status \(status.rawValue) after \(connectPolls) polls, retried \(retryingConnect)")
				if connectPolls >= 20 {
					retryOrGiveUp(who)
					return
				}
			}
			let started = approvalStartedAt ?? Date()
			approvalStartedAt = started
			if !waitingForApproval { withAnimation { waitingForApproval = true } }
			if Date().timeIntervalSince(started) < 60 { return }
		}

		withAnimation {
			isConnecting = false
			waitingForApproval = false
			retryingConnect = false
		}
		appNote("[connect] result \(status.rawValue)")

		if status == PARSEC_OK {
			ParsecBackgroundManager.shared.connectionDidGoLive(peerId: who.id, hostname: hosts.first(where: { $0.id == who.id })?.hostname ?? who.hostname)
			onConnected?()
		} else {
			CParsec.disconnect()
			baseAlertText = status.readable(connecting: true)
			showBaseAlert = true
		}

		pollTask?.cancel()
	}

	func retryOrGiveUp(_ who: IdentifiableHostInfo) {
		pollTask?.cancel()
		CParsec.disconnect()
		if !retryingConnect {
			connectTo(who, retried: true)
			return
		}
		withAnimation {
			isConnecting = false
			retryingConnect = false
		}
		baseAlertText = "\(who.hostname) didn't answer the connection request"
		showBaseAlert = true
	}

	func cancelConnection() {
		appNote("[connect] cancelled")
		withAnimation {
			isConnecting = false
			waitingForApproval = false
			retryingConnect = false
		}

		CParsec.disconnect()

		pollTask?.cancel()
	}

	func logout() {
		KeychainService.remove(key: AppConstants.sessionKeyChainKey)
		SessionStore.clinfo = nil
		ParsecBackgroundManager.shared.disableAutoReconnect()
		onLogout?()
	}
}
