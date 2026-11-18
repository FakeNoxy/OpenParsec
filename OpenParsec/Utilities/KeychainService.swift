import Foundation
import UIKit
import os

/// Single owner for keychain access (save / load / remove).
/// Replaces the three inline `SecItem*` implementations that used to live in
/// `ContentView`, `LoginView`, and `MainView`.
enum KeychainService {
	/// Saves `data` under `key`. Deletes any existing item first (matching the old behavior).
	static func save(_ data: Data, key: String) {
		SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary)
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: key,
			kSecValueData as String: data,
			kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
		]
		let status = SecItemAdd(query as CFDictionary, nil)
		guard status == errSecSuccess else {
			print("Error saving to Keychain: \(status)")
			return
		}
		print("Data saved to Keychain.")
	}

	/// Loads the data stored under `key`, or `nil` if none exists.
	static func load(key: String) -> Data? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: key,
			kSecReturnData as String: kCFBooleanTrue!,
			kSecMatchLimit as String: kSecMatchLimitOne
		]
		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		guard status == errSecSuccess else {
			if status != errSecItemNotFound {
				print("Error loading from keychain: \(status)")
			}
			os_log("%{public}@", log: appLog, "[session] keychain read \(status) protected=\(UIApplication.shared.isProtectedDataAvailable)")
			return nil
		}
		guard let data = item as? Data else {
			return nil
		}
		return data
	}

	/// Removes the item stored under `key`.
	static func remove(key: String) {
		let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
		let status = SecItemDelete(query as CFDictionary)
		if status == errSecSuccess {
			print("Successfully removed data from keychain.")
		}
	}
}
