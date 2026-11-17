import Foundation

/// Friend information from the Parsec API
struct FriendInfo: Decodable {
	var user_id: Int
	var user_name: String
}

/// Wrapper for friend list API responses
struct FriendInfoList: Decodable {
	var data: [FriendInfo]?
	var has_more: Bool
}