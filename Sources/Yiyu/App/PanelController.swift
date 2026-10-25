import AppKit
import SwiftUI
import YiyuCore

/// Places the panel where the user last dragged it (the top-right corner of the main screen
/// until then) and switches it between the full panel, the collapsed strip and hidden.
@MainActor
final class PanelController {
    private enum Layout {
        static let expandedWidth: CGFloat = 344
        static let expandedHeight: CGFloat = 600
        static let collapsedSize = CGSize(width: PanelBadge.size, height: PanelBadge.size)
        static let screenMargin: CGFloat = 10
    }

    private let panel: FloatingPanel
    private let ui: PanelState
    private let anchorStore = PanelAnchorStore()
    private var screenObserver: NSObjectProtocol?

    init(model: AppModel, ui: PanelState, dataFolder: URL, polisher: DiaryPolisher) {
        self.panel = FloatingPanel()
        self.ui = ui

        let actions = PanelActions(
            toggleCollapsed: { [weak self] in self?.toggleCollapsed() },
            expand: { [weak self] in self?.expand(focus: true) },
            hidePanel: { [weak self] in self?.hide() },
            openDataFolder: { NSWorkspace.shared.open(dataFolder) },
            quit: { NSApp.terminate(nil) },
            panelDidMove: { [weak self] in self?.rememberPosition() },
            resetPosition: { [weak self] in self?.resetPosition() }
        )
        let hostingView = FirstMouseHostingView(rootView: RootView(model: model, ui: ui, actions: actions).environment(polisher))
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
    var hasCustomPosition: Bool { anchorStore.anchor != nil }

    #if DEBUG
    var debugWindow: NSPanel { panel }
    /// Set by the debug tour so its synthetic clicks never take the keyboard from the user.
    var keepsKeyboardAway = false
    #else
    let keepsKeyboardAway = false
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
        if focus && !keepsKeyboardAway {
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

    /// Called when a drag ends: keep the new spot, pulled back fully onto a screen.
    func rememberPosition() {
        anchorStore.anchor = PanelPlacement.anchor(of: panel.frame)
        reposition()
        anchorStore.anchor = PanelPlacement.anchor(of: panel.frame)
    }

    func resetPosition() {
        anchorStore.anchor = nil
        reposition()
    }

    func reposition() {
        let size = ui.isCollapsed
            ? Layout.collapsedSize
            : CGSize(width: Layout.expandedWidth, height: Layout.expandedHeight)
        let frame = PanelPlacement.frame(
            size: size,
            anchor: anchorStore.anchor,
            screens: NSScreen.screens.map(\.visibleFrame),
            margin: Layout.screenMargin
        )
        panel.setFrame(frame, display: true)
        // The shadow follows the drawn shape, which SwiftUI redraws on the next pass.
        DispatchQueue.main.async { [panel] in panel.invalidateShadow() }
    }
}
