import ParsecSDK
import Foundation

/// Resolves virtual-keyboard text input to a Parsec keycode plus a "needs
/// shift" flag. Extracted from `ParsecSDKBridge.getKeyCodeByText` so the
/// bridge stays focused on transport.
enum TextKeycodeResolver {
	static func resolve(text: String) -> (keycode: ParsecKeycode?, useShift: Bool) {
		var keyCode: ParsecKeycode?
		var useShift = false
		if text.count == 1 {
			let char = Character(text)
			if char.isLetter || char.isNumber {
				keyCode = KeyCodeTranslators.parsecKeyCodeTranslator(text.uppercased())
				if char.isUppercase {
					useShift = true
				}
			} else if char.isNewline {
				keyCode = ParsecKeycode(40)
			} else if char.isWhitespace {
				keyCode = ParsecKeycode(44)
			} else {
				let (keycodeRaw, keyMod) = KeyCodeTranslators.getParsecKeycode(for: text)
				if keycodeRaw != -1 {
					keyCode = ParsecKeycode(UInt32(keycodeRaw))
					if keyMod {
						useShift = true
					}
				}
			}
		} else {
			keyCode = KeyCodeTranslators.parsecKeyCodeTranslator(text)
		}

		return (keyCode, useShift)
	}
}
