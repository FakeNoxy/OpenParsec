import XCTest
import ParsecSDK
@testable import OpenParsec

/// Unit tests for `CursorPositionHelper.toHost` / `toClient` (pure coordinate
/// math). The helper reads `CParsec.hostWidth/Height` and `clientWidth/Height`,
/// so a `ParsecSDKBridge` must be installed first (`CParsec.initialize()`).
///
/// With the bridge's default dimensions (host 1920×1080, client 1920×1080)
/// the aspect ratio is 16:9 in both directions, so the conversion is a
/// 1:1 identity plus clamping to the host/client bounds.
final class CursorPositionHelperTests: XCTestCase {

	override func setUp() {
		super.setUp()
		// Install the SDK bridge so CParsec.hostWidth/clientWidth are valid.
		// Default dimensions: host 1920×1080, client 1920×1080.
		CParsec.initialize()
	}

	override func tearDown() {
		CParsec.destroy()
		super.tearDown()
	}

	// MARK: - toHost (client → host coordinates)

	func testToHostIdentityWhenAspectMatches() {
		// 16:9 == 16:9, so client coords map 1:1 to host coords.
		let (x, y) = CursorPositionHelper.toHost(100, 50)
		XCTAssertEqual(x, 100)
		XCTAssertEqual(y, 50)
	}

	func testToHostOrigin() {
		let (x, y) = CursorPositionHelper.toHost(0, 0)
		XCTAssertEqual(x, 0)
		XCTAssertEqual(y, 0)
	}

	func testToHostCenter() {
		let (x, y) = CursorPositionHelper.toHost(960, 540)
		XCTAssertEqual(x, 960)
		XCTAssertEqual(y, 540)
	}

	func testToHostClampsToHostBounds() {
		// Out-of-bounds client coords are clamped to [0, hostWidth/Height].
		let (x, y) = CursorPositionHelper.toHost(5000, 5000)
		XCTAssertEqual(x, 1920)
		XCTAssertEqual(y, 1080)
	}

	func testToHostClampsNegativeToZero() {
		let (x, y) = CursorPositionHelper.toHost(-10, -10)
		XCTAssertEqual(x, 0)
		XCTAssertEqual(y, 0)
	}

	// MARK: - toClient (host → client coordinates)

	func testToClientIdentityWhenAspectMatches() {
		let (x, y) = CursorPositionHelper.toClient(100, 50)
		XCTAssertEqual(x, 100)
		XCTAssertEqual(y, 50)
	}

	func testToClientOrigin() {
		let (x, y) = CursorPositionHelper.toClient(0, 0)
		XCTAssertEqual(x, 0)
		XCTAssertEqual(y, 0)
	}

	func testToClientClampsToClientBounds() {
		let (x, y) = CursorPositionHelper.toClient(5000, 5000)
		XCTAssertEqual(x, 1920)
		XCTAssertEqual(y, 1080)
	}

	func testToClientClampsNegativeToZero() {
		let (x, y) = CursorPositionHelper.toClient(-10, -10)
		XCTAssertEqual(x, 0)
		XCTAssertEqual(y, 0)
	}

	// MARK: - Round-trip

	func testRoundTripHostToClientToHost() {
		let (cx, cy) = CursorPositionHelper.toHost(123, 45)
		let (hx, hy) = CursorPositionHelper.toClient(cx, cy)
		XCTAssertEqual(hx, 123)
		XCTAssertEqual(hy, 45)
	}

	func testRoundTripClientToHostToClient() {
		let (hx, hy) = CursorPositionHelper.toClient(67, 89)
		let (cx, cy) = CursorPositionHelper.toHost(hx, hy)
		XCTAssertEqual(cx, 67)
		XCTAssertEqual(cy, 89)
	}
}
