import Foundation
import ParsecSDK
import os

// MARK: - Stream Session State

/// Observable holder for the active stream's session metrics (resolution, bitrate, fps, output).
class StreamSessionState: ObservableObject {
	@Published var resolutionX = 0
	@Published var resolutionY = 0
	@Published var bitrate = 0
	@Published var hostDefaultBitrate = 0
	@Published var constantFps = false
	@Published var output = "none"
	@Published var displayConfigs: [ParsecDisplayConfig] = []
	@Published var isBlocked = false

	func reset() {
		resolutionX = 0
		resolutionY = 0
		bitrate = 0
		hostDefaultBitrate = 0
		constantFps = false
		output = "none"
		displayConfigs = []
		isBlocked = false
	}

	static let shared = StreamSessionState()
}

extension ParsecStatus {
	func readable(connecting: Bool = false) -> String {
		switch self {
		case WS_ERR_AUTH:               return "Authentication failed"
		case WS_ERR_CONNECT:            return "Can't reach Parsec"
		case WS_ERR_TEAM_DEACTIVATED:   return "Team account deactivated"
		case NAT_ERR_PEER_PHASE:        return "Couldn't reach the host"
		case NETWORK_ERR_BG_TIMEOUT:    return "Timed out in the background"
		case NETWORK_ERR_UNSUPPORTED:   return "Network not supported"
		case CONNECT_WRN_DECLINED:      return "Host declined the connection"
		case CONNECT_WRN_NO_PERMISSION: return "No permission to connect"
		case CONNECT_WRN_NO_ROOM:       return "Host is full"
		case CONNECT_WRN_CANCELED:      return "Connection canceled"
		case CONNECT_WRN_PEER_GONE:     return "Host is offline"
		case HOST_WRN_KICKED:           return "Kicked by the host"
		case HOST_WRN_SHUTDOWN:         return "Host shut down"
		case SERVER_ERR_DISPLAY:        return "Host has no display"
		case SERVER_ERR_RESOLUTION:     return "Host resolution problem"
		case CAPTURE_ERR_INIT:          return "Host capture failed"
		case CONNECT_WRN_APPROVAL:      return "Host didn't approve the connection"
		case CONNECT_WRN_UNCONFIRMED:   return "Confirm your Parsec account email first"
		case PARSEC_CONNECTING:         return "Still connecting to the host"
		case PARSEC_NOT_RUNNING:        return "Connection didn't start"
		case NETWORK_WRN_TIMEOUT:       return "Network timed out"
		case NETWORK_ERR_SHUTDOWN:      return "Host ended the connection"
		case NETWORK_ERR_INTERRUPTED:   return "Connection was interrupted"
		case WS_ERR_GOING_AWAY, WS_ERR_CLOSE: return "Parsec closed the connection"
		case WS_ERR_READ, WS_ERR_WRITE: return "Lost the connection to Parsec"
		case NAT_ERR_NO_CANDIDATES:     return "No network path to the host"
		case NAT_ERR_STUN_PHASE:        return "Couldn't reach Parsec's network service"
		case SERVER_ERR_NO_USER:        return "No one is signed in on the host"
		case SERVER_ERR_MAX_RESOLUTION: return "Host can't stream at this resolution"
		case SERVER_ERR_CLIENT_GONE, SERVER_ERR_CLIENT_ABORT: return "Host dropped the connection"
		default:
			os_log("%{public}@", "[status] no text for \(rawValue)")
			return "\(connecting ? "Couldn't connect" : "Disconnected") (code \(rawValue))"
		}
	}

	var isPermanentFailure: Bool {
		switch self {
		case WS_ERR_AUTH, WS_ERR_TEAM_DEACTIVATED,
			 CONNECT_WRN_DECLINED, CONNECT_WRN_NO_PERMISSION, CONNECT_WRN_NO_ROOM,
			 CONNECT_WRN_CANCELED,
			 HOST_WRN_KICKED, HOST_WRN_SHUTDOWN,
			 NETWORK_ERR_UNSUPPORTED, SERVER_ERR_DISPLAY, SERVER_ERR_RESOLUTION,
			 CONNECT_WRN_UNCONFIRMED, SERVER_ERR_NO_USER, CONNECT_WRN_APPROVAL:
			return true
		default:
			return false
		}
	}
}
