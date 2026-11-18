import SwiftUI
import os

/// Owns the login flow: authenticate + session restore.
/// `LoginView` is UI-only; all logic lives here.
@MainActor
final class LoginViewModel: ObservableObject {
	@Published var isLoading = false
	@Published var presentTFAAlert = false
	@Published var showAlert = false
	@Published var alertText = ""

	/// Invoked after a successful login so the caller can navigate to the main screen.
	var onAuthenticated: (() -> Void)?

	/// Restores a saved session from the keychain (moved from `ContentView.initApp`).
	/// Returns `true` when a session was restored.
	func restore() -> Bool {
		if let data = KeychainService.load(key: AppConstants.sessionKeyChainKey) {
			let decoder = JSONDecoder()

			print("Retrieved data from keychain: \(data).\nTrying to restore session.")
			SessionStore.clinfo = try? decoder.decode(ClientInfo.self, from: data)
			if SessionStore.clinfo != nil {
				let status = SecItemUpdate([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: AppConstants.sessionKeyChainKey] as CFDictionary, [kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock] as CFDictionary)
				if status != errSecSuccess {
					os_log("%{public}@", log: appLog, "[session] keychain update \(status)")
				}
				print("Session restored and moved to the main page.")
				return true
			} else {
				print("Unable to restore session, falling back to login page.")
			}
		}

		print("Initialized")
		return false
	}

	/// Authenticates and, on success, persists the session and fires `onAuthenticated`.
	func authenticate(email: String, password: String, tfa: String? = nil) {
		withAnimation { isLoading = true }

		Task { @MainActor in
			defer { isLoading = false }

			do {
				let (status, data) = try await ParsecAPI.shared.authenticate(email: email, password: password, tfa: tfa)

				if status == 201 { // 201 Created
					// store it and recover it from the next app opening, so people won't swear
					guard let info: ClientInfo = try? JSONDecoder().decode(ClientInfo.self, from: data) else {
						alertText = "Bad response from the server"
						showAlert = true
						return
					}
					SessionStore.clinfo = info

					KeychainService.save(data, key: AppConstants.sessionKeyChainKey)

					print("*** Login succeeded! ***")
					onAuthenticated?()
				} else {
					// Unexpected non-201 success status
					alertText = "Login failed (HTTP \(status))"
					showAlert = true
				}
			} catch let APIError.http(status, data) {
				// 4XX client errors
				guard let info: ErrorInfo = try? JSONDecoder().decode(ErrorInfo.self, from: data) else {
					alertText = "Login failed (HTTP \(status))"
					showAlert = true
					return
				}

				let json = try? JSONSerialization.jsonObject(with: data, options: [])
				if let dict = json as? [String: Any], let isTFARequired = dict["tfa_required"] as? Bool {
					print("Code output:")
					print(dict)
					if isTFARequired {
						presentTFAAlert = true
					} else {
						alertText = "Error: \(info)"
						showAlert = true
					}
				} else {
					alertText = info.error
					showAlert = true
				}
			} catch let APIError.transport(underlying) {
				alertText = underlying.localizedDescription
				showAlert = true
			} catch {
				alertText = "Could not reach the server"
				showAlert = true
			}
		}
	}
}
