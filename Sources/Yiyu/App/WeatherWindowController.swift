import AppKit
import SwiftUI

/// The 天气设置 window. Built on first use and kept, so what was typed stays until it is saved.
@MainActor
final class WeatherWindowController: NSObject, NSWindowDelegate {
    let model: WeatherModel
    private var window: NSWindow?

    init(model: WeatherModel) {
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

    /// Same as the appearance window: give the keyboard back to the app the user came from.
    func windowWillClose(_ notification: Notification) {
        if NSApp.isActive {
            NSApp.deactivate()
        }
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingView(rootView: WeatherSettingsView(model: model))
        let window = EditingWindow(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "天气设置"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = hosting
        window.center()
        return window
    }
}

/// Opens the weather settings from any view or menu, through the responder chain to the app delegate.
@MainActor
enum WeatherCommand {
    static func open() {
        NSApp.sendAction(#selector(AppDelegate.showWeatherSettings(_:)), to: nil, from: nil)
    }
}
