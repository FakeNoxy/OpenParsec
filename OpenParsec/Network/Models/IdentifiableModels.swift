import Foundation

/// Identifiable wrappers over the API models for SwiftUI `List`/`ForEach`.
struct IdentifiableHostInfo: Identifiable {
	var id: String // Peer ID
	var hostname: String // Computer's Display Name
	var user: UserInfo // User Data
	var connections: Int // User's Connected To This Host
}

struct IdentifiableUserInfo: Identifiable {
	var id: Int // User ID
	var username: String // User Display Name
}

enum Page {
	case hosts
	case friends
}
