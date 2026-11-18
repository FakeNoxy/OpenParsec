import Foundation

/// Host information for a Parsec session
struct HostInfo: Decodable {
	var user: UserInfo
	var peer_id: String
	var game_id: String
	var description: String
	var max_players: Int
	var mode: String
	var name: String
	var event_name: String
	var players: Int
	var guest_access: Bool
	var online: Bool
	var build: String
}

/// Wrapper for host list API responses
struct HostInfoList: Decodable {
	var data: [HostInfo]?
	var has_more: Bool
}