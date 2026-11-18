import UIKit
import ParsecSDK

extension ParsecViewController {
	@objc func keyboardWillShow(notification: NSNotification) {
		if let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
			let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
			let scrollFrameInView = scrollView.convert(scrollView.bounds, to: view)
			let intersection = scrollFrameInView.intersection(keyboardFrameInView)
			let coversBottomEdge = !intersection.isNull && intersection.maxY >= scrollFrameInView.maxY - 1
			let height = coversBottomEdge ? intersection.height : 0
			keyboardHeight = height
            keyboardVisible = true

            // Allow scrolling past current bottom to see hidden content
            scrollView.contentInset.bottom = height

			if scrollView.zoomScale <= 1.0, let shift = pictureShiftAboveKeyboard(height - accessoryClearBand) {
				keyboardCoversPicture = false
				updatePanHandle()
				pinnedToKeyboard = true
				scrollView.contentInset.top = max(0, -shift)
				scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: shift), animated: true)
				onKeyboardVisibilityChanged?(true)
				return
			}
			var baseY = scrollView.contentOffset.y
			if pinnedToKeyboard {
				pinnedToKeyboard = false
				scrollView.contentInset.top = 0
				baseY = 0
			}
			keyboardCoversPicture = height > 0
			updatePanHandle()
			if height > 0 && SettingsStore.shared.cursorMode == .direct {
				onKeyboardCoversPicture?()
			}
			if SettingsStore.shared.cursorMode == .direct {
				let bottomY = max(0, scrollView.contentSize.height - scrollView.bounds.height + height)
				scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: bottomY), animated: true)
				onKeyboardVisibilityChanged?(true)
				return
			}

            // Automatic scroll up only if mouse is in the bottom half of the screen
            let mouseY = CGFloat(CParsec.mouseInfo.mouseY)
            let screenMidY = view.bounds.height / 2.1

            if mouseY > screenMidY {
                 let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height + height)
                 let newOffsetY = min(maxOffsetY, baseY + height / 1.25)

                 scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: newOffsetY), animated: true)

            } else if baseY != scrollView.contentOffset.y {
				scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: baseY), animated: true)
			}
		}
		onKeyboardVisibilityChanged?(true)
	}

	var accessoryClearBand: CGFloat {
		keyboardAccessoriesView?.subviews.first?.frame.minY ?? 0
	}

	func pictureShiftAboveKeyboard(_ keyboard: CGFloat) -> CGFloat? {
		let w = view.bounds.width, h = view.bounds.height
		guard keyboard > 0, CParsec.hostWidth > 0, CParsec.hostHeight > 0 else { return nil }
		let picture = min(h, w * CGFloat(CParsec.hostHeight / CParsec.hostWidth))
		guard picture <= h - keyboard else { return nil }
		return keyboard - (h - picture) / 2
	}

	func updatePanHandle() {
		setPanHandleVisible(keyboardCoversPicture && SettingsStore.shared.cursorMode == .direct)
	}

	func setPanHandleVisible(_ visible: Bool) {
		guard let handle = panHandle else { return }
		handle.isHidden = !visible
		setPanHandleAxes()
		layoutKeyBar()
	}

	func setPanHandleAxes() {
		guard let handle = panHandle, !handle.isHidden else { return }
		let zoomed = scrollView.zoomScale > 1.01
		let label = zoomed ? "Move screen in any direction" : "Move screen up or down"
		guard handle.accessibilityLabel != label else { return }
		handle.image = UIImage(systemName: zoomed ? "arrow.up.and.down.and.arrow.left.and.right" : "arrow.up.and.down")
		handle.accessibilityLabel = label
	}

	func layoutKeyBar() {
		guard let handle = panHandle, let keys = keyScrollView, let bar = keys.superview else { return }
		let inset = bar.safeAreaInsets
		handle.frame.origin.x = 4 + inset.left
		let left = (handle.isHidden ? 8 : 48) + inset.left
		keys.frame = CGRect(x: left, y: 0, width: bar.bounds.width - 72 - left - inset.right, height: 44)
		keyBarDone?.frame.origin.x = bar.bounds.width - 70 - inset.right
	}

	@objc func handlePanHandle(_ gesture: UIPanGestureRecognizer) {
		if gesture.state == .began {
			panStartOffset = scrollView.contentOffset
		}
		let t = gesture.translation(in: view)
		let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
		let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
		let x = min(max(0, panStartOffset.x - t.x), maxX)
		let y = min(max(-scrollView.contentInset.top, panStartOffset.y - t.y), maxY)
		scrollView.setContentOffset(CGPoint(x: x, y: y), animated: false)
		positionCursorOverlay()
	}

	@objc func handlePanHandleDoubleTap(_ gesture: UITapGestureRecognizer) {
		let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
		let y: CGFloat = scrollView.contentOffset.y < maxY / 2 ? maxY : 0
		scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: y), animated: true)
	}

	@objc func keyboardWillHide(notification: NSNotification) {
		keyboardHeight = 0.0
        keyboardVisible = false
		keyboardCoversPicture = false
		setPanHandleVisible(false)
		if pinnedToKeyboard {
			pinnedToKeyboard = false
			scrollView.contentInset = .zero
			scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0), animated: true)
			onKeyboardVisibilityChanged?(false)
			return
		}

        // Restore inset
        scrollView.contentInset.bottom = 0

        // Transform cleanup (just in case)
        view.transform = .identity

        // Automatic scroll down in landscape mode (reverse of show)
        if view.bounds.width > view.bounds.height {
             // We subtract, but clamp to 0 (or valid range)
			let newOffsetY = max(0, scrollView.contentOffset.y - ((notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height ?? 0.0))
             // Or maybe just clamp to valid range without forcing a subtract?
             // User said "bajar la altura", implying a reverse scroll.
             scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: newOffsetY), animated: true)
        }
		onKeyboardVisibilityChanged?(false)
	}
}
