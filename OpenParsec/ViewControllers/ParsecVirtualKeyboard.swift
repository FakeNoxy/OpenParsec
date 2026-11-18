import UIKit
import ParsecSDK

// MARK: - Virtual Keyboard
extension ParsecViewController: UIKeyInput, UITextInputTraits {
	var hasText: Bool {
		return true
	}

	var keyboardType: UIKeyboardType {
		get {
			return .asciiCapable
		}
		set {

		}
	}

	// passthrough keyboard: send raw input, dont let iOS autocorrect / smart-substitute / inject text
	var autocorrectionType: UITextAutocorrectionType {
		get { .no }
		set { }
	}
	var spellCheckingType: UITextSpellCheckingType {
		get { .no }
		set { }
	}
	var smartQuotesType: UITextSmartQuotesType {
		get { .no }
		set { }
	}
	var smartDashesType: UITextSmartDashesType {
		get { .no }
		set { }
	}
	var smartInsertDeleteType: UITextSmartInsertDeleteType {
		get { .no }
		set { }
	}
	var autocapitalizationType: UITextAutocapitalizationType {
		get { .none }
		set { }
	}

	override var canBecomeFirstResponder: Bool {
		return true
	}

	func insertText(_ text: String) {
		CParsec.sendVirtualKeyboardInput(text: text)
	}

	func deleteBackward() {
		CParsec.sendVirtualKeyboardInput(text: "BACKSPACE")
	}

	@objc func inputWasReleased() {
		clearToolbarModifiers(sendToHost: false)
	}

	func clearToolbarModifiers(sendToHost: Bool) {
		guard let bar = keyboardAccessoriesView else { return }
		for button in toolbarButtons(in: bar) where button.isOn {
			button.isOn = false
			button.backgroundColor = .black
			if sendToHost {
				CParsec.sendVirtualKeyboardInput(text: button.keyText, isOn: false)
			}
		}
	}

	// CRITICAL: This is the robust way to show the keyboard.
    // 1. Dispatch async to ensure view is attached to window.
    // 2. call reloadInputViews() to ensure updated accessory view (especially for rotation).
    // 3. call becomeFirstResponder().
    // 4. Do NOT simplify this to a synchronous call, or it will fail in some race conditions.
	func setKeyboardVisible(_ visible: Bool) {
		keyboardVisible = visible
		if visible {
            DispatchQueue.main.async {
                self.reloadInputViews()
                let success = self.becomeFirstResponder()
                if !success {
                   // Fallback: try again? or just log (can't log).
                   // Maybe ensure user interaction is on on window?
                }
            }
		} else {
			resignFirstResponder()
		}
	}

}
