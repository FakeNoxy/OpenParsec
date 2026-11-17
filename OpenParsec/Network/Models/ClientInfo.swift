import Foundation

/// Error response from Parsec API
struct ErrorInfo: Decodable {
	var error: String
}

/// Client session information returned after authentication
struct ClientInfo: Decodable {
	var instance_id: String
	var user_id: Int
	var session_id: String
	var host_peer_id: String
}
