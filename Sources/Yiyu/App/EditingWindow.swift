import AppKit

/// The app has no main menu, so this window handles the editing shortcuts and ⌘W itself.
final class EditingWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let shortcut = CommandShortcut(event) else {
            return super.performKeyEquivalent(with: event)
        }
        if let action = shortcut.editingAction, NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        if shortcut.key == "w" && !shortcut.isShifted {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
