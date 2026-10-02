import AppKit

/// A pan recognizer on the common ancestor handles text, controls, and empty
/// padding without covering those views with a hit-test-blocking overlay.
/// Delaying the primary mouse events lets a click reach its original control
/// only when the gesture fails (no drag), so dragging doesn't toggle playback.
final class WindowDrag: NSObject {
    private var origin: NSPoint?
    private var pointer: NSPoint?
    private weak var view: NSView?
    private(set) var recognizer: NSPanGestureRecognizer!

    init(view: NSView) {
        self.view = view
        super.init()
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.buttonMask = 1
        pan.delaysPrimaryMouseButtonEvents = true
        view.addGestureRecognizer(pan)
        recognizer = pan
    }

    @objc private func handlePan(_ pan: NSPanGestureRecognizer) {
        guard let window = view?.window else { return }
        switch pan.state {
        case .began:
            origin = window.frame.origin
            pointer = NSEvent.mouseLocation
        case .changed:
            guard let origin, let pointer else { return }
            window.setFrameOrigin(Self.movedOrigin(origin, from: pointer, to: NSEvent.mouseLocation))
        case .ended, .cancelled, .failed:
            origin = nil
            pointer = nil
        default:
            break
        }
    }

    static func movedOrigin(_ origin: NSPoint, from start: NSPoint, to end: NSPoint) -> NSPoint {
        NSPoint(x: origin.x + end.x - start.x, y: origin.y + end.y - start.y)
    }
}
