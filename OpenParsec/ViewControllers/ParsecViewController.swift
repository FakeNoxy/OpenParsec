import Foundation
import UIKit
import ParsecSDK
import QuartzCore
import os

class ParsecViewController: UIViewController, UIScrollViewDelegate, ParsecTouchInputDelegate {
	var glkView: ParsecRendererView!
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
	var panStartOffset: CGPoint = .zero
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
	
	
	var repeatTimer: Timer?
	var repeatKeyCode: Int = -1
	var optCmdRemapActive = false
	var altKeyHeld = false

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



