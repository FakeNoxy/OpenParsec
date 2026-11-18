import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	var window: UIWindow?

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		SessionCoordinator.shared.sceneWillConnect(shortcutType: connectionOptions.shortcutItem?.type)
		let contentView = ContentView()

		if let windowScene = scene as? UIWindowScene {
		    let window = UIWindow(windowScene: windowScene)
		    window.rootViewController = UIHostingController(rootView: contentView)
		    self.window = window
		    window.makeKeyAndVisible()
		}
	}

	func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
		guard shortcutItem.type == ParsecBackgroundManager.reconnectShortcut else {
			completionHandler(false)
			return
		}
		completionHandler(SessionCoordinator.shared.handleReconnectShortcut())
	}

	func sceneDidDisconnect(_ scene: UIScene) {
		SessionCoordinator.shared.sceneDidDisconnect()
	}

	func sceneDidBecomeActive(_ scene: UIScene) {
		SessionCoordinator.shared.sceneDidBecomeActive()
	}

	func sceneWillResignActive(_ scene: UIScene) {
		SessionCoordinator.shared.sceneWillResignActive()
	}

	func sceneWillEnterForeground(_ scene: UIScene) {
		SessionCoordinator.shared.sceneWillEnterForeground()
	}

	func sceneDidEnterBackground(_ scene: UIScene) {
		SessionCoordinator.shared.sceneDidEnterBackground()
	}
}
