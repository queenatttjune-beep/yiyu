import AppKit
import SwiftUI

/// The 外观与皮肤 window. Built on first use and kept, so it reopens where it was left.
@MainActor
final class AppearanceWindowController {
    private static let size = NSSize(width: 780, height: 680)

    let model: AppearanceModel
    private var window: NSWindow?

    init(model: AppearanceModel) {
        self.model = model
    }

    #if DEBUG
    var debugWindow: NSWindow? { window }
    #endif

    /// With `activate: false` the window only comes to the front; the keyboard stays where it was.
    func show(activate: Bool = true) {
        let window = self.window ?? makeWindow()
        self.window = window
        guard activate else {
            window.orderFrontRegardless()
            return
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let window = EditingWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "外观与皮肤"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AppearanceSettingsView(model: model))
        window.center()
        return window
    }
}

/// The app has no main menu, so this window handles the editing shortcuts and ⌘W itself.
private final class EditingWindow: NSWindow {
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

/// Opens the appearance window from any view or menu: the action travels up the responder chain to the app delegate.
@MainActor
enum AppearanceCommand {
    static func open() {
        NSApp.sendAction(#selector(AppDelegate.showAppearanceSettings(_:)), to: nil, from: nil)
    }
}
