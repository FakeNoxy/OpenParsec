import Foundation
import ParsecSDK
import UIKit
import Combine
import os

let sdkLog = OSLog(subsystem: "com.aigch.OpenParsec", category: "sdk")
let appLog = OSLog(subsystem: "com.aigch.OpenParsec", category: "app")

final class ConnectionLog: ObservableObject {
	static let shared = ConnectionLog()

	private struct Entry {
		var time: String
		let text: String
		var count: Int
	}

	@Published private(set) var lines: [String] = []
	private var entries: [Entry] = []
	private let lock = NSLock()
	private var pending: [(time: String, text: String)] = []
	private var flushScheduled = false
	private let clock: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "HH:mm:ss.S"
		return f
	}()

	func add(_ text: String) {
		let time = clock.string(from: Date())
		lock.lock()
		pending.append((time, text))
		let schedule = !flushScheduled
		flushScheduled = true
		lock.unlock()
		if schedule {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.flush() }
		}
	}

	private func flush() {
		lock.lock()
		let fresh = pending
		pending.removeAll()
		flushScheduled = false
		lock.unlock()
		for item in fresh {
			if let last = entries.indices.last, entries[last].text == item.text {
				entries[last].count += 1
				entries[last].time = item.time
			} else {
				entries.append(Entry(time: item.time, text: item.text, count: 1))
			}
		}
		if entries.count > 200 {
			entries.removeFirst(entries.count - 200)
		}
		lines = entries.map { "\($0.time) \($0.text)\($0.count > 1 ? " x\($0.count)" : "")" }
	}
}

func appNote(_ text: String) {
	os_log("%{public}@", log: appLog, text)
	ConnectionLog.shared.add(text)
}

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

struct KeyBoardKeyEvent {
	var input: UIKey?
	var isPressBegin: Bool
}
