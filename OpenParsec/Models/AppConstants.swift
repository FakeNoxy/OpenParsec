import Foundation
import SwiftUI

enum AppConstants {
	static let sessionKeyChainKey = "OPStoredAuthData"

	/// Single source of truth for the Parsec API base URL.
	static let apiBaseURL = URL(string: "https://kessel-api.parsec.app")!

	/// Single source of truth for the Parsec API User-Agent string.
	static let userAgent = "parsec/150-93b Windows/11 libmatoya/4.0"
}

var appScheme: ColorScheme = .dark
