import Foundation

/// Typed endpoints for the Parsec API.
/// All methods use `APIClient.shared` and read the session token from `SessionStore`.
struct ParsecAPI {
	static let shared = ParsecAPI()

	/// POST /v1/auth — succeeds with 201.
	/// Returns the raw body so the caller can persist it to the keychain unchanged
	/// (matching the old inline behavior of saving the exact 201 response bytes).
	/// Throws `APIError.http(status: 4xx, data: ...)` on failure — decode `data` as
	/// `ErrorInfo` / inspect the `tfa_required` field.
	func authenticate(email: String, password: String, tfa: String? = nil) async throws -> (status: Int, data: Data) {
		try await APIClient.shared.raw(
			"v1/auth",
			method: "POST",
			body: ["email": email, "password": password, "tfa": tfa],
			auth: false
		)
	}

	/// GET /v2/hosts?mode=desktop&public=false
	func hosts() async throws -> APIResponse<HostInfoList> {
		try await APIClient.shared.data("v2/hosts?mode=desktop&public=false")
	}

	/// GET /me
	func selfInfo() async throws -> APIResponse<SelfInfo> {
		try await APIClient.shared.data("me")
	}

	/// GET /friendships
	func friends() async throws -> APIResponse<FriendInfoList> {
		try await APIClient.shared.data("friendships")
	}
}
