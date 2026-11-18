import Foundation
import SwiftUI

// MARK: - Settings Store

/// Observable singleton wrapping `UserDefaults` for all user settings.
final class SettingsStore: ObservableObject {
	static let shared = SettingsStore()
	private let defaults = UserDefaults.standard

	private init() {
		defaults.register(defaults: [
			"rendererChoice": RendererType.metal.rawValue,
			"resolution": ParsecResolution.client.rawValue,
			"bitrate": 0,
			"decoder": DecoderPref.h264.rawValue,
			"cursorMode": CursorMode.touchpad.rawValue,
			"cursorScale": 0.5,
			"mouseSensitivity": 1.0,
			"optionAsCommand": false,
			"menuSwipeEdge": MenuSwipeEdge.off.rawValue,
			"noOverlay": false,
			"hideStatusBar": true,
			"rightClickPosition": RightClickPosition.firstFinger.rawValue,
			"reverseScrollDirection": false,
			"scrollSensitivity": 1.5,
			"preferredFramesPerSecond": 60,
			"showKeyboardButton": true,
			"alwaysShowStatus": false,
			"enablePiP": false,
			"startMuted": false,
			"autoReconnectEnabled": true,
			"errorPrompts": false,
			"showConnectionLog": true,
			"autoConnectOnLaunch": false,
			"savedZoomEnabled": false,
			"savedConstantFps": false
		])
		// values saved back when saving was off would now always apply
		if defaults.object(forKey: "saveSessionSettings") as? Bool == false {
			defaults.set(false, forKey: "savedZoomEnabled")
			defaults.set(false, forKey: "savedConstantFps")
		}
		defaults.removeObject(forKey: "saveSessionSettings")
	}

	private func store(_ value: Any, _ key: String) {
		if let current = defaults.object(forKey: key), (current as? NSObject)?.isEqual(value) == true {
			return
		}
		objectWillChange.send()
		defaults.set(value, forKey: key)
	}

	var renderer: RendererType {
		get { RendererType(rawValue: defaults.integer(forKey: "rendererChoice")) ?? .metal }
		set { store(newValue.rawValue, "rendererChoice") }
	}

	var resolution: ParsecResolution {
		get { ParsecResolution(rawValue: defaults.string(forKey: "resolution") ?? "") ?? .client }
		set { store(newValue.rawValue, "resolution") }
	}

	var bitrate: Int {
		get { defaults.integer(forKey: "bitrate") }
		set { store(newValue, "bitrate") }
	}

	var decoder: DecoderPref {
		get { DecoderPref(rawValue: defaults.integer(forKey: "decoder")) ?? .h264 }
		set { store(newValue.rawValue, "decoder") }
	}

	var cursorMode: CursorMode {
		get { CursorMode(rawValue: defaults.integer(forKey: "cursorMode")) ?? .touchpad }
		set { store(newValue.rawValue, "cursorMode") }
	}

	var cursorScale: Double {
		get { defaults.double(forKey: "cursorScale") }
		set { store(newValue, "cursorScale") }
	}

	var mouseSensitivity: Double {
		get { defaults.double(forKey: "mouseSensitivity") }
		set { store(newValue, "mouseSensitivity") }
	}

	var optionAsCommand: Bool {
		get { defaults.bool(forKey: "optionAsCommand") }
		set { store(newValue, "optionAsCommand") }
	}

	var menuSwipeEdge: MenuSwipeEdge {
		get { MenuSwipeEdge(rawValue: defaults.integer(forKey: "menuSwipeEdge")) ?? .off }
		set { store(newValue.rawValue, "menuSwipeEdge") }
	}

	var noOverlay: Bool {
		get { defaults.bool(forKey: "noOverlay") }
		set { store(newValue, "noOverlay") }
	}

	var hideStatusBar: Bool {
		get { defaults.bool(forKey: "hideStatusBar") }
		set { store(newValue, "hideStatusBar") }
	}

	var rightClickPosition: RightClickPosition {
		get { RightClickPosition(rawValue: defaults.integer(forKey: "rightClickPosition")) ?? .firstFinger }
		set { store(newValue.rawValue, "rightClickPosition") }
	}

	var reverseScrollDirection: Bool {
		get { defaults.bool(forKey: "reverseScrollDirection") }
		set { store(newValue, "reverseScrollDirection") }
	}

	var scrollSensitivity: Double {
		get { defaults.double(forKey: "scrollSensitivity") }
		set { store(newValue, "scrollSensitivity") }
	}

	var preferredFramesPerSecond: Int { // 0 = use device max (ProMotion)
		get { defaults.integer(forKey: "preferredFramesPerSecond") }
		set { store(newValue, "preferredFramesPerSecond") }
	}

	var showKeyboardButton: Bool {
		get { defaults.bool(forKey: "showKeyboardButton") }
		set { store(newValue, "showKeyboardButton") }
	}

	var alwaysShowStatus: Bool {
		get { defaults.bool(forKey: "alwaysShowStatus") }
		set { store(newValue, "alwaysShowStatus") }
	}

	var enablePiP: Bool {
		get { defaults.bool(forKey: "enablePiP") }
		set { store(newValue, "enablePiP") }
	}

	var startMuted: Bool {
		get { defaults.bool(forKey: "startMuted") }
		set { store(newValue, "startMuted") }
	}

	var autoReconnect: Bool {
		get { defaults.bool(forKey: "autoReconnectEnabled") }
		set { store(newValue, "autoReconnectEnabled") }
	}

	var errorPrompts: Bool {
		get { defaults.bool(forKey: "errorPrompts") }
		set { store(newValue, "errorPrompts") }
	}

	var showConnectionLog: Bool {
		get { defaults.bool(forKey: "showConnectionLog") }
		set { store(newValue, "showConnectionLog") }
	}

	var autoConnectOnLaunch: Bool {
		get { defaults.bool(forKey: "autoConnectOnLaunch") }
		set { store(newValue, "autoConnectOnLaunch") }
	}

	var zoomEnabled: Bool {
		get { defaults.bool(forKey: "savedZoomEnabled") }
		set { store(newValue, "savedZoomEnabled") }
	}

	var constantFps: Bool {
		get { defaults.bool(forKey: "savedConstantFps") }
		set { store(newValue, "savedConstantFps") }
	}
}
