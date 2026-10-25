import AppKit
import SwiftUI

/// A borderless panel that floats above other windows on every Space and takes keyboard
/// input without activating the app, so whatever you were working in stays in front.
final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?
    /// ⌘1…⌘9, zero-based. Handled here so it works even while a text field has focus.
    var onNumberShortcut: ((Int) -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .utilityWindow
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool {
        #if DEBUG
        // Read-only tours must not take input, even if AppKit promotes a window or it is clicked.
        if DebugTour.requestedMode == .gallery || DebugTour.requestedMode == .garden { return false }
        #endif
        return true
    }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// The app has no main menu while it stays in the background, so route the
    /// standard editing shortcuts to the focused text field ourselves.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let shortcut = CommandShortcut(event) else {
            return super.performKeyEquivalent(with: event)
        }
        if let action = shortcut.editingAction, NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        if let number = shortcut.number, let onNumberShortcut {
            onNumberShortcut(number - 1)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// A ⌘-key press, without ⌃ or ⌥.
struct CommandShortcut {
    let key: String
    let isShifted: Bool

    init?(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.control), !flags.contains(.option),
              let key = event.charactersIgnoringModifiers?.lowercased()
        else { return nil }
        self.key = key
        self.isShifted = flags.contains(.shift)
    }

    var editingAction: Selector? {
        switch (key, isShifted) {
        case ("x", false): #selector(NSText.cut(_:))
        case ("c", false): #selector(NSText.copy(_:))
        case ("v", false): #selector(NSText.paste(_:))
        case ("a", false): #selector(NSText.selectAll(_:))
        case ("z", false): Selector(("undo:"))
        case ("z", true): Selector(("redo:"))
        default: nil
        }
    }

    var number: Int? {
        guard !isShifted, let value = Int(key), (1...9).contains(value) else { return nil }
        return value
    }
}

/// Lets the first click on an inactive panel reach the button under the pointer.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
