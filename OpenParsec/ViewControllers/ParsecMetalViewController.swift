import UIKit
import MetalKit

extension MTKView: RenderLoop {}

class ParsecMetalViewController: ParsecRendererView {

	var metalView: MTKView!
	let metalRenderer: ParsecMetalRenderer?
	let updateImage: () -> Void
	weak var viewController: UIViewController?

	var renderView: UIView { metalView }

	required init(viewController: UIViewController, updateImage: @escaping () -> Void) {
		self.viewController = viewController
		self.updateImage = updateImage
		metalRenderer = MTLCreateSystemDefaultDevice().flatMap { ParsecMetalRenderer($0, updateImage) }
	}

	public func viewDidLoad() {
		// iPhone Duo: size from parent view bounds, not UIScreen.main
		let bounds = viewController?.view.bounds ?? .zero
		metalView = MTKView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height), device: metalRenderer?.device)
		metalView.colorPixelFormat = .bgra8Unorm
		metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
		metalView.autoResizeDrawable = false
		let fps = SettingsHandler.preferredFramesPerSecond
		// iPhone Duo: get max FPS from the view's screen, not UIScreen.main
		let maxFPS = metalView.window?.screen.maximumFramesPerSecond ?? 60
		metalView.preferredFramesPerSecond = fps == 0 ? maxFPS : fps
		metalView.delegate = metalRenderer
		ParsecBackgroundManager.shared.glkViewController = metalView
	}

	func cleanUp() {
		metalView?.isPaused = true
		metalRenderer?.reset()
	}

	func updateSize(width: CGFloat, height: CGFloat) {
		metalView.frame.size.width = width
		metalView.frame.size.height = height
	}
}

