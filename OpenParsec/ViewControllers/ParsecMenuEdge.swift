import UIKit
import ParsecSDK

// MARK: - Menu Edge Swipe

/// Screen-edge swipe and tap/long-press handlers that open the stream menu.
extension ParsecViewController {
	// the delay stops a direct mode swipe from clicking at the edge first
	func addMenuEdgeSwipe(_ edge: UIRectEdge) -> UIScreenEdgePanGestureRecognizer {
		let edgeSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleMenuEdgeSwipe(_:)))
		edgeSwipe.edges = edge
		edgeSwipe.maximumNumberOfTouches = 1
		edgeSwipe.allowedTouchTypes = [0]
		edgeSwipe.delaysTouchesBegan = true
		edgeSwipe.isEnabled = false
		view.addGestureRecognizer(edgeSwipe)
		return edgeSwipe
	}

	// left brings back a hidden menu button, slide over owns the right edge
	func updateMenuEdgeSwipe(menuHidden: Bool) {
		menuEdgeSwipe?.isEnabled = menuHidden || SettingsStore.shared.menuSwipeEdge == .left
		menuEdgeSwipeRight?.isEnabled = SettingsStore.shared.menuSwipeEdge == .right
	}

	// switching it off mid swipe would hand the held touch to the stream
	@objc func handleMenuEdgeSwipe(_ gestureRecognizer: UIScreenEdgePanGestureRecognizer) {
		switch gestureRecognizer.state {
		case .began:
			flushAllTouches()
			onMenuEdgeSwipe?()
		case .ended, .cancelled, .failed:
			updateMenuEdgeSwipe(menuHidden: false)
		default:
			break
		}
	}

	@objc func handleSingleFingerTap(_ gestureRecognizer: UITapGestureRecognizer) {
		// Only click if the finger stayed put; a moved finger was a cursor nudge, not a tap.
		if cursorDidMoveThisTouch { return }
		if SettingsStore.shared.cursorMode == .direct { return }
		let location = gestureRecognizer.location(in: gestureRecognizer.view)
		let adjustedLocation = contentView.convert(location, from: view)
		touchController.onTap(typeOfTap: 1, location: adjustedLocation)
	}

	@objc func handleTwoFingerTap(_ gestureRecognizer: UITapGestureRecognizer) {
		// A two-finger TAP is a right click; if the fingers moved (pinch/scroll) it wasn't a tap.
		if twoFingerDidMove { return }
		// dont leak a right-click to the host while backgrounding (app switch) or after a disconnect
		guard UIApplication.shared.applicationState == .active,
			  ParsecBackgroundManager.shared.hasActiveConnection else { return }

		let location: CGPoint
		switch SettingsStore.shared.rightClickPosition {
		case .firstFinger:
			location = gestureRecognizer.location(ofTouch: 0, in: gestureRecognizer.view)
			case .secondFinger:
			location = gestureRecognizer.location(ofTouch: 1, in: gestureRecognizer.view)
		default:
			location = gestureRecognizer.location(in: gestureRecognizer.view)
		}

		let adjustedLocation = contentView.convert(location, from: view)
		touchController.onTap(typeOfTap: 3, location: adjustedLocation)
	}

	@objc func handleThreeFinderTap(_ gestureRecognizer: UITapGestureRecognizer) {
		setKeyboardVisible(!keyboardVisible)
	}

	@objc func handleLongPress(_ gestureRecognizer: UIGestureRecognizer) {
		if SettingsStore.shared.cursorMode != .touchpad {
			return
		}
		switch gestureRecognizer.state {
		case .began:
			// Click-and-hold (file drag): hold the left button; the overlay keeps moving the cursor.
			clickHoldActive = true
			CParsec.sendMouseClickMessage(ParsecMouseButton.init(rawValue: 1), true)
		case .ended, .cancelled, .failed:
			releaseClickHoldIfNeeded()
		default:
			break
		}
	}
}
