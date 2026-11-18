import Foundation
import UIKit
import ParsecSDK
import QuartzCore
import os

class ParsecViewController: UIViewController, UIScrollViewDelegate, ParsecTouchInputDelegate {
	var glkView: ParsecPlayground!
	var gamePadController: GamepadController!
	var touchController: TouchController!
	var u: UIImageView?
	var lastImg: CGImage?
    var lastMouseX: Int32 = -1
    var lastMouseY: Int32 = -1
    var lastCursorHidden: Bool = false
	var zoomEnabled = false
	var appliedRenderScale: CGFloat = 0       // last contentScaleFactor applied (avoids redundant reallocations)
	let maxRenderScale: CGFloat = 6.0         // cap on drawable density
	var clickHoldActive = false        // left button held via long-press (file drag)
	// Flick-to-glide momentum (tuned constants, not user settings).
	var momentumLink: CADisplayLink?
	var cursorMomentumActive = false
	var scrollMomentumActive = false
	var edgeScrollActive = false
	var edgeScrollPoint: CGPoint = .zero
	var edgeScrollLastTick: CFTimeInterval = 0
	let edgeScrollMargin: CGFloat = 44.0
	let edgeScrollMaxSpeed: CGFloat = 900.0
	var cursorVelocity: CGPoint = .zero     // content points / sec
	var scrollVelocity: Float = 0.0         // wheel units / sec
	var lastCursorMoveTime: CFTimeInterval = 0
	var lastScrollMoveTime: CFTimeInterval = 0
	let flingMinSpeed: CGFloat = 80.0       // min release speed (content pts/sec) to start a cursor glide
	let cursorStopSpeed: CGFloat = 40.0     // end the glide below this speed (lower = gentler, less abrupt)
	let cursorDecayPerSec: Double = 0.08    // fraction of speed left after 1s (bigger = longer glide)
	let scrollStartSpeed: Float = 800.0     // min release speed (wheel units/sec) to start a scroll glide
	let scrollStopSpeed: Float = 200.0
	let scrollDecayPerSec: Double = 0.004
	// A left click fires only if the finger barely moved (else it's a cursor nudge).
	var cursorDidMoveThisTouch = false
	var singleTouchStartScreen: CGPoint = .zero
	let tapMoveSlop: CGFloat = 4.0          // finger movement (pts) above which a touch is a drag, not a tap
	let staleTouchThreshold: TimeInterval = 1.5   // a touch idle this long vs an actively-moving one is a ghost
	let staleMoveSlop: CGFloat = 24.0        // the moving finger must travel this far before a ghost is swept
	var twoFingerDidMove = false            // true once a 2-finger gesture became a pinch/scroll (suppresses right-click)

	var mouseSensitivity: Float { Float(SettingsHandler.mouseSensitivity) }
	// Two-finger scroll-wheel accumulation, kept separate from cursor movement.
	var lastScrollTranslation: CGPoint = .zero
	var accumulatedScrollY: Float = 0.0
	var scrollWheelSpeed: Float { Float(SettingsHandler.scrollSensitivity) * 2.3 }

	// Input-driven cursor + viewport state (manual touch handling via TouchOverlayView).
	var touchOverlay: TouchOverlayView!
	var cursorContentPos: CGPoint = .zero
	var isDragging = false
	var twoFingerResidual = false       // leftover finger after a 2-finger gesture; inert until full lift
	var activeTouches: [UITouch] = []   // ordered; first two drive pinch / scroll
	var touchOrigins: [UITouch: CGPoint] = [:]   // begin location per touch, for ghost-sweep movement test

	enum TwoFingerMode { case undecided, zoom, scroll }
	var twoFingerMode: TwoFingerMode = .undecided
	var startPinchDistance: CGFloat = 0
	var lastPinchDistance: CGFloat = 0
	var startTwoFingerMidpoint: CGPoint = .zero
	var lastTwoFingerMidpoint: CGPoint = .zero

	var keyboardAccessoriesView: UIView?
	var keyboardHeight: CGFloat = 0.0
	var keyboardVisible: Bool = false
	var pinnedToKeyboard = false
	var onKeyboardCoversPicture: (() -> Void)?
	var panHandle: UIImageView?
	var keyScrollView: UIScrollView?
	var keyBarDone: UIButton?
	private var panStartOffset: CGPoint = .zero
	var keyboardCoversPicture = false
	var onKeyboardVisibilityChanged: ((Bool) -> Void)?
	var onMenuEdgeSwipe: (() -> Void)?
	var menuEdgeSwipe: UIScreenEdgePanGestureRecognizer?
	var menuEdgeSwipeRight: UIScreenEdgePanGestureRecognizer?
	var scrollView: UIScrollView!
	var contentView: UIView!
	var lastLaidOutWidth: CGFloat = 0
	var lastLaidOutHeight: CGFloat = 0

