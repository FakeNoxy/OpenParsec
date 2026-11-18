import SwiftUI
import Combine

/// Owns the live stream metric string (decode/encode/network latency, bitrate,
/// draw fps, codec/resolution) that `ReconnectController.poll(showMenu:)`
/// rebuilds every 0.5 s.
///
/// Kept as a *separate* `ObservableObject` on purpose: `ParsecView` holds
/// `ReconnectController` as a `@StateObject`, so any `@Published` write on it
/// re-evaluates `ParsecView`'s body and re-presents the UIKit-backed
/// Resolution/Bitrate `Menu`s (scroll position reset). The metric string
/// changes on nearly every poll, so it must live on an object that ONLY
/// `ParsecStatusBar` observes.
///
/// Not `@MainActor` on purpose (matches `ReconnectController`): all writes
/// happen on the main thread via the status bar's timer, and the test target
/// compiles `ReconnectController` (which now owns a `MetricsModel`) without
/// any actor-isolation friction.
final class MetricsModel: ObservableObject {
	@Published var info: String = "Loading..."
}
