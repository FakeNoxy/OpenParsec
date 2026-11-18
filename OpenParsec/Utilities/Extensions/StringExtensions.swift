import Foundation

/// String helpers for the Parsec client.
extension String {
	static func fromBuffer(_ ptr: UnsafeMutablePointer<CChar>, length len: Int) -> String {
		// convert C char bytes using the UTF8 encoding
		let nsstr = NSString(bytes: ptr, length: len, encoding: NSUTF8StringEncoding)
		return nsstr! as String
	}
}