	override var prefersPointerLocked: Bool {
		return true
	}

	override var prefersHomeIndicatorAutoHidden: Bool {
		return true
	}

	init() {
		super.init(nibName: nil, bundle: nil)

		let update: () -> Void = { [weak self] in self?.updateImage() }
		let metal = SettingsHandler.renderer == .metal ? ParsecMetalViewController(viewController: self, updateImage: update) : nil
		if let metal = metal, metal.metalRenderer != nil {
			self.glkView = metal
			CParsec.runningRenderer = .metal
			appNote("[renderer] metal")
		} else {
			CParsec.runningRenderer = .opengl
			appNote("[renderer] opengl")
			if metal != nil {
				os_log("%{public}@", log: sdkLog, type: .error, "metal could not start, using opengl")
			}
			self.glkView = ParsecGLKViewController(viewController: self, updateImage: update)
		}

		self.gamePadController = GamepadController()
		self.touchController = TouchController()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func computeRenderScale() -> CGFloat {
		// iPhone Duo: use traitCollection instead of UIScreen.main
		let nativeScale = traitCollection.displayScale
		guard scrollView.zoomScale > 1.01 else { return nativeScale }
		let vw = glkView.renderView.frame.size.width
		let vh = glkView.renderView.frame.size.height
		let sw = CGFloat(CParsec.hostWidth)
		let sh = CGFloat(CParsec.hostHeight)
		guard vw > 0, vh > 0, sw > 0, sh > 0 else { return nativeScale }
		// Match the drawable to the source so zoom stays crisp without rendering wasted pixels.
		let needed = max(sw / vw, sh / vh)
		return min(maxRenderScale, max(nativeScale, needed))
	}

	func updateRenderScale() {
		let target = computeRenderScale()
		if abs(target - appliedRenderScale) > 0.01 {
			appliedRenderScale = target
			DispatchQueue.main.async { [weak self] in
				self?.glkView.renderView.contentScaleFactor = target
			}
		}
	}

	func updateImage() {
		updateRenderScale()
        // Optimization: Snap current valus
        let currentMouseX = CParsec.mouseInfo.mouseX
        let currentMouseY = CParsec.mouseInfo.mouseY
        let currentHidden = CParsec.mouseInfo.cursorHidden
        let currentImg = CParsec.mouseInfo.cursorImg

        // Skip if nothing changed
        if currentMouseX == lastMouseX &&
           currentMouseY == lastMouseY &&
           currentHidden == lastCursorHidden &&
           currentImg == lastImg {
            return
        }

        lastMouseX = currentMouseX
        lastMouseY = currentMouseY
        lastCursorHidden = currentHidden

		if currentImg != nil && !currentHidden {
			u?.isHidden = false
			if lastImg != currentImg {
				u!.image = UIImage(cgImage: currentImg!)
				lastImg = currentImg!
			}

			// While dragging, the touch handler owns the cursor position and viewport (smooth,
			// input-driven). When idle, follow the host's reported cursor so host- or keyboard-
			// driven moves are reflected and any prediction drift is corrected.
			if !isDragging && !clickHoldActive && !cursorMomentumActive {
				let fingerSet = SettingsHandler.cursorMode == .direct
					&& abs(cursorContentPos.x - CGFloat(currentMouseX)) < 1
					&& abs(cursorContentPos.y - CGFloat(currentMouseY)) < 1
				cursorContentPos = CGPoint(x: CGFloat(currentMouseX), y: CGFloat(currentMouseY))
				positionCursorOverlay()
				if scrollView.zoomScale > 1.0 {
					if !fingerSet {
						centerViewportOnCursorPos()
						positionCursorOverlay()
					}
				} else {
					// Not zoomed: keep the cursor above the on-screen keyboard.
					keepCursorAboveKeyboard()
				}
			}
		} else {
			u?.isHidden = true
		}
	}

	func applyFrameRate() {
		// iPhone Duo: get max FPS from the view's screen, not UIScreen.main
		let maxFPS = view.window?.screen.maximumFramesPerSecond ?? 60
		let fps = SettingsHandler.preferredFramesPerSecond == 0 ? maxFPS : SettingsHandler.preferredFramesPerSecond
		(glkView as? ParsecMetalViewController)?.metalView.preferredFramesPerSecond = fps
		(glkView as? ParsecGLKViewController)?.glkViewController.preferredFramesPerSecond = fps
	}

	override func viewDidLoad() {
		// ScrollView Setup
		scrollView = UIScrollView(frame: view.bounds)
		scrollView.delegate = self
		scrollView.minimumZoomScale = 1.0
		scrollView.maximumZoomScale = 5.0
		scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		// The scroll view is a programmatically-driven zoom/pan container only. Every touch is
		// owned by touchOverlay (created below); the scroll view's own gestures are disabled so
		// they can never race with or swallow our cursor / pinch / scroll handling.
		scrollView.panGestureRecognizer.isEnabled = false
		scrollView.pinchGestureRecognizer?.isEnabled = false
		scrollView.isScrollEnabled = false
		scrollView.bouncesZoom = false
		view.addSubview(scrollView)

        // ContentView
		contentView = UIView(frame: view.bounds)
		scrollView.addSubview(contentView)
		scrollView.contentSize = view.bounds.size

        // Initialize GLKView
		glkView.viewDidLoad()

		// Move GLKView to ContentView
		// glkView.viewDidLoad() adds the view to 'view', we need to move it.
		glkView.renderView.removeFromSuperview()
		contentView.addSubview(glkView.renderView)

		if #available(iOS 15.0, *) {
			if SettingsHandler.enablePiP {
				if let parsecGLK = glkView as? ParsecGLKViewController, let eaglContext = parsecGLK.eaglContext {
					PictureInPictureManager.shared.setup(sourceView: view, glContext: eaglContext)
				} else if glkView is ParsecMetalViewController {
					PictureInPictureManager.shared.setup(sourceView: view, glContext: nil)
				}
			}
		}

		touchController.viewDidLoad()
		gamePadController.viewDidLoad()

		// Touch overlay: a transparent sibling ON TOP of the scroll view (and above the gamepad /
		// touch controllers) that captures every raw touch and routes it deterministically
		// (1 finger = cursor, 2 fingers = pinch / scroll). Added before the cursor image and the
		// keyboard toolbar so those stay on top of it.
		touchOverlay = TouchOverlayView(frame: view.bounds)
		touchOverlay.backgroundColor = .clear
		touchOverlay.isMultipleTouchEnabled = true
		touchOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		touchOverlay.inputDelegate = self
		view.addSubview(touchOverlay)

		// Cursor is a screen-space overlay ON TOP of everything (not inside the scroll view), so the
		// zoom transform never scales it - keeping it crisp and a constant on-screen size.
		u = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
		u!.isUserInteractionEnabled = false
		view.addSubview(u!)

		setNeedsUpdateOfPrefersPointerLocked()

		let pointerInteraction = UIPointerInteraction(delegate: self)
		view.addInteraction(pointerInteraction)

		view.isMultipleTouchEnabled = true
		view.isUserInteractionEnabled = true

		// All gestures (cursor, pinch-zoom, two-finger scroll) are handled in the
		// ParsecTouchInputDelegate methods below, driven by touchOverlay's raw touches.

		// Add tap gesture recognizer for single-finger touch
		let singleFingerTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleFingerTap(_:)))
		singleFingerTapGestureRecognizer.numberOfTouchesRequired = 1
		singleFingerTapGestureRecognizer.allowedTouchTypes = [0, 2]
		// Let the overlay see the real touch end so no phantom finger lingers.
		singleFingerTapGestureRecognizer.cancelsTouchesInView = false
		singleFingerTapGestureRecognizer.delaysTouchesEnded = false
		view.addGestureRecognizer(singleFingerTapGestureRecognizer)

		// Add tap gesture recognizer for two-finger touch
		let twoFingerTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
		twoFingerTapGestureRecognizer.numberOfTouchesRequired = 2
		twoFingerTapGestureRecognizer.allowedTouchTypes = [0]
		twoFingerTapGestureRecognizer.cancelsTouchesInView = false
		twoFingerTapGestureRecognizer.delaysTouchesEnded = false
		view.addGestureRecognizer(twoFingerTapGestureRecognizer)
		//		view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
		//		view.backgroundColor = UIColor(red: 0x66, green: 0xcc, blue: 0xff, alpha: 1.0)

		let threeFingerTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleThreeFinderTap(_:)))
		threeFingerTapGestureRecognizer.numberOfTouchesRequired = 3
		threeFingerTapGestureRecognizer.allowedTouchTypes = [0]
		threeFingerTapGestureRecognizer.cancelsTouchesInView = false
		threeFingerTapGestureRecognizer.delaysTouchesEnded = false
		view.addGestureRecognizer(threeFingerTapGestureRecognizer)

		let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
		longPressGestureRecognizer.numberOfTouchesRequired = 1
		longPressGestureRecognizer.allowedTouchTypes = [0, 2]
		longPressGestureRecognizer.allowableMovement = 40
		// Don't cancel the overlay's touch, so the click-hold button can be released on lift.
		longPressGestureRecognizer.cancelsTouchesInView = false
		view.addGestureRecognizer(longPressGestureRecognizer)

		menuEdgeSwipe = addMenuEdgeSwipe(.left)
		menuEdgeSwipeRight = addMenuEdgeSwipe(.right)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(keyboardWillShow),
			name: UIResponder.keyboardWillShowNotification,
			object: nil
		)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(inputWasReleased),
			name: NSNotification.Name("ParsecInputReleased"),
			object: nil
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(keyboardWillHide),
			name: UIResponder.keyboardWillHideNotification,
			object: nil
		)

		// Backgrounding / Control Center / system alerts can orphan touches; flush on resign.
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(appWillResignActive),
			name: UIApplication.willResignActiveNotification,
			object: nil
		)

	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)

		let h = size.height
		let w = size.width

		// Reset zoom on rotation
		scrollView.zoomScale = 1.0

		self.glkView.updateSize(width: w, height: h)
		contentView.frame.size = CGSize(width: w, height: h)
		scrollView.contentSize = CGSize(width: w, height: h)
		// iPhone Duo: get scale from the view's screen, not UIScreen.main
		CParsec.setFrame(w, h, view.window?.screen.scale ?? 2.0)

        // Reset accessory view to ensure correct width in new orientation
        clearToolbarModifiers(sendToHost: true)
        keyboardAccessoriesView = nil
        if keyboardVisible {
            reloadInputViews()
        }
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		// glkView/contentView get sized from possibly-stale bounds in viewDidLoad and have no
		// autoresizing, so the stream renders in a corner until a rotation re-applies the size.
		// re-apply once layout settles; skip while zoomed so we dont stomp pan/zoom.
		guard scrollView != nil, scrollView.zoomScale == 1.0 else { return }
		let w = view.bounds.width
		let h = view.bounds.height
		guard w > 0, h > 0, w != lastLaidOutWidth || h != lastLaidOutHeight else { return }
		lastLaidOutWidth = w
		lastLaidOutHeight = h
		glkView.updateSize(width: w, height: h)
		contentView.frame.size = CGSize(width: w, height: h)
		scrollView.contentSize = CGSize(width: w, height: h)
		// iPhone Duo: get scale from the view's screen, not UIScreen.main
		CParsec.setFrame(w, h, view.window?.screen.scale ?? 2.0)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		UIApplication.shared.isIdleTimerDisabled = true
		if let parent = parent {
			parent.setChildForHomeIndicatorAutoHidden(self)
			parent.setChildViewControllerForPointerLock(self)
		}
		if keyboardVisible {
			becomeFirstResponder()
		}
		// (Pinch-to-zoom is driven manually via touchOverlay; the scroll view's pinch stays off.)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		UIApplication.shared.isIdleTimerDisabled = false
		stopMomentum()
		if let parent = parent {
			parent.setChildForHomeIndicatorAutoHidden(nil)
			parent.setChildViewControllerForPointerLock(nil)
		}
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
	}
	
	
	private var repeatTimer: Timer?
	private var repeatKeyCode: Int = -1
	private var optCmdRemapActive = false
	private var altKeyHeld = false

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		for press in presses {
			guard let key = press.key else { continue }

			if key.keyCode == .keyboardLeftAlt || key.keyCode == .keyboardRightAlt {
				altKeyHeld = true
			}

			if SettingsHandler.optionAsCommand && !isModifierKey(key.keyCode) && (altKeyHeld || key.modifierFlags.contains(.alternate)) {
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
			if height > 0 && SettingsHandler.cursorMode == .direct {
				onKeyboardCoversPicture?()
			}
			if SettingsHandler.cursorMode == .direct {
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
		setPanHandleVisible(keyboardCoversPicture && SettingsHandler.cursorMode == .direct)
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


extension ParsecViewController: UIPointerInteractionDelegate {
	func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
		return UIPointerStyle.hidden()
	}

	func pointerInteraction(_ inter: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
		let loc = request.location
		if let iv = view!.hitTest(loc, with: nil) {
			let rect = view!.convert(iv.bounds, from: iv)
			let region = UIPointerRegion(rect: rect, identifier: iv.tag)
			return region
		}
		return nil
	}

}



