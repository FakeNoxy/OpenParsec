import XCTest
@testable import OpenParsec

/// Tests for `SettingsStore` set/get round-trip and registered defaults.
///
/// **Limitation:** `SettingsStore` is a singleton backed by
/// `UserDefaults.standard` (not injectable). Tests therefore mutate the real
/// standard defaults and restore the previous values in `tearDown` so they
/// don't leak into other tests or the host app's persisted state.
final class SettingsStoreTests: XCTestCase {

	private let store = SettingsStore.shared

	// Snapshot of the keys we touch, restored in tearDown.
	private var saved: [String: Any?] = [:]
	private let touchedKeys = [
		"rendererChoice", "bitrate", "cursorScale", "optionAsCommand",
		"reverseScrollDirection", "scrollSensitivity", "preferredFramesPerSecond"
	]

	override func setUp() {
		super.setUp()
		let d = UserDefaults.standard
		for key in touchedKeys {
			saved[key] = d.object(forKey: key)
		}
	}

	override func tearDown() {
		let d = UserDefaults.standard
		for key in touchedKeys {
			if let value = saved[key] {
				d.set(value, forKey: key)
			} else {
				d.removeObject(forKey: key)
			}
		}
		saved = [:]
		super.tearDown()
	}

	// MARK: - Round-trip (set → read back)

	func testRendererRoundTrip() {
		store.renderer = .opengl
		XCTAssertEqual(store.renderer, .opengl)
		store.renderer = .metal
		XCTAssertEqual(store.renderer, .metal)
	}

	func testBitrateRoundTrip() {
		store.bitrate = 12345
		XCTAssertEqual(store.bitrate, 12345)
		store.bitrate = 0
		XCTAssertEqual(store.bitrate, 0)
	}

	func testCursorScaleRoundTrip() {
		store.cursorScale = 0.75
		XCTAssertEqual(store.cursorScale, 0.75)
	}

	func testBoolRoundTrip() {
		store.optionAsCommand = true
		XCTAssertTrue(store.optionAsCommand)
		store.optionAsCommand = false
		XCTAssertFalse(store.optionAsCommand)

		store.reverseScrollDirection = true
		XCTAssertTrue(store.reverseScrollDirection)
	}

	func testScrollSensitivityRoundTrip() {
		store.scrollSensitivity = 2.5
		XCTAssertEqual(store.scrollSensitivity, 2.5)
	}

	func testPreferredFramesPerSecondRoundTrip() {
		store.preferredFramesPerSecond = 144
		XCTAssertEqual(store.preferredFramesPerSecond, 144)
	}

	// MARK: - Defaults (registered values)

	/// Remove the touched keys so the registered defaults surface, then verify
	/// they match the values registered in `SettingsStore.init`.
	private func assertDefaults() {
		UserDefaults.standard.removeObject(forKey: "rendererChoice")
		UserDefaults.standard.removeObject(forKey: "bitrate")
		UserDefaults.standard.removeObject(forKey: "cursorScale")
		UserDefaults.standard.removeObject(forKey: "optionAsCommand")
		UserDefaults.standard.removeObject(forKey: "reverseScrollDirection")
		UserDefaults.standard.removeObject(forKey: "scrollSensitivity")
		UserDefaults.standard.removeObject(forKey: "preferredFramesPerSecond")

		XCTAssertEqual(store.renderer, .metal)            // registered default
		XCTAssertEqual(store.bitrate, 0)
		XCTAssertEqual(store.cursorScale, 0.5)
		XCTAssertFalse(store.optionAsCommand)
		XCTAssertFalse(store.reverseScrollDirection)
		XCTAssertEqual(store.scrollSensitivity, 1.5)
		XCTAssertEqual(store.preferredFramesPerSecond, 60)
	}

	func testRegisteredDefaults() {
		assertDefaults()
	}

	func testSetThenResetToDefault() {
		// Set a non-default value…
		store.renderer = .opengl
		XCTAssertEqual(store.renderer, .opengl)
		// …then clear it so the registered default (.metal) returns.
		UserDefaults.standard.removeObject(forKey: "rendererChoice")
		XCTAssertEqual(store.renderer, .metal)
	}
}
