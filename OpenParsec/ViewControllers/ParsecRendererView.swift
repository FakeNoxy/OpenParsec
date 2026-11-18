import UIKit

/// Common contract shared by the GLK and Metal renderer view controllers.
protocol ParsecRendererView {
	init(viewController: UIViewController, updateImage: @escaping () -> Void)
	var renderView: UIView { get }
	func viewDidLoad()
	func cleanUp()
	func updateSize(width: CGFloat, height: CGFloat)
}
