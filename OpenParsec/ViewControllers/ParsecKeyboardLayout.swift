import UIKit
import ParsecSDK

// MARK: - Keyboard Layout

/// Virtual on-screen keyboard: key buttons, input accessory view, and toolbar.
class KeyboardButton: UIButton {
	let keyText: String
	let isToggleable: Bool
	var isOn = false

	required init(keyText: String, isToggleable: Bool) {
		self.keyText = keyText
		self.isToggleable = isToggleable
		super.init(frame: .zero)
		addTarget(self, action: #selector(handleTouchDown), for: .touchDown)
		addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchDragExit, .touchCancel])

	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// Add a press-down animation for feedback
	@objc private func handleTouchDown() {
		self.alpha = 0.5
	}

	// Restore to normal state when touch ends
	@objc private func handleTouchUp() {
		UIView.animate(withDuration: 0.2) {
			self.alpha = 1.0
		}
	}
}

extension ParsecViewController {
    // copied from moonlight https://github.com/moonlight-stream/moonlight-ios/blob/022352c1667788d8626b659d984a290aa5c25e17/Limelight/Input/StreamView.m#L393
	override var inputAccessoryView: UIView? {

		if let keyboardAccessoriesView {
			return keyboardAccessoriesView
		}
        // Refactored to UIView with autoresizing mask for better landscape support
        // Using frame-based layout for the container to avoid constraint conflicts with keyboard
		let containerView = AccessoryContainerView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 94))
        containerView.autoresizingMask = [.flexibleWidth]
        containerView.backgroundColor = .clear

		// Use a simple UIView instead of UIToolbar to avoid constraint conflicts
		let toolbarBackground = UIView(frame: CGRect(x: 0, y: 50, width: containerView.bounds.width, height: 44))
		toolbarBackground.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		toolbarBackground.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)

		let scrollView = UIScrollView(frame: CGRect(x: 8, y: 0, width: toolbarBackground.bounds.width - 80, height: 44))
		scrollView.autoresizingMask = [.flexibleWidth]
		scrollView.showsHorizontalScrollIndicator = false

		let buttonStackView = UIStackView()
		buttonStackView.axis = .horizontal
		buttonStackView.distribution = .equalSpacing
		buttonStackView.alignment = .center
		buttonStackView.spacing = 8
		buttonStackView.translatesAutoresizingMaskIntoConstraints = false

		let shiftBarButton = createKeyboardButton(displayText: "⇧", keyText: "SHIFT", isToggleable: true)
		let windowsBarButton = createKeyboardButton(displayText: "⌘", keyText: "LGUI", isToggleable: true)
		let tabBarButton = createKeyboardButton(displayText: "⇥", keyText: "TAB", isToggleable: false)
		let escapeBarButton = createKeyboardButton(displayText: "⎋", keyText: "UIKeyInputEscape", isToggleable: false)
		let controlBarButton = createKeyboardButton(displayText: "⌃", keyText: "CONTROL", isToggleable: true)
		let altBarButton = createKeyboardButton(displayText: "⌥", keyText: "LALT", isToggleable: true)
		let deleteBarButton = createKeyboardButton(displayText: "Del", keyText: "DELETE", isToggleable: false)
		let f1Button = createKeyboardButton(displayText: "F1", keyText: "F1", isToggleable: false)
		let f2Button = createKeyboardButton(displayText: "F2", keyText: "F2", isToggleable: false)
		let f3Button = createKeyboardButton(displayText: "F3", keyText: "F3", isToggleable: false)
		let f4Button = createKeyboardButton(displayText: "F4", keyText: "F4", isToggleable: false)
		let f5Button = createKeyboardButton(displayText: "F5", keyText: "F5", isToggleable: false)
		let f6Button = createKeyboardButton(displayText: "F6", keyText: "F6", isToggleable: false)
		let f7Button = createKeyboardButton(displayText: "F7", keyText: "F7", isToggleable: false)
		let f8Button = createKeyboardButton(displayText: "F8", keyText: "F8", isToggleable: false)
		let f9Button = createKeyboardButton(displayText: "F9", keyText: "F9", isToggleable: false)
		let f10Button = createKeyboardButton(displayText: "F10", keyText: "F10", isToggleable: false)
		let f11Button = createKeyboardButton(displayText: "F11", keyText: "F11", isToggleable: false)
		let f12Button = createKeyboardButton(displayText: "F12", keyText: "F12", isToggleable: false)
		let upButton = createKeyboardButton(displayText: "↑", keyText: "UP", isToggleable: false)
		let downButton = createKeyboardButton(displayText: "↓", keyText: "DOWN", isToggleable: false)
		let leftButton = createKeyboardButton(displayText: "←", keyText: "LEFT", isToggleable: false)
		let rightButton = createKeyboardButton(displayText: "→", keyText: "RIGHT", isToggleable: false)

		let buttons = [tabBarButton, shiftBarButton, controlBarButton, altBarButton, windowsBarButton, escapeBarButton, f1Button, f2Button, f3Button, f4Button, f5Button, f6Button, f7Button, f8Button, f9Button, f10Button, f11Button, f12Button, deleteBarButton, upButton, downButton, leftButton, rightButton]

		for button in buttons {
			buttonStackView.addArrangedSubview(button)
		}

		scrollView.addSubview(buttonStackView)

		// Set constraints for the stack view inside the scroll view
		NSLayoutConstraint.activate([
			buttonStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
			buttonStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
			buttonStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
			buttonStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
			buttonStackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
		])

		// Done button with frame-based layout
		let doneButton = UIButton(type: .system)
		doneButton.frame = CGRect(x: toolbarBackground.bounds.width - 70, y: 0, width: 60, height: 44)
		doneButton.autoresizingMask = [.flexibleLeftMargin]
		doneButton.setTitle("Done", for: .normal)
		doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

		let handle = UIImageView(image: UIImage(systemName: "arrow.up.and.down"))
		handle.frame = CGRect(x: 4, y: 0, width: 40, height: 44)
		handle.contentMode = .center
		handle.tintColor = .label
		handle.isUserInteractionEnabled = true
		handle.isHidden = true
		handle.isAccessibilityElement = true
		handle.accessibilityLabel = "Move screen up or down"
		handle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePanHandle(_:))))
		let handleDoubleTap = UITapGestureRecognizer(target: self, action: #selector(handlePanHandleDoubleTap(_:)))
		handleDoubleTap.numberOfTapsRequired = 2
		handle.addGestureRecognizer(handleDoubleTap)
		panHandle = handle
		keyScrollView = scrollView
		keyBarDone = doneButton
		containerView.onLayout = { [weak self] in self?.layoutKeyBar() }

		toolbarBackground.addSubview(scrollView)
		toolbarBackground.addSubview(handle)
		toolbarBackground.addSubview(doneButton)

		containerView.addSubview(toolbarBackground)

		keyboardAccessoriesView = containerView
		return containerView
	}

	func createKeyboardButton(displayText: String, keyText: String, isToggleable: Bool) -> UIButton {
		let button = KeyboardButton(keyText: keyText, isToggleable: isToggleable)

		// Set the image and button properties
		button.setTitle(displayText, for: .normal)
		button.titleLabel?.font = .systemFont(ofSize: 10)
		button.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
		button.titleLabel?.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
		if let label = button.titleLabel {
			label.textAlignment = .center
		}
		button.backgroundColor = .black
		button.layer.cornerRadius = 3.0

		button.titleLabel?.contentMode = .scaleAspectFit

		// Set target and action for button
		button.addTarget(self, action: #selector(toolbarButtonClicked(_:)), for: .touchUpInside)

		return button
	}

	func toolbarButtons(in view: UIView) -> [KeyboardButton] {
		let own = (view as? KeyboardButton).map { [$0] } ?? []
		return own + view.subviews.flatMap { toolbarButtons(in: $0) }
	}

	@objc func toolbarButtonClicked(_ sender: KeyboardButton) {
		let isToggleable = sender.isToggleable
		var isOn = sender.isOn

		if isToggleable {
			isOn.toggle()
			if isOn {
				sender.backgroundColor = .lightGray
			} else {
				sender.backgroundColor = .black
			}
		}

		sender.isOn = isOn
		let keyText = sender.keyText

		if isToggleable {
			if isOn {
				CParsec.sendVirtualKeyboardInput(text: keyText, isOn: true)
			} else {
				CParsec.sendVirtualKeyboardInput(text: keyText, isOn: false)
			}
		} else {
			CParsec.sendVirtualKeyboardInput(text: keyText)
		}

	}

	@objc func doneTapped() {
		// Resign first responder to dismiss the keyboard
		resignFirstResponder()
	}
}
