import Foundation

/// Simple holder for client session info (renamed from `NetworkHandler`).
///
/// Thread-safety: `clinfo` is written from main-actor view models and read
/// from `APIClient.perform()` (a nonisolated async function that may run off-
/// the main executor). The `NSLock` prevents a data race on the reference.
class SessionStore {
	private static let lock = NSLock()
	private static var _clinfo: ClientInfo?

	public static var clinfo: ClientInfo? {
		get { lock.lock(); defer { lock.unlock() }; return _clinfo }
		set { lock.lock(); defer { lock.unlock() }; _clinfo = newValue }
	}
}
