import XCTest
import ParsecSDK
@testable import OpenParsec

/// Regression tests for the features merged in from upstream/main:
/// - PR #124 connection diagnostics: `ConnectionAttemptPolicy`, `ParsecStatus`
///   helpers (`isPeerConnectionFailure`, `isLocalNetworkFailure`,
///   `connectionMessage`, `isPermanentFailure`)
/// - PR #135 clipboard sync: `ParsecUserDataType.clipboard`, the
///   `SettingsStore.clipboardSync` setting, and `ClipboardSync.receive` gating
///
/// All tested code is pure or gated by a setting — no SDK session required.
final class UpstreamFeatureTests: XCTestCase {

	// MARK: - PR #124: ConnectionAttemptPolicy

	func testFreshPolicyHasNotTimedOut() {
		let policy = ConnectionAttemptPolicy()
		XCTAssertFalse(policy.timedOut)
	}

	func testTickWhileActiveCountsPolls() {
		var policy = ConnectionAttemptPolicy()
		XCTAssertTrue(policy.tick(isActive: true))
		XCTAssertTrue(policy.tick(isActive: true))
		XCTAssertFalse(policy.timedOut)
	}

	func testTickWhileInactiveDoesNotCount() {
		var policy = ConnectionAttemptPolicy()
		XCTAssertFalse(policy.tick(isActive: false))
		XCTAssertFalse(policy.tick(isActive: false))
		XCTAssertFalse(policy.timedOut)
	}

	func testPolicyTimesOutAfterTimeoutPolls() {
		var policy = ConnectionAttemptPolicy()
		for _ in 0..<ConnectionAttemptPolicy.timeoutPolls {
			_ = policy.tick(isActive: true)
		}
		XCTAssertTrue(policy.timedOut)
	}

	func testPolicyResetsWhenReplaced() {
		var policy = ConnectionAttemptPolicy()
		for _ in 0..<ConnectionAttemptPolicy.timeoutPolls {
			_ = policy.tick(isActive: true)
		}
		XCTAssertTrue(policy.timedOut)
		policy = ConnectionAttemptPolicy()
		XCTAssertFalse(policy.timedOut)
	}

	func testShouldRetryOnlyOnceForPeerFailures() {
		XCTAssertTrue(ConnectionAttemptPolicy.shouldRetry(isPeerFailure: true, alreadyRetried: false))
		XCTAssertFalse(ConnectionAttemptPolicy.shouldRetry(isPeerFailure: true, alreadyRetried: true))
	}

	func testShouldNotRetryNonPeerFailures() {
		XCTAssertFalse(ConnectionAttemptPolicy.shouldRetry(isPeerFailure: false, alreadyRetried: false))
	}

	// MARK: - PR #124: ParsecStatus diagnostics helpers

	func testPeerConnectionFailures() {
		XCTAssertTrue(NAT_ERR_PEER_PHASE.isPeerConnectionFailure)
		XCTAssertTrue(NAT_ERR_NO_CANDIDATES.isPeerConnectionFailure)
		XCTAssertTrue(NAT_ERR_STUN_PHASE.isPeerConnectionFailure)
		XCTAssertFalse(WS_ERR_AUTH.isPeerConnectionFailure)
	}

	func testLocalNetworkFailures() {
		XCTAssertTrue(NAT_ERR_PEER_PHASE.isLocalNetworkFailure)
		XCTAssertTrue(NAT_ERR_NO_CANDIDATES.isLocalNetworkFailure)
		XCTAssertFalse(NAT_ERR_STUN_PHASE.isLocalNetworkFailure)
		XCTAssertFalse(WS_ERR_AUTH.isLocalNetworkFailure)
	}

	func testConnectionMessageContainsStatusCode() {
		XCTAssertTrue(WS_ERR_AUTH.connectionMessage(connecting: true).contains("(code \(WS_ERR_AUTH.rawValue))"))
	}

	func testConnectionMessageAddsLanHelpOnlyForLocalNetworkFailures() {
		let lan = NAT_ERR_PEER_PHASE.connectionMessage(connecting: true)
		XCTAssertTrue(lan.contains("Local Network"))
		XCTAssertTrue(lan.contains("allow OpenParsec in Settings"))

		let nonLan = WS_ERR_AUTH.connectionMessage(connecting: true)
		XCTAssertFalse(nonLan.contains("Local Network"))
	}

	func testConnectionMessageOmitsLanHelpWhenNotConnecting() {
		XCTAssertFalse(NAT_ERR_PEER_PHASE.connectionMessage(connecting: false).contains("Local Network"))
	}

	func testPermanentFailures() {
		for status in [WS_ERR_AUTH, WS_ERR_TEAM_DEACTIVATED,
					   CONNECT_WRN_DECLINED, CONNECT_WRN_NO_PERMISSION,
					   CONNECT_WRN_NO_ROOM, CONNECT_WRN_CANCELED,
					   HOST_WRN_KICKED, HOST_WRN_SHUTDOWN,
					   NETWORK_ERR_UNSUPPORTED, SERVER_ERR_DISPLAY,
					   SERVER_ERR_RESOLUTION, CONNECT_WRN_UNCONFIRMED,
					   SERVER_ERR_NO_USER, CONNECT_WRN_APPROVAL] {
			XCTAssertTrue(status.isPermanentFailure, "\(status.rawValue) should be permanent")
		}
		for status in [PARSEC_OK, PARSEC_CONNECTING,
					   NAT_ERR_PEER_PHASE, NETWORK_ERR_SHUTDOWN] {
			XCTAssertFalse(status.isPermanentFailure, "\(status.rawValue) should not be permanent")
		}
	}

	// MARK: - PR #135: clipboard sync plumbing

	func testClipboardUserDataTypeId() {
		XCTAssertEqual(ParsecUserDataType.clipboard.rawValue, 7)
	}

	func testClipboardSyncSettingDefaultsOff() {
		UserDefaults.standard.removeObject(forKey: "clipboardSync")
		XCTAssertFalse(SettingsStore.shared.clipboardSync)
	}

	func testClipboardSyncSettingRoundTrip() {
		SettingsStore.shared.clipboardSync = true
		XCTAssertTrue(SettingsStore.shared.clipboardSync)
	}

	func testReceiveIsGatedBySetting() {
		let sentinel = "sentinel-\(UUID().uuidString)"
		UIPasteboard.general.string = sentinel
		SettingsStore.shared.clipboardSync = false

		ClipboardSync.shared.receive("should-not-apply")
		pumpMainQueue()

		XCTAssertEqual(UIPasteboard.general.string, sentinel)
	}

	func testReceiveAppliesTextWhenEnabled() {
		let incoming = "from-host-\(UUID().uuidString)"
		SettingsStore.shared.clipboardSync = true

		ClipboardSync.shared.receive(incoming)
		pumpMainQueue()

		XCTAssertEqual(UIPasteboard.general.string, incoming)
	}

	// MARK: - Helpers

	private var clipboardSettingBefore: Bool?

	override func setUp() {
		super.setUp()
		clipboardSettingBefore = SettingsStore.shared.clipboardSync
	}

	override func tearDown() {
		if let before = clipboardSettingBefore {
			SettingsStore.shared.clipboardSync = before
		}
		super.tearDown()
	}

	/// Wait for `DispatchQueue.main.async` work to drain.
	private func pumpMainQueue() {
		let expectation = expectation(description: "main queue drained")
		DispatchQueue.main.async { expectation.fulfill() }
		wait(for: [expectation], timeout: 2)
	}
}
