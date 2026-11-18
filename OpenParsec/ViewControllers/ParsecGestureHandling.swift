import UIKit
import ParsecSDK
import QuartzCore

extension ParsecViewController: UIGestureRecognizerDelegate {

	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}

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
		menuEdgeSwipe?.isEnabled = menuHidden || SettingsHandler.menuSwipeEdge == .left
		menuEdgeSwipeRight?.isEnabled = SettingsHandler.menuSwipeEdge == .right
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

	@objc func handlePinchGesture(_ gestureRecognizer: UIPinchGestureRecognizer) {
		// Pinch is handled by UIScrollView
	}

	// MARK: - Manual touch handling (ParsecTouchInputDelegate)
	// touchOverlay delivers raw touches here. One finger drives the mouse cursor; two fingers are
	// classified once per gesture into either pinch-zoom or host scroll-wheel (never both), so the
	// gestures never fight. No UIScrollView gesture recognizer is in the loop.

	func parsecTouchesUpdated(_ touches: Set<UITouch>, moved: Bool) {
		let oldCount = activeTouches.count
		// Rebuild from the event each time (keeping order) so a cancelled touch can't leave a stale one.
		var ordered = activeTouches.filter { touches.contains($0) }
		for t in touches where !ordered.contains(t) {
			ordered.append(t)
			touchOrigins[t] = t.location(in: view)
		}
		// Sweep a ghost (an OS-dropped lift lingering as .stationary) only while another finger actively
		// moves - a resting or just-tapped finger is never swept, so taps and held fingers stay safe.
		var sweptGhost = false
		if ordered.count >= 2 && !clickHoldActive,
		   let newest = ordered.max(by: { $0.timestamp < $1.timestamp }) {
			let origin = touchOrigins[newest] ?? newest.location(in: view)
			let here = newest.location(in: view)
			if hypot(here.x - origin.x, here.y - origin.y) > staleMoveSlop {
				let fresh = ordered.filter { newest.timestamp - $0.timestamp < staleTouchThreshold }
				if fresh.count < ordered.count { ordered = fresh; sweptGhost = true }
			}
		}
		activeTouches = ordered
		touchOrigins = touchOrigins.filter { activeTouches.contains($0.key) }
		if sweptGhost && activeTouches.count == 1 {
			// Recover the surviving finger as a live cursor instead of inert two-finger residual.
			stopMomentum()
			twoFingerResidual = false
			twoFingerMode = .undecided
			startCursor()
		} else if activeTouches.count != oldCount {
			handleTouchCountChange(old: oldCount, new: activeTouches.count)
		}
		if moved { handleActiveTouchesMoved() }
	}

	func handleTouchCountChange(old: Int, new: Int) {
		edgeScrollActive = false
		if new > old { stopMomentum() }   // any new finger cancels an in-progress glide
		if new == 0 {
			let flingCursor = (old == 1) && isDragging && !twoFingerResidual && !clickHoldActive
			let flingScroll = (old >= 2) && (twoFingerMode == .scroll)
			releaseClickHoldIfNeeded()   // defensive: the left button must never stay stuck down
			endCursorIfNeeded()
			isDragging = false
			twoFingerResidual = false
			twoFingerMode = .undecided
			if flingCursor { startCursorMomentum() }
			if flingScroll { startScrollMomentum() }
		} else if new == 1 {
			if old >= 2 {
				// Leftover finger after a two-finger gesture: stay inert until full lift so it
				// doesn't jump the cursor.
				if twoFingerMode == .scroll { startScrollMomentum() }
				twoFingerResidual = true
				twoFingerMode = .undecided
			} else if old == 0 {
				startCursor()
			}
		} else if new >= 2 {
			releaseClickHoldIfNeeded()   // can't keep the button held during a two-finger gesture
			if isDragging { endCursorIfNeeded(); isDragging = false }
			beginTwoFinger()
		}
	}

	func releaseClickHoldIfNeeded() {
		if clickHoldActive {
			CParsec.sendMouseClickMessage(ParsecMouseButton.init(rawValue: 1), false)
			clickHoldActive = false
		}
	}

	@objc func appWillResignActive() { flushAllTouches() }

	// Drop all touch state and release any held button so nothing sticks when backgrounded.
	func flushAllTouches() {
		stopMomentum()
		releaseClickHoldIfNeeded()
		endCursorIfNeeded()
		isDragging = false
		twoFingerResidual = false
		twoFingerMode = .undecided
		activeTouches = []
	}

	func startCursor() {
		isDragging = true
		twoFingerResidual = false
		cursorDidMoveThisTouch = false
		singleTouchStartScreen = activeTouches.first?.location(in: view) ?? .zero
		if SettingsHandler.cursorMode == .direct {
			if let t = activeTouches.first {
				cursorContentPos = clampToContent(contentView.convert(t.location(in: view), from: view))
				CParsec.sendMousePosition(Int32(cursorContentPos.x), Int32(cursorContentPos.y))
				positionCursorOverlay()
			}
			CParsec.sendMouseClickMessage(ParsecMouseButton.init(rawValue: 1), true)
		}
	}

	func endCursorIfNeeded() {
		if isDragging && SettingsHandler.cursorMode == .direct {
			CParsec.sendMouseClickMessage(ParsecMouseButton.init(rawValue: 1), false)
		}
	}

	func beginTwoFinger() {
		twoFingerMode = .undecided
		twoFingerDidMove = false
		accumulatedScrollY = 0.0
		let d = twoFingerDistanceAndMidpoint()
		startPinchDistance = d.distance
		lastPinchDistance = d.distance
		startTwoFingerMidpoint = d.midpoint
		lastTwoFingerMidpoint = d.midpoint
	}

	func twoFingerDistanceAndMidpoint() -> (distance: CGFloat, midpoint: CGPoint) {
		let pts = activeTouches.prefix(2).map { $0.location(in: view) }
		guard pts.count == 2 else { return (0, pts.first ?? .zero) }
		let dx = pts[1].x - pts[0].x
		let dy = pts[1].y - pts[0].y
		let mid = CGPoint(x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2)
		return (hypot(dx, dy), mid)
	}

	func handleActiveTouchesMoved() {
		if (isDragging || clickHoldActive), !twoFingerResidual, activeTouches.count == 1, let t = activeTouches.first {
			moveCursor(with: t)
		} else if activeTouches.count >= 2 {
			handleTwoFinger()
		}
	}

	func moveCursor(with t: UITouch) {
		let zoom = scrollView.zoomScale
		let loc = t.location(in: view)
		let prev = t.previousLocation(in: view)
		if hypot(loc.x - singleTouchStartScreen.x, loc.y - singleTouchStartScreen.y) > tapMoveSlop {
			cursorDidMoveThisTouch = true
		}

		if CParsec.mouseInfo.mousePositionRelative {
			// Host has captured the pointer (e.g. a game): send true relative motion instead.
			let s = CGFloat(mouseSensitivity) / zoom
			CParsec.sendMouseDelta(Int32((loc.x - prev.x) * s), Int32((loc.y - prev.y) * s))
			return
		}

		if SettingsHandler.cursorMode == .direct {
			cursorContentPos = clampToContent(contentView.convert(loc, from: view))
		} else {
			// Relative finger movement, predicted locally; sensitivity scales down with zoom so the
			// cursor tracks the visible finger.
			let s = CGFloat(mouseSensitivity) / zoom
			let dcx = (loc.x - prev.x) * s
			let dcy = (loc.y - prev.y) * s
			cursorContentPos = clampToContent(CGPoint(x: cursorContentPos.x + dcx, y: cursorContentPos.y + dcy))
			// Smoothed velocity so a quick flick keeps gliding after the finger lifts.
			let now = CACurrentMediaTime()
			let dt = CGFloat(now - lastCursorMoveTime)
			if dt > 0.0005 && dt < 0.1 {
				cursorVelocity = CGPoint(x: cursorVelocity.x * 0.4 + (dcx / dt) * 0.6,
										 y: cursorVelocity.y * 0.4 + (dcy / dt) * 0.6)
			}
			lastCursorMoveTime = now
		}
		// Command the host to the ABSOLUTE predicted position (not a delta) so the host cursor can't
		// crawl behind network round-trips - clicks always land where the cursor is drawn.
		CParsec.sendMousePosition(Int32(cursorContentPos.x), Int32(cursorContentPos.y))
		if SettingsHandler.cursorMode == .direct {
			edgeScrollPoint = loc
			if cursorDidMoveThisTouch && edgeScrollVelocity(at: loc) != .zero {
				if !edgeScrollActive { edgeScrollLastTick = 0 }
				edgeScrollActive = true
				ensureMomentumLink()
			}
		} else {
			centerViewportOnCursorPos()
			positionCursorOverlay()
			keepCursorAboveKeyboard()
		}
		positionCursorOverlay()
	}

	func handleTwoFinger() {
		let d = twoFingerDistanceAndMidpoint()
		if twoFingerMode == .undecided {
			let distDelta = abs(d.distance - startPinchDistance)
			let midDelta = hypot(d.midpoint.x - startTwoFingerMidpoint.x, d.midpoint.y - startTwoFingerMidpoint.y)
			let deadZone: CGFloat = 12.0
			if distDelta > deadZone || midDelta > deadZone {
				twoFingerMode = (distDelta > midDelta && zoomEnabled) ? .zoom : .scroll
				twoFingerDidMove = true
			}
		}
		switch twoFingerMode {
		case .zoom:
			if lastPinchDistance > 0 {
				applyZoom(to: scrollView.zoomScale * (d.distance / lastPinchDistance), anchorInView: d.midpoint)
			}
		case .scroll:
			let deltaY = Float(d.midpoint.y - lastTwoFingerMidpoint.y)
			let direction: Float = SettingsHandler.reverseScrollDirection ? -1.0 : 1.0
			let contribution = deltaY * scrollWheelSpeed * direction
			accumulatedScrollY += contribution
			let intScrollY = Int32(accumulatedScrollY)
			if intScrollY != 0 {
				CParsec.sendWheelMsg(x: 0, y: intScrollY)
				accumulatedScrollY -= Float(intScrollY)
			}
			// Track scroll velocity for a little post-flick momentum.
			let snow = CACurrentMediaTime()
			let sdt = Float(snow - lastScrollMoveTime)
			if sdt > 0.0005 && sdt < 0.1 {
				scrollVelocity = scrollVelocity * 0.4 + (contribution / sdt) * 0.6
			}
			lastScrollMoveTime = snow
		case .undecided:
			break
		}
		lastPinchDistance = d.distance
		lastTwoFingerMidpoint = d.midpoint
	}

	func startCursorMomentum() {
		guard SettingsHandler.cursorMode == .touchpad, !CParsec.mouseInfo.mousePositionRelative else { return }
		guard CACurrentMediaTime() - lastCursorMoveTime < 0.06 else { return }   // finger was still moving at release
		guard hypot(cursorVelocity.x, cursorVelocity.y) > flingMinSpeed else { return }
		// Less glide when zoomed out: at 1x the cursor crosses the screen instead of panning the view.
		let glideScale = min(1.0, 0.3 + 0.7 * (scrollView.zoomScale - 1.0))
		cursorVelocity.x *= glideScale
		cursorVelocity.y *= glideScale
		cursorMomentumActive = true
		ensureMomentumLink()
	}

	func startScrollMomentum() {
		guard CACurrentMediaTime() - lastScrollMoveTime < 0.06 else { return }
		guard abs(scrollVelocity) > scrollStartSpeed else { return }
		scrollMomentumActive = true
		ensureMomentumLink()
	}

	func ensureMomentumLink() {
		if momentumLink == nil {
			let link = CADisplayLink(target: self, selector: #selector(momentumTick(_:)))
			link.add(to: .main, forMode: .common)
			momentumLink = link
		}
	}

	func stopMomentum() {
		cursorMomentumActive = false
		scrollMomentumActive = false
		edgeScrollActive = false
		cursorVelocity = .zero
		scrollVelocity = 0
		momentumLink?.invalidate()
		momentumLink = nil
	}

	@objc func momentumTick(_ link: CADisplayLink) {
		let dt = CGFloat(link.targetTimestamp - link.timestamp)
		if dt <= 0 { return }
		var stillActive = false

		if cursorMomentumActive {
			let decay = CGFloat(pow(cursorDecayPerSec, Double(dt)))
			cursorVelocity.x *= decay
			cursorVelocity.y *= decay
			let before = cursorContentPos
			cursorContentPos = clampToContent(CGPoint(x: cursorContentPos.x + cursorVelocity.x * dt,
													  y: cursorContentPos.y + cursorVelocity.y * dt))
			if !CParsec.mouseInfo.mousePositionRelative {
				CParsec.sendMousePosition(Int32(cursorContentPos.x), Int32(cursorContentPos.y))
			}
			centerViewportOnCursorPos()
			positionCursorOverlay()
			let stalled = abs(cursorContentPos.x - before.x) < 0.05 && abs(cursorContentPos.y - before.y) < 0.05
			if hypot(cursorVelocity.x, cursorVelocity.y) < cursorStopSpeed || stalled {
				cursorMomentumActive = false
			} else {
				stillActive = true
			}
		}

		if scrollMomentumActive {
			scrollVelocity *= Float(pow(scrollDecayPerSec, Double(dt)))
			accumulatedScrollY += scrollVelocity * Float(dt)
			let i = Int32(accumulatedScrollY)
			if i != 0 {
				CParsec.sendWheelMsg(x: 0, y: i)
				accumulatedScrollY -= Float(i)
			}
			if abs(scrollVelocity) < scrollStopSpeed {
				scrollMomentumActive = false
			} else {
				stillActive = true
			}
		}

		if edgeScrollActive {
			let elapsed = edgeScrollLastTick > 0 ? min(CGFloat(link.timestamp - edgeScrollLastTick), 0.1) : dt
			edgeScrollLastTick = link.timestamp
			if stepEdgeScroll(elapsed) {
				stillActive = true
			} else {
				edgeScrollActive = false
			}
		}

		if !stillActive { stopMomentum() }
	}

	// Manually zoom the scroll view around a screen-space anchor (the pinch midpoint), keeping the
	// content point under the anchor fixed. Replaces the scroll view's own pinch recognizer.
	func applyZoom(to targetScale: CGFloat, anchorInView anchor: CGPoint) {
		let oldZoom = scrollView.zoomScale
		let newZoom = min(max(targetScale, scrollView.minimumZoomScale), scrollView.maximumZoomScale)
		guard abs(newZoom - oldZoom) > 0.0001 else { return }
		let off = scrollView.contentOffset
		let contentX = (anchor.x + off.x) / oldZoom
		let contentY = (anchor.y + off.y) / oldZoom
		scrollView.zoomScale = newZoom
		setPanHandleAxes()
		if pinnedToKeyboard {
			pinnedToKeyboard = false
			scrollView.contentInset.top = 0
			keyboardCoversPicture = keyboardHeight > 0
			updatePanHandle()
		}
		var newOff = CGPoint(x: contentX * newZoom - anchor.x, y: contentY * newZoom - anchor.y)
		let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
		let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
		newOff.x = min(max(0, newOff.x), maxX)
		newOff.y = min(max(0, newOff.y), maxY)
		scrollView.setContentOffset(newOff, animated: false)
		// Park the cursor at the viewport centre after zooming so a later drag doesn't snap the view.
		let bottomInset = keyboardVisible ? keyboardHeight : 0.0
		let centerX = (scrollView.bounds.width / 2 + scrollView.contentOffset.x) / newZoom
		let centerY = ((scrollView.bounds.height - bottomInset) / 2 + scrollView.contentOffset.y) / newZoom
		cursorContentPos = clampToContent(CGPoint(x: centerX, y: centerY))
		if !CParsec.mouseInfo.mousePositionRelative {
			CParsec.sendMousePosition(Int32(cursorContentPos.x), Int32(cursorContentPos.y))
		}
		positionCursorOverlay()
	}

	func clampToContent(_ p: CGPoint) -> CGPoint {
		let w = view.bounds.width
		let h = view.bounds.height
		return CGPoint(x: min(max(0, p.x), w), y: min(max(0, p.y), h))
	}

	// Places the cursor overlay at the cursor's content position projected into screen space,
	// drawn at full Cursor Scale (no zoom division) so it stays crisp and constant-sized.
	func positionCursorOverlay() {
		guard let u = u else { return }
		let zoom = scrollView.zoomScale
		let off = scrollView.contentOffset
		let screenX = cursorContentPos.x * zoom - off.x
		let screenY = cursorContentPos.y * zoom - off.y
		let cs = CGFloat(SettingsHandler.cursorScale)
		let hotX = CGFloat(CParsec.mouseInfo.cursorHotX) * cs
		let hotY = CGFloat(CParsec.mouseInfo.cursorHotY) * cs
		let w = CGFloat(CParsec.mouseInfo.cursorWidth) * cs
		let h = CGFloat(CParsec.mouseInfo.cursorHeight) * cs
		u.frame = CGRect(x: screenX - hotX, y: screenY - hotY, width: w, height: h)
	}

	@objc func handleSingleFingerTap(_ gestureRecognizer: UITapGestureRecognizer) {
		// Only click if the finger stayed put; a moved finger was a cursor nudge, not a tap.
		if cursorDidMoveThisTouch { return }
		if SettingsHandler.cursorMode == .direct { return }
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
		switch SettingsHandler.rightClickPosition {
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
		if SettingsHandler.cursorMode != .touchpad {
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

    // UIScrollViewDelegate
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return contentView
	}

	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		positionCursorOverlay()
	}

	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		// Centering is handled on cursor movement (updateImage) and at the end of a pinch.
	}

	func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
		centerViewportOnCursorPos()
	}

	func keepCursorAboveKeyboard() {
		guard scrollView.zoomScale <= 1.0, keyboardVisible, scrollView.contentInset.bottom > 0, !pinnedToKeyboard,
			  SettingsHandler.cursorMode != .direct, let cursor = u, !cursor.isHidden else { return }
		let visibleBottom = view.bounds.height - keyboardHeight
		let margin = min(50, max(0, (visibleBottom - cursor.frame.height) / 2 - 1))
		let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
		var target = scrollView.contentOffset.y
		if cursor.frame.maxY > visibleBottom - margin {
			target += cursor.frame.maxY - (visibleBottom - margin)
		} else if cursor.frame.minY < margin {
			target -= margin - cursor.frame.minY
		}
		target = min(max(0, target), maxOffsetY)
		guard target != scrollView.contentOffset.y else { return }
		scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: target), animated: false)
		positionCursorOverlay()
	}

	// Slides the viewport so the host cursor stays centered on screen while zoomed in,
	// clamped so the cursor can still reach the true edges of the host screen.
	func centerViewportOnCursorPos() {
		guard scrollView.zoomScale > 1.0 else { return }
		let zoom = scrollView.zoomScale
		let bottomInset = keyboardVisible ? keyboardHeight : 0.0
		let visibleWidth = view.bounds.width
		let visibleHeight = view.bounds.height - bottomInset
		let cursorX = cursorContentPos.x * zoom
		let cursorY = cursorContentPos.y * zoom
		var targetX = cursorX - visibleWidth / 2
		var targetY = cursorY - visibleHeight / 2
		let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
		let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height + bottomInset)
		targetX = min(max(0, targetX), maxX)
		targetY = min(max(0, targetY), maxY)
		scrollView.setContentOffset(CGPoint(x: targetX, y: targetY), animated: false)
	}

	func edgeScrollVelocity(at p: CGPoint) -> CGPoint {
		guard scrollView.zoomScale > 1.0 else { return .zero }
		let visibleHeight = view.bounds.height - (keyboardVisible ? keyboardHeight : 0.0)
		func axis(_ v: CGFloat, _ length: CGFloat) -> CGFloat {
			if v < edgeScrollMargin {
				return -min(1, (edgeScrollMargin - v) / edgeScrollMargin) * edgeScrollMaxSpeed
			}
			if v > length - edgeScrollMargin {
				return min(1, (v - (length - edgeScrollMargin)) / edgeScrollMargin) * edgeScrollMaxSpeed
			}
			return 0
		}
		return CGPoint(x: axis(p.x, view.bounds.width), y: axis(p.y, visibleHeight))
	}

	func stepEdgeScroll(_ dt: CGFloat) -> Bool {
		let v = edgeScrollVelocity(at: edgeScrollPoint)
		guard v != .zero, !CParsec.mouseInfo.mousePositionRelative else { return false }
		let bottomInset = keyboardVisible ? keyboardHeight : 0.0
		let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
		let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height + bottomInset)
		let off = scrollView.contentOffset
		let next = CGPoint(x: min(max(0, off.x + v.x * dt), maxX), y: min(max(0, off.y + v.y * dt), maxY))
		guard next != off else { return false }
		scrollView.setContentOffset(next, animated: false)
		cursorContentPos = clampToContent(contentView.convert(edgeScrollPoint, from: view))
		CParsec.sendMousePosition(Int32(cursorContentPos.x), Int32(cursorContentPos.y))
		positionCursorOverlay()
		return true
	}

	func setZoomEnabled(_ enabled: Bool) {
		// Pinch is driven manually in touchOverlay; just gate it with this flag.
		zoomEnabled = enabled
		guard !enabled, scrollView.zoomScale > 1.0 else { return }
		UIView.animate(withDuration: 0.25, animations: {
			self.scrollView.zoomScale = 1.0
			self.scrollView.contentOffset = .zero
		}, completion: { _ in
			self.positionCursorOverlay()
		})
	}

}
