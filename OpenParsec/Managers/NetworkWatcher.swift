import Foundation
import Network

/// Monitors network connectivity and interface changes
final class NetworkWatcher {
	static let shared = NetworkWatcher()

	private let monitor = NWPathMonitor()
	private let queue = DispatchQueue(label: "netwatch")
	private var running = false
	private var offline = false
	private(set) var noNetwork = false
	private(set) var interfaceDescription = "unknown"
	private var known = false
	private var interface: NWInterface.InterfaceType?
	private(set) var interfaceChanges = 0
	private var waiting: [() -> Void] = []

	var onReturn: (() -> Void)?

	func start() {
		if running { return }
		running = true

		monitor.pathUpdateHandler = { [weak self] path in
			let status = path.status
			let type = [NWInterface.InterfaceType.wifi, .cellular, .wiredEthernet].first { path.usesInterfaceType($0) }
			let interface = path.usesInterfaceType(.wifi) ? "Wi-Fi" : path.usesInterfaceType(.cellular) ? "cellular" : path.usesInterfaceType(.wiredEthernet) ? "Ethernet" : "other"
			DispatchQueue.main.async {
				guard let self = self else { return }
				self.noNetwork = status == .unsatisfied
				self.interfaceDescription = interface
				appNote("[network] \(interface), \(status == .satisfied ? "available" : "unavailable"); LAN permission unknown")
				if status == .satisfied, let type = type {
					if let old = self.interface, old != type {
						self.interfaceChanges += 1
					}
					self.interface = type
				}
				if !self.known {
					self.known = true
					let runs = self.waiting
					self.waiting = []
					runs.forEach { $0() }
				}
				if status == .satisfied {
					guard self.offline else { return }
					self.offline = false
					self.onReturn?()
				} else {
					self.offline = true
				}
			}
		}

		monitor.start(queue: queue)
	}

	func whenKnown(_ run: @escaping () -> Void) {
		if known { run() } else { waiting.append(run) }
	}
}
