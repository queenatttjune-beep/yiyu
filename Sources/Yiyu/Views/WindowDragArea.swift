import AppKit
import SwiftUI
import YiyuCore

/// A transparent area that moves its window when dragged. A press that barely moves
/// counts as a click and runs `onClick` instead.
struct WindowDragArea: NSViewRepresentable {
    let hint: String
    var onClick: (@MainActor () -> Void)?
    let onDragEnd: @MainActor () -> Void

    func makeNSView(context: Context) -> DragHandleView {
        let view = DragHandleView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: DragHandleView, context: Context) {
        view.toolTip = hint
        view.onClick = onClick
        view.onDragEnd = onDragEnd
    }
}

final class DragHandleView: NSView {
    var onClick: (@MainActor () -> Void)?
    var onDragEnd: (@MainActor () -> Void)?
    private var drag: PanelDrag?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        beginDrag(at: NSEvent.mouseLocation)
    }

    override func mouseDragged(with event: NSEvent) {
        continueDrag(to: NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        endDrag()
    }

    // The steps are separate from the mouse events so the debug tour can drive them.

    func beginDrag(at mouse: CGPoint) {
        guard let window else { return }
        drag = PanelDrag(mouse: mouse, origin: window.frame.origin)
    }

    func continueDrag(to mouse: CGPoint) {
        guard let window, let origin = drag?.update(mouse: mouse) else { return }
        if drag?.isDragging == true {
            NSCursor.closedHand.set()
        }
        window.setFrameOrigin(origin)
    }

    func endDrag() {
        guard let finished = drag else { return }
        drag = nil
        if finished.isDragging {
            NSCursor.openHand.set()
            onDragEnd?()
        } else {
            onClick?()
        }
    }
}
