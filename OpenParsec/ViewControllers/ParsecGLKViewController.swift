import UIKit
import GLKit

class ParsecGLKViewController: ParsecPlayground {

	var glkView: GLKView!
	let glkViewController = GLKViewController()
	var glkRenderer: ParsecGLKRenderer!
	let updateImage: () -> Void

	weak var viewController: UIViewController?

	required init(viewController: UIViewController, updateImage: @escaping () -> Void) {
		self.viewController = viewController
		self.updateImage = updateImage
	}

	public func viewDidLoad() {
		// iPhone Duo: size from parent view bounds, not UIScreen.main
		let bounds = viewController?.view.bounds ?? .zero
		glkView = GLKView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
		glkRenderer = ParsecGLKRenderer(glkView, glkViewController, updateImage)
		self.viewController?.view.addSubview(glkView)
		setupGLKViewController()
		ParsecBackgroundManager.shared.glkViewController = glkViewController

	}

	private func setupGLKViewController() {
		glkView.context = EAGLContext(api: .openGLES3)!
		glkViewController.view = glkView

		// Use configured FPS or device max (for ProMotion displays)
		let fps = SettingsHandler.preferredFramesPerSecond
		if fps == 0 {
			// iPhone Duo: get max FPS from the view's screen, not UIScreen.main
			let maxFPS = glkView.window?.screen.maximumFramesPerSecond ?? 60
			glkViewController.preferredFramesPerSecond = Int(maxFPS)
		} else {
			glkViewController.preferredFramesPerSecond = fps
		}

		if let parent = viewController {
			parent.addChild(glkViewController)
			parent.view.addSubview(glkViewController.view)
			glkViewController.didMove(toParent: parent)
		}
	}

	var eaglContext: EAGLContext? {
		return glkView?.context
	}

	var renderView: UIView { glkView }

	func cleanUp() {
		guard let context = eaglContext else { return }
		EAGLContext.setCurrent(context)
		CParsec.glDestroy()
	}

	func updateSize(width: CGFloat, height: CGFloat) {
		glkView.frame.size.width = width
		glkView.frame.size.height = height
	}

}

