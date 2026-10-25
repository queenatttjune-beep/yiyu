import AppKit
import SwiftUI

/// Keeps the panel pinned to the top-right corner of the main screen and switches it
/// between the full panel, the collapsed strip and hidden.
@MainActor
final class PanelController {
    private enum Layout {
        static let expandedWidth: CGFloat = 344
        static let expandedHeight: CGFloat = 600
        static let collapsedSize = CGSize(width: 300, height: 46)
        static let screenMargin: CGFloat = 10
    }

    private let panel: FloatingPanel
    private let ui: PanelState
    private var screenObserver: NSObjectProtocol?

    init(model: AppModel, ui: PanelState, dataFolder: URL) {
        self.panel = FloatingPanel()
        self.ui = ui

        let actions = PanelActions(
            toggleCollapsed: { [weak self] in self?.toggleCollapsed() },
            expand: { [weak self] in self?.expand(focus: true) },
            hidePanel: { [weak self] in self?.hide() },
            openDataFolder: { NSWorkspace.shared.open(dataFolder) },
            quit: { NSApp.terminate(nil) }
        )
        let hostingView = FirstMouseHostingView(rootView: RootView(model: model, ui: ui, actions: actions))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.onCancel = { [weak self] in self?.collapse() }
        panel.onNumberShortcut = { index in
            guard PanelTab.allCases.indices.contains(index) else { return }
            ui.tab = PanelTab.allCases[index]
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    var isVisible: Bool { panel.isVisible }
    var isCollapsed: Bool { ui.isCollapsed }

    #if DEBUG
    var debugWindow: NSPanel { panel }
    #endif

    func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggleVisible() {
        isVisible ? hide() : show()
    }

    func expand(focus: Bool, tab: PanelTab? = nil) {
        if let tab {
            ui.tab = tab
        }
        ui.isCollapsed = false
        reposition()
        panel.orderFrontRegardless()
        if focus {
            panel.makeKey()
            ui.focusRequest += 1
        }
    }

    func collapse() {
        let hadKeyboard = panel.isKeyWindow
        ui.isCollapsed = true
        if hadKeyboard {
            // Ordering out hands the keyboard back to the app underneath.
            panel.orderOut(nil)
        }
        reposition()
        panel.orderFrontRegardless()
    }

    func toggleCollapsed() {
        ui.isCollapsed ? expand(focus: true) : collapse()
    }

    /// ⌃⌥T: open and focus the panel; pressed again while typing in it, tuck it away.
    func toggleFromHotKey() {
        if !panel.isVisible || ui.isCollapsed {
            expand(focus: true)
        } else if panel.isKeyWindow {
            collapse()
        } else {
            panel.makeKey()
            ui.focusRequest += 1
        }
    }

    func reposition() {
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = ui.isCollapsed
            ? Layout.collapsedSize
            : CGSize(
                width: Layout.expandedWidth,
                height: min(Layout.expandedHeight, visible.height - Layout.screenMargin * 2)
            )
        let origin = CGPoint(
            x: visible.maxX - size.width - Layout.screenMargin,
            y: visible.maxY - size.height - Layout.screenMargin
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.invalidateShadow()
    }

    /// Light skins need light context menus, date pickers and text cursors.
    func applyAppearance(isDark: Bool) {
        panel.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
}
