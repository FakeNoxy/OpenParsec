import UIKit

protocol ParsecPlayground {
	init(viewController: UIViewController, updateImage: @escaping () -> Void)
	var renderView: UIView { get }
	func viewDidLoad()
	func cleanUp()
	func updateSize(width: CGFloat, height: CGFloat)
}
