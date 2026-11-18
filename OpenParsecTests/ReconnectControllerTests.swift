import XCTest
import ParsecSDK
@testable import OpenParsec

/// Tests for the `ReconnectController` state machine.
///
/// **Limitations (pragmatic):**
/// - `poll(showMenu:)` requires a live `ParsecClientStatus` (an active SDK
///   connection) to exercise its full branches. Without a real host it only
///   reaches the "not running" path, which tears the connection down — so
///   `poll` is not exercised here. Full `poll` coverage needs a mockable
///   `CParsec`/`ParsecService` seam.
/// - `reconnectTo(_:)` is intentionally NOT tested: it calls
///   `CParsec.reconnect` → `connect` → `startBackgroundTask()`, which launches
///   two infinite `DispatchQueue.global()` polling loops that call the C SDK.
///   Driving that in a unit-test host is unsafe (tight C-SDK loops, no real
///   connection). It is covered by the manual regression matrix instead.
/// - `attach(viewController:contentController:)` takes a non-optional
///   `ParsecViewController`, so the tests instantiate a real (but never
///   view-loaded) `ParsecViewController`. Its `init()` is safe: it only
///   constructs the renderer view controllers (no GPU context, no view
///   hierarchy, no background loops) and the input controllers.
/// - The tests below cover the pure, SDK-free parts: initial `@Published`
///   state, the `.endedInBackground` event transition, the alert short-circuit,
///   and `attach` idempotency — establishing the test target and pattern.
final class ReconnectControllerTests: XCTestCase {

	private var controller: ReconnectController!
	private var viewController: ParsecViewController!

	override func setUp() {
		super.setUp()
		controller = ReconnectController()
		// A real (never view-loaded) view controller satisfies the non-optional
		// `attach` parameter. Safe: `ParsecViewController.init()` only constructs
		// the renderer + input controllers; it does not start any background work.
		viewController = ParsecViewController()
	}

	override func tearDown() {
		controller = nil
		viewController = nil
		super.tearDown()
	}

	// MARK: - Initial state

	func testInitialState() {
		XCTAssertEqual(controller.metricInfo, "Loading...")
		XCTAssertFalse(controller.showDCAlert)
		XCTAssertEqual(controller.DCAlertText, "Disconnected (reason unknown)")
		XCTAssertFalse(controller.isReconnecting)
		XCTAssertFalse(controller.connectionLost)
		XCTAssertFalse(controller.waitingForNetwork)
		XCTAssertFalse(controller.waitingForStream)
	}

	// MARK: - endedInBackground event transition

	func testEndedInBackgroundEventSetsReconnecting() {
		// Wire the controller to the event bus.
		controller.attach(viewController: viewController, contentController: nil)

		XCTAssertFalse(controller.isReconnecting)
		XCTAssertFalse(controller.showDCAlert)
		XCTAssertFalse(controller.waitingForNetwork)

		ParsecBackgroundManager.shared.emit(.endedInBackground)

		XCTAssertTrue(controller.isReconnecting)
		XCTAssertFalse(controller.waitingForStream)
	}

	func testEndedInBackgroundIsNoOpWhenAlertShown() {
		controller.attach(viewController: viewController, contentController: nil)
		// Pre-set the disconnect alert; the handler should not flip isReconnecting.
		controller.showDCAlert = true
		controller.isReconnecting = false

		ParsecBackgroundManager.shared.emit(.endedInBackground)

		XCTAssertFalse(controller.isReconnecting)
		XCTAssertTrue(controller.showDCAlert)
	}

	func testEndedInBackgroundIsNoOpWhenWaitingForNetwork() {
		controller.attach(viewController: viewController, contentController: nil)
		controller.waitingForNetwork = true
		controller.isReconnecting = false

		ParsecBackgroundManager.shared.emit(.endedInBackground)

		XCTAssertFalse(controller.isReconnecting)
	}

	// MARK: - attach idempotency

	func testAttachIsIdempotent() {
		// Attaching twice must not duplicate the event handler.
		controller.attach(viewController: viewController, contentController: nil)
		controller.attach(viewController: viewController, contentController: nil)

		ParsecBackgroundManager.shared.emit(.endedInBackground)

		// isReconnecting should be true (processed exactly once).
		XCTAssertTrue(controller.isReconnecting)
	}
}
