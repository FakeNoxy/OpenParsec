import Foundation
import ParsecSDK

class CursorPositionHelper {
	static func toHost(_ xp: Int, _ yp: Int) -> (Int, Int) {
		let xh = CParsec.hostWidth
		let yh = CParsec.hostHeight
		let xc = CParsec.clientWidth
		let yc = CParsec.clientHeight

		let tc = yc / xc
		let th = yh / xh

		var xa: Float
		var ya: Float
		if th < tc {
			xa = Float(xp) * xh / xc
			ya = (Float(yp) - 0.5 * (yc - xc*th)) * xh / xc
		} else {
			ya = Float(yp) * yh / yc
			xa = (Float(xp) - 0.5 * (xc - yc/th)) * yh / yc
		}

		return (Int(ParsecSDKBridge.clamp(xa, minValue: 0, maxValue: CParsec.hostWidth)), Int(ParsecSDKBridge.clamp(ya, minValue: 0, maxValue: CParsec.hostHeight)))
	}

	static func toClient(_ xa: Int, _ ya: Int) -> (Int, Int) {
		let xh = CParsec.hostWidth
		let yh = CParsec.hostHeight
		let xc = CParsec.clientWidth
		let yc = CParsec.clientHeight

		let tc = yc / xc
		let th = yh / xh

		var xp: Float
		var yp: Float
		if th < tc {
			xp = Float(xa) * xc / xh
			yp = Float(ya) * xc / xh + 0.5 * (yc - xc*th)
		} else {
			yp = Float(ya) * yc / yh
			xp = Float(xa) * yc / yh + 0.5 * (xc - yc/th)
		}

		return (Int(ParsecSDKBridge.clamp(xp, minValue: 0, maxValue: CParsec.clientWidth)), Int(ParsecSDKBridge.clamp(yp, minValue: 0, maxValue: CParsec.clientHeight)))
	}
}
