import Foundation

/// Enumerations backing the user-facing settings choices.
enum RendererType: Int {
	case opengl
    case metal
}

enum DecoderPref: Int {
    case h264
    case h265
}

enum CursorMode: Int {
    case touchpad
    case direct
}

enum RightClickPosition: Int {
	case firstFinger
	case middle
	case secondFinger
}

enum MenuSwipeEdge: Int {
	case left
	case right
	case off
}
