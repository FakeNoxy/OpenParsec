import Foundation

/// User profile information
struct UserInfo: Decodable {
	var id: Int
	var name: String
	var warp: Bool
	var team_id: String
}

/// Detailed user information for the authenticated user
struct SelfInfoData: Decodable {
	var id: Int
	var name: String
	var email: String
	var warp: Bool
	var staff: Bool
	var team_id: String
	var is_confirmed: Bool
	var team_is_active: Bool
	var is_saml: Bool
	var is_gateway_enabled: Bool
	var is_relay_enabled: Bool
	var has_tfa: Bool
	var cohort_channel: String
}

/// Wrapper for self info API responses
struct SelfInfo: Decodable {
	var data: SelfInfoData
}