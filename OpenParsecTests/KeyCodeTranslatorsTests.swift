import XCTest
import ParsecSDK
@testable import OpenParsec

/// Unit tests for the key-code translation layer:
/// `KeyCodeTranslators.parsecKeyCodeTranslator`, `KeyCodeTranslators.getParsecKeycode`,
/// `KeyCodeTranslators.uiKeyCodeToInt`, and `TextKeycodeResolver.resolve`.
/// All tested functions are pure — no SDK instance or network required.
final class KeyCodeTranslatorsTests: XCTestCase {

	// MARK: - parsecKeyCodeTranslator (string → Parsec keycode)

	func testLettersMapToKeycodes() {
		// KEY_A ... KEY_Z = 4 ... 29 (parsec.h)
		for (i, c) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() {
			XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator(String(c))?.rawValue, Optional(UInt32(4 + i)), "letter \(c)")
		}
	}

	func testDigitsMapToKeycodes() {
		// KEY_1 ... KEY_0 = 30 ... 39 (parsec.h)
		for (i, c) in "1234567890".enumerated() {
			XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator(String(c))?.rawValue, Optional(UInt32(30 + i)), "digit \(c)")
		}
	}

	func testSpecialKeyNames() {
		XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator("ENTER")?.rawValue, 40)
		XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator("BACKSPACE")?.rawValue, 42)
		XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator("TAB")?.rawValue, 43)
		XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator("SPACE")?.rawValue, 44)
		XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator("F1")?.rawValue, 58)
		XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator("F12")?.rawValue, 69)
		XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator("UP")?.rawValue, 82)
		XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator("SHIFT")?.rawValue, 225)
		XCTAssertEqual(KeyCodeTranslators.parsecKeyCodeTranslator("LALT")?.rawValue, 226)
	}

	func testUnknownStringsReturnNil() {
		XCTAssertNil(KeyCodeTranslators.parsecKeyCodeTranslator(""))
		XCTAssertNil(KeyCodeTranslators.parsecKeyCodeTranslator("a")) // lowercase is not a key name
		XCTAssertNil(KeyCodeTranslators.parsecKeyCodeTranslator("AB"))
		XCTAssertNil(KeyCodeTranslators.parsecKeyCodeTranslator("hello world"))
	}

	// MARK: - getParsecKeycode (character → keycode + shift flag)

	func testUnshiftedPunctuation() {
		check("-") { $0 == 45 }
		check("=") { $0 == 46 }
		check("[") { $0 == 47 }
		check("]") { $0 == 48 }
		check("\\") { $0 == 49 }
		check(";") { $0 == 51 }
		check("'") { $0 == 52 }
		check("`") { $0 == 53 }
		check(",") { $0 == 54 }
		check(".") { $0 == 55 }
		check("/") { $0 == 56 }
	}

	func testShiftedPunctuation() {
		check("_", shift: true) { $0 == 45 }
		check("+", shift: true) { $0 == 46 }
		check("{", shift: true) { $0 == 47 }
		check("}", shift: true) { $0 == 48 }
		check("|", shift: true) { $0 == 49 }
		check(":", shift: true) { $0 == 51 }
		check("\"", shift: true) { $0 == 52 }
		check("~", shift: true) { $0 == 53 }
		check("<", shift: true) { $0 == 54 }
		check(">", shift: true) { $0 == 55 }
		check("?", shift: true) { $0 == 56 }
	}

	func testShiftedDigits() {
		check("!", shift: true) { $0 == 30 }
		check("@", shift: true) { $0 == 31 }
		check("#", shift: true) { $0 == 32 }
		check("$", shift: true) { $0 == 33 }
		check("%", shift: true) { $0 == 34 }
		check("^", shift: true) { $0 == 35 }
		check("&", shift: true) { $0 == 36 }
		check("*", shift: true) { $0 == 37 }
		check("(", shift: true) { $0 == 38 }
		check(")", shift: true) { $0 == 39 }
	}

	func testFullwidthUnicodeVariants() {
		// Fullwidth forms map to the same key as their ASCII counterpart.
		check("－") { $0 == 45 }
		check("＋", shift: true) { $0 == 46 }
		check("，") { $0 == 54 }
		check("？", shift: true) { $0 == 56 }
		check("！", shift: true) { $0 == 30 }
	}

	func testUnknownCharactersReturnMinusOne() {
		let (code, shift) = KeyCodeTranslators.getParsecKeycode(for: "")
		XCTAssertEqual(code, -1)
		XCTAssertFalse(shift)

		let (code2, _) = KeyCodeTranslators.getParsecKeycode(for: "a") // letters are not handled here
		XCTAssertEqual(code2, -1)
	}

	// MARK: - uiKeyCodeToInt (UIKeyboardHIDUsage → Parsec keycode)

	func testUIKeyCodes() {
		XCTAssertEqual(KeyCodeTranslators.uiKeyCodeToInt(key: .keyboardA), 4)
		XCTAssertEqual(KeyCodeTranslators.uiKeyCodeToInt(key: .keyboardZ), 29)
		XCTAssertEqual(KeyCodeTranslators.uiKeyCodeToInt(key: .keyboard1), 30)
		XCTAssertEqual(KeyCodeTranslators.uiKeyCodeToInt(key: .keyboard0), 39)
		XCTAssertEqual(KeyCodeTranslators.uiKeyCodeToInt(key: .keyboardReturnOrEnter), 40)
		XCTAssertEqual(KeyCodeTranslators.uiKeyCodeToInt(key: .keyboardEscape), 41)
		XCTAssertEqual(KeyCodeTranslators.uiKeyCodeToInt(key: .keyboardSpacebar), 44)
		XCTAssertEqual(KeyCodeTranslators.uiKeyCodeToInt(key: .keyboardF1), 58)
		XCTAssertEqual(KeyCodeTranslators.uiKeyCodeToInt(key: .keyboardLeftControl), 224)
		XCTAssertEqual(KeyCodeTranslators.uiKeyCodeToInt(key: .keyboardLeftShift), 225)
	}

	// MARK: - TextKeycodeResolver

	func testResolverLowercaseLetter() {
		let (keycode, useShift) = TextKeycodeResolver.resolve(text: "a")
		XCTAssertEqual(keycode?.rawValue, 4)
		XCTAssertFalse(useShift)
	}

	func testResolverUppercaseLetterUsesShift() {
		let (keycode, useShift) = TextKeycodeResolver.resolve(text: "A")
		XCTAssertEqual(keycode?.rawValue, 4)
		XCTAssertTrue(useShift)
	}

	func testResolverDigit() {
		let (keycode, useShift) = TextKeycodeResolver.resolve(text: "5")
		XCTAssertEqual(keycode?.rawValue, 34)
		XCTAssertFalse(useShift)
	}

	func testResolverNewlineAndWhitespace() {
		// \n is a newline → ENTER (40). \t and space are whitespace → SPACE (44).
		XCTAssertEqual(TextKeycodeResolver.resolve(text: "\n").keycode?.rawValue, 40)
		XCTAssertEqual(TextKeycodeResolver.resolve(text: "\t").keycode?.rawValue, 44)
		XCTAssertEqual(TextKeycodeResolver.resolve(text: " ").keycode?.rawValue, 44)
	}

	func testResolverPunctuationWithShift() {
		let (keycode, useShift) = TextKeycodeResolver.resolve(text: "?")
		XCTAssertEqual(keycode?.rawValue, 56)
		XCTAssertTrue(useShift)

		let (keycode2, useShift2) = TextKeycodeResolver.resolve(text: ",")
		XCTAssertEqual(keycode2?.rawValue, 54)
		XCTAssertFalse(useShift2)
	}

	func testResolverUnresolvableInput() {
		// Empty string: not a single character, and "" is not a key name.
		XCTAssertNil(TextKeycodeResolver.resolve(text: "").keycode)
		XCTAssertFalse(TextKeycodeResolver.resolve(text: "").useShift)

		// Multi-character text that is not a key name.
		XCTAssertNil(TextKeycodeResolver.resolve(text: "ab").keycode)
	}

	// MARK: - Helpers

	private func check(_ ch: String, shift expectedShift: Bool = false, _ condition: (Int) -> Bool) {
		let (code, keyMod) = KeyCodeTranslators.getParsecKeycode(for: ch)
		XCTAssertTrue(condition(code), "keycode for '\(ch)' should satisfy the condition, got \(code)")
		XCTAssertEqual(keyMod, expectedShift, "shift flag for '\(ch)'")
	}
}
