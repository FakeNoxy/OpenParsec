import SwiftUI
import ParsecSDK
import Foundation

extension MainView {
	func initView() {
		lastHostShown = ParsecBackgroundManager.shared.lastPeerId != nil ? ParsecBackgroundManager.shared.lastHostname : nil
		refreshHosts()
		refreshSelf()
		refreshFriends()

		ParsecBackgroundManager.shared.onShouldReconnect = { peerId in
			if let host = hosts.first(where: { $0.id == peerId }) {
				connectTo(host)
			} else {
				refreshHosts()
			}
		}

		NetworkWatcher.shared.onReturn = {
			guard NetworkHandler.clinfo != nil, !ParsecBackgroundManager.shared.hasActiveConnection else { return }
			refreshHosts()
			refreshFriends()
		}
		NetworkWatcher.shared.start()

		ParsecBackgroundManager.shared.onShortcutReconnect = {
			if !isConnecting { reconnectLastHost() }
		}
		let pending = ParsecBackgroundManager.shared.reconnectPending
		ParsecBackgroundManager.shared.reconnectPending = false

		NetworkWatcher.shared.whenKnown {
			if (SettingsHandler.autoConnectOnLaunch && ParsecBackgroundManager.shared.resumeOnLaunch || pending) && !isConnecting && !ParsecBackgroundManager.shared.hasActiveConnection, ParsecBackgroundManager.shared.lastPeerId != nil {
				reconnectLastHost()
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
		withAnimation {
			isRefreshing = true

			let clinfo = NetworkHandler.clinfo
			if clinfo == nil {
				isRefreshing = false
				sessionExpired = true
				return
			}

			let apiURL = URL(string: "https://kessel-api.parsec.app/v2/hosts?mode=desktop&public=false")!

			var request = URLRequest(url: apiURL)
			request.httpMethod = "GET"
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			request.setValue("Bearer \(clinfo!.session_id)", forHTTPHeaderField: "Authorization")
			request.setValue("parsec/150-93b Windows/11 libmatoya/4.0", forHTTPHeaderField: "User-Agent")

			let task = URLSession.shared.dataTask(with: request) { (data, response, _) in
				DispatchQueue.main.async {
					defer { isRefreshing = false }

					if let data = data {
						guard let statusCode = (response as? HTTPURLResponse)?.statusCode else { return }
						if statusCode == 401 {
							refreshError = nil
							sessionExpired = true
							return
						}
						let decoder = JSONDecoder()

						if statusCode == 200 { // 200 OK
							sessionExpired = false
							guard let info: HostInfoList = try? decoder.decode(HostInfoList.self, from: data) else {
								refreshError = "Couldn't refresh hosts: bad response"
								return
							}
							refreshError = nil
							hosts.removeAll()
							if let datas = info.data {
								datas.forEach { h in
									hosts.append(IdentifiableHostInfo(id: h.peer_id, hostname: h.name, user: h.user, connections: h.players))
								}
							}
							if let lastId = ParsecBackgroundManager.shared.lastPeerId, let current = hosts.first(where: { $0.id == lastId }), current.hostname != ParsecBackgroundManager.shared.lastHostname {
								ParsecBackgroundManager.shared.lastHostname = current.hostname
								if lastHostShown != nil { lastHostShown = current.hostname }
							}

							var grammar: String = "hosts"
							if hosts.count == 1 {
								grammar = "host"
							}

							hostCountStr = "\(hosts.count) \(grammar)"

							let formatter = DateFormatter()
							formatter.dateStyle = .short
							formatter.timeStyle = .short
							refreshTime = "Last refreshed at \(formatter.string(from: Date()))"
						} else if statusCode == 403, let info: ErrorInfo = try? decoder.decode(ErrorInfo.self, from: data) { // 403 Forbidden
							refreshError = "Couldn't refresh hosts: \(info.error)"
						} else {
							refreshError = "Couldn't refresh hosts (HTTP \(statusCode))"
						}
					} else {
						refreshError = "Can't reach Parsec"
					}
				}
			}
			task.resume()
		}
	}

	func refreshSelf() {
		withAnimation {
			let clinfo = NetworkHandler.clinfo
			if clinfo == nil {
				return
			}

			let apiURL = URL(string: "https://kessel-api.parsec.app/me")!

			var request = URLRequest(url: apiURL)
			request.httpMethod = "GET"
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			request.setValue("Bearer \(clinfo!.session_id)", forHTTPHeaderField: "Authorization")
			request.setValue("parsec/150-93b Windows/11 libmatoya/4.0", forHTTPHeaderField: "User-Agent")

			let task = URLSession.shared.dataTask(with: request) { (data, response, _) in
				DispatchQueue.main.async {
					if let data = data {
						guard let statusCode = (response as? HTTPURLResponse)?.statusCode else { return }
						if statusCode == 401 {
							sessionExpired = true
							return
						}
						let decoder = JSONDecoder()

						if statusCode == 200 { // 200 OK
							guard let selfInfo = try? decoder.decode(SelfInfo.self, from: data) else { return }
							userInfo = IdentifiableUserInfo(id: selfInfo.data.id, username: selfInfo.data.name)
						} else {
							guard let info: ErrorInfo = try? decoder.decode(ErrorInfo.self, from: data) else { return }

							baseAlertText = "Error gathering user info: \(info.error)"
							showBaseAlert = true
						}
					}
				}
			}
			task.resume()
		}
	}

	func refreshFriends() {
		withAnimation {
			let clinfo = NetworkHandler.clinfo
			if clinfo == nil {
				return
			}

			let apiURL = URL(string: "https://kessel-api.parsec.app/friendships")!

			var request = URLRequest(url: apiURL)
			request.httpMethod = "GET"
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			request.setValue("Bearer \(clinfo!.session_id)", forHTTPHeaderField: "Authorization")
			request.setValue("parsec/150-93b Windows/11 libmatoya/4.0", forHTTPHeaderField: "User-Agent")

			let task = URLSession.shared.dataTask(with: request) { (data, response, _) in
				DispatchQueue.main.async {
					if let data = data {
						guard let statusCode = (response as? HTTPURLResponse)?.statusCode else { return }
						if statusCode == 401 {
							sessionExpired = true
							return
						}
						let decoder = JSONDecoder()

						if statusCode == 200 { // 200 OK
							guard let info: FriendInfoList = try? decoder.decode(FriendInfoList.self, from: data) else { return }
							friends.removeAll()
							if let datas = info.data {
								datas.forEach { f in
									friends.append(IdentifiableUserInfo(id: f.user_id, username: f.user_name))
								}
							}

							var grammar: String = "friends"
							if friends.count == 1 {
								grammar = "friend"
							}

							friendCountStr = "\(friends.count) \(grammar)"
						} else {
							guard let info: ErrorInfo = try? decoder.decode(ErrorInfo.self, from: data) else { return }

							baseAlertText = "Error gathering friends: \(info.error)"
							showBaseAlert = true
						}
					}
				}
			}
			task.resume()
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

		pollTimer?.invalidate()
		pollTimer = nil
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

		// Polling status
		pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
			MainActor.assumeIsolated {
				pollConnect(who)
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
			if let c = controller {
				c.setView(.parsec)
			}
		} else {
			CParsec.disconnect()
			baseAlertText = status.readable(connecting: true)
			showBaseAlert = true
		}

		pollTimer?.invalidate()
	}

	func retryOrGiveUp(_ who: IdentifiableHostInfo) {
		pollTimer?.invalidate()
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

		pollTimer?.invalidate()
	}

	func logout() {
		removeFromKeychain(key: AppConstants.sessionKeyChainKey)
		NetworkHandler.clinfo = nil
		ParsecBackgroundManager.shared.disableAutoReconnect()
		if let c = controller {
			c.setView(.login)
		}
	}

	func removeFromKeychain(key: String) {
		let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
		let status = SecItemDelete(query as CFDictionary)
		if status == errSecSuccess {
			print("Successfully removed data from keychain.")
		}
	}
}

struct MainView_Previews: PreviewProvider {
	static var previews: some View {
		MainView(nil)
	}
}
