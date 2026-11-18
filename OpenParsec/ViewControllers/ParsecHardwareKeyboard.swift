import UIKit
import ParsecSDK

extension ParsecViewController {
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		for press in presses {
			guard let key = press.key else { continue }

			if key.keyCode == .keyboardLeftAlt || key.keyCode == .keyboardRightAlt {
				altKeyHeld = true
			}

			if SettingsStore.shared.optionAsCommand && !isModifierKey(key.keyCode) && (altKeyHeld || key.modifierFlags.contains(.alternate)) {
				if !optCmdRemapActive {
					CParsec.sendKeyboardMessage(keyCode: 226, pressed: false)
					CParsec.sendKeyboardMessage(keyCode: 230, pressed: false)
					CParsec.sendKeyboardMessage(keyCode: 227, pressed: true)
					optCmdRemapActive = true
				}
				let code = KeyCodeTranslators.uiKeyCodeToInt(key: key.keyCode)
				CParsec.sendKeyboardMessage(keyCode: UInt32(code), pressed: true)
				startKeyRepeat(keyCode: code)
				continue
			}

			CParsec.sendKeyboardMessage(event:KeyBoardKeyEvent(input: press.key, isPressBegin: true))

			if !isModifierKey(key.keyCode) {
				startKeyRepeat(keyCode: KeyCodeTranslators.uiKeyCodeToInt(key: key.keyCode))
			}
		}
	}

	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		for press in presses {
			guard let key = press.key else { continue }

			if optCmdRemapActive {
				if key.keyCode == .keyboardLeftAlt || key.keyCode == .keyboardRightAlt {
					altKeyHeld = false
					CParsec.sendKeyboardMessage(keyCode: 227, pressed: false)
					optCmdRemapActive = false
					continue
				}
				if !isModifierKey(key.keyCode) {
					let code = KeyCodeTranslators.uiKeyCodeToInt(key: key.keyCode)
					CParsec.sendKeyboardMessage(keyCode: UInt32(code), pressed: false)
					if code == repeatKeyCode { stopKeyRepeat() }
					continue
				}
			}

			if key.keyCode == .keyboardLeftAlt || key.keyCode == .keyboardRightAlt {
				altKeyHeld = false
			}

			CParsec.sendKeyboardMessage(event:KeyBoardKeyEvent(input: press.key, isPressBegin: false))

			let code = KeyCodeTranslators.uiKeyCodeToInt(key: key.keyCode)
			if code == repeatKeyCode {
				stopKeyRepeat()
			}
		}
	}

	override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		// iOS sends this instead of pressesEnded when a press is interrupted (e.g. backgrounding
		// mid-hold) — without cleanup the host keeps keys held (stuck paste, stuck modifier).
		CParsec.sendReleaseMessage()
		resetKeyState()
	}

	func startKeyRepeat(keyCode: Int) {
		stopKeyRepeat()
		repeatKeyCode = keyCode

		repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
			MainActor.assumeIsolated {
				guard let self = self else { return }
				self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
					MainActor.assumeIsolated {
						guard let self = self else { return }
						CParsec.sendKeyboardMessage(keyCode: UInt32(self.repeatKeyCode), pressed: false)
						CParsec.sendKeyboardMessage(keyCode: UInt32(self.repeatKeyCode), pressed: true)
					}
				}
			}
		}
	}

	func stopKeyRepeat() {
		repeatTimer?.invalidate()
		repeatTimer = nil
		repeatKeyCode = -1
	}

	func resetKeyState() {
		stopKeyRepeat()
		optCmdRemapActive = false
		altKeyHeld = false
	}

	func isModifierKey(_ keyCode: UIKeyboardHIDUsage) -> Bool {
		switch keyCode {
		case .keyboardLeftControl, .keyboardLeftShift, .keyboardLeftAlt, .keyboardLeftGUI,
			 .keyboardRightControl, .keyboardRightShift, .keyboardRightAlt, .keyboardRightGUI,
			 .keyboardCapsLock:
			return true
		default:
			return false
		}
	}
}
