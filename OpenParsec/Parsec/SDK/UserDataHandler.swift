import ParsecSDK
import Foundation

/// Decodes host user-data events (video config, display list) from the SDK
/// event buffer. Extracted from `ParsecSDKBridge.handleUserDataEvent` so the
/// bridge stays focused on transport.
final class UserDataHandler {
	private let parsec: OpaquePointer
	private var didSetResolution = false

	init(_ parsec: OpaquePointer) {
		self.parsec = parsec
	}

	/// Reset the "first config received" latch. Called by the bridge on
	/// reconnect, matching the old `didSetResolution = false` in `reconnect()`.
	func resetResolutionLatch() {
		didSetResolution = false
	}

	func handle(event: ParsecClientUserDataEvent) {
		let pointer = ParsecGetBuffer(self.parsec, event.key)
		if pointer == nil {
			return
		}
		switch event.id {
		case ParsecUserDataType.clipboard.rawValue:
			ClipboardSync.shared.receive(String(cString: pointer!.assumingMemoryBound(to: CChar.self)))
		case 11:
			do {
				let decoder = JSONDecoder()
				let config = try decoder.decode(ParsecUserDataVideoConfig.self, from: Data(bytesNoCopy: pointer!, count: strlen(pointer!), deallocator: .none))
				let videoConfig = config.video.first
				DispatchQueue.main.async {
					if let cfg = videoConfig {
						StreamSessionState.shared.resolutionX = cfg.resolutionX
						StreamSessionState.shared.resolutionY = cfg.resolutionY
						StreamSessionState.shared.bitrate = cfg.encoderMaxBitrate
						StreamSessionState.shared.constantFps = cfg.fullFPS
					}
					if !self.didSetResolution {
						self.didSetResolution = true
						if StreamSessionState.shared.hostDefaultBitrate == 0 {
							StreamSessionState.shared.hostDefaultBitrate = StreamSessionState.shared.bitrate
						}
						StreamSessionState.shared.resolutionX = SettingsStore.shared.resolution.width
						StreamSessionState.shared.resolutionY = SettingsStore.shared.resolution.height
						StreamSessionState.shared.constantFps = SettingsStore.shared.constantFps
						if SettingsStore.shared.bitrate > 0 {
							StreamSessionState.shared.bitrate = SettingsStore.shared.bitrate
						}
						CParsec.updateHostVideoConfig()
					}
				}

			} catch {
				print("error while parsing user data: \(error.localizedDescription)")
			}
		case 12:
			do {
				let decoder = JSONDecoder()
				let config = try decoder.decode(Array<ParsecDisplayConfig>.self, from: Data(bytesNoCopy: pointer!, count: strlen(pointer!), deallocator: .none))
				DispatchQueue.main.async {
					StreamSessionState.shared.displayConfigs = config
				}
			} catch {
				print("error while parsing user data: \(error.localizedDescription)")
			}
		default:
			break
		}

		ParsecFree(pointer)
	}
}
