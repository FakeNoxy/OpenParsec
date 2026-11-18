import SwiftUI
import ParsecSDK
import Foundation

// CRITICAL: This class exists to PERSIST the ParsecViewController instance across SwiftUI view updates.
// Do not remove or change to a struct. If ParsecViewController is recreated, the keyboard responder chain breaks.
class ParsecSession: ObservableObject {
    let controller: ParsecViewController

    init() {
        self.controller = ParsecViewController()
    }
}

struct MenuRowsHeightKey: PreferenceKey {
	static let defaultValue: CGFloat = 0

	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		value = max(value, nextValue())
	}
}
