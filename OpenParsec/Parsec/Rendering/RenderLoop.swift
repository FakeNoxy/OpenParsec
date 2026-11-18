import GLKit
import MetalKit

/// A render surface whose drawing loop can be paused/resumed.
/// Concretely a `GLKViewController` (OpenGL path) or an `MTKView` (Metal path).
protocol RenderLoop: AnyObject {
	var isPaused: Bool { get set }
}

extension GLKViewController: RenderLoop {}
extension MTKView: RenderLoop {}
