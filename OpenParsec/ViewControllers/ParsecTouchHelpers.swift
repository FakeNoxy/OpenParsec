import UIKit

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

protocol ParsecTouchInputDelegate: AnyObject {
	// Called on every touch change with the authoritative set of currently-active touches.
	func parsecTouchesUpdated(_ activeTouches: Set<UITouch>, moved: Bool)
}

// A transparent overlay that owns every raw touch and forwards it to the controller. Sitting on
// top of (not inside) the scroll view, it gives deterministic, unfiltered touch delivery with no
// UIScrollView gesture races - the controller decides 1-finger cursor vs 2-finger pinch / scroll.
class TouchOverlayView: UIView {
	weak var inputDelegate: ParsecTouchInputDelegate?

	// Forward the live touch set (excluding ended/cancelled) on every event. External mouse /
	// trackpad input arrives as indirect-pointer touches but is handled entirely by GCMouse, so it's
	// dropped here — otherwise it warps the direct-mode cursor and fights touchpad-mode drags.
	private func forward(_ event: UIEvent?, moved: Bool) {
		let active = (event?.allTouches ?? []).filter { touch in
			guard touch.phase != .ended && touch.phase != .cancelled else { return false }
			if #available(iOS 13.4, *), touch.type == .indirectPointer { return false }
			return true
		}
		inputDelegate?.parsecTouchesUpdated(active, moved: moved)
	}
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { forward(event, moved: false) }
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { forward(event, moved: true) }
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { forward(event, moved: false) }
	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { forward(event, moved: false) }
}

final class AccessoryContainerView: UIView {
	var onLayout: (() -> Void)?

	override func layoutSubviews() {
		super.layoutSubviews()
		onLayout?()
	}

	override func safeAreaInsetsDidChange() {
		super.safeAreaInsetsDidChange()
		setNeedsLayout()
	}

	override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
		subviews.contains { $0.frame.contains(point) }
	}
}
