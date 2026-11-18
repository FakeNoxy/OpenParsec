import SwiftUI

/// SwiftUI `View` availability shims.
extension View {
	func prefersPersistentSystemOverlaysHidden() -> some View {
		if #available(iOS 16, *) {
			return self.persistentSystemOverlays(.hidden)
		} else {
			return self
		}
	}
}
