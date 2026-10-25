import AppKit

/// The menu bar icon: show or hide the panel, launch at login, quit.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let panel: PanelController
    private let dataFolder: URL
    private let isHotKeyAvailable: Bool

    init(panel: PanelController, dataFolder: URL, isHotKeyAvailable: Bool) {
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.panel = panel
        self.dataFolder = dataFolder
        self.isHotKeyAvailable = isHotKeyAvailable
        super.init()

        item.button?.image = Self.moonGateIcon()
        item.button?.toolTip = "一隅"
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        addItem(to: menu, title: panel.isVisible ? "隐藏面板" : "显示面板", action: #selector(toggleVisible))

        let collapseTitle = panel.isCollapsed ? "展开" : "收起"
        let collapse = addItem(to: menu, title: collapseTitle, action: #selector(toggleCollapsed))
        if isHotKeyAvailable {
            collapse.keyEquivalent = "t"
            collapse.keyEquivalentModifierMask = [.control, .option]
        } else {
            collapse.title = "\(collapseTitle)（⌃⌥T 被其他应用占用）"
        }

        menu.addItem(.separator())
        let reset = addItem(to: menu, title: "放回右上角", action: #selector(resetPosition))
        reset.isEnabled = panel.hasCustomPosition
        let login = addItem(to: menu, title: "登录时自动打开", action: #selector(toggleLoginItem))
        login.state = LoginItem.isEnabled ? .on : .off
        addItem(to: menu, title: "打开数据文件夹", action: #selector(openDataFolder))
        let appearance = addItem(to: menu, title: "外观与皮肤…", action: #selector(showAppearanceSettings))
        appearance.keyEquivalent = ","
        addItem(to: menu, title: "天气设置…", action: #selector(showWeatherSettings))
        menu.addItem(.separator())
        let quit = addItem(to: menu, title: "退出一隅", action: #selector(quit))
        quit.keyEquivalent = "q"
    }

    @discardableResult
    private func addItem(to menu: NSMenu, title: String, action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menu.addItem(menuItem)
        return menuItem
    }

    @objc private func toggleVisible() {
        panel.toggleVisible()
    }

    @objc private func toggleCollapsed() {
        if !panel.isVisible {
            panel.expand(focus: true)
        } else {
            panel.toggleCollapsed()
        }
    }

    @objc private func resetPosition() {
        panel.resetPosition()
        if !panel.isVisible {
            panel.show()
        }
    }

    @objc private func toggleLoginItem() {
        let wanted = !LoginItem.isEnabled
        do {
            try LoginItem.setEnabled(wanted)
        } catch {
            let alert = NSAlert()
            alert.messageText = wanted ? "没能加入登录项" : "没能移出登录项"
            alert.informativeText = "\(error.localizedDescription)\n可以在 系统设置 › 通用 › 登录项 里手动调整。"
            alert.runModal()
        }
    }

    @objc private func openDataFolder() {
        NSWorkspace.shared.open(dataFolder)
    }

    @objc private func showAppearanceSettings() {
        AppearanceCommand.open()
    }

    @objc private func showWeatherSettings() {
        WeatherCommand.open()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// A moon gate standing on the ground with a plum blossom inside, like the collapsed badge.
    /// Laid out top-down on an 18 × 18 template.
    private static func moonGateIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let ground: CGFloat = 15.2
            let lineWidth: CGFloat = 1.35
            NSColor.black.set()

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: 18, height: ground)).addClip()
            let gate = NSBezierPath(ovalIn: NSRect(x: 9 - 6.8, y: 10.02 - 6.8, width: 13.6, height: 13.6))
            gate.lineWidth = lineWidth
            gate.stroke()
            NSGraphicsContext.restoreGraphicsState()

            let groundLine = NSBezierPath()
            groundLine.move(to: NSPoint(x: 1.2, y: ground))
            groundLine.line(to: NSPoint(x: 16.8, y: ground))
            groundLine.lineWidth = lineWidth
            groundLine.lineCapStyle = .round
            groundLine.stroke()

            let stem = NSBezierPath()
            stem.move(to: NSPoint(x: 9, y: 12.4))
            stem.curve(to: NSPoint(x: 7.6, y: ground), controlPoint1: NSPoint(x: 8.87, y: 13.47), controlPoint2: NSPoint(x: 8.4, y: 14.4))
            stem.lineWidth = 1.1
            stem.lineCapStyle = .round
            stem.stroke()

            let blossom = NSPoint(x: 9, y: 9.3)
            let petalRadius: CGFloat = 1.63
            for index in 0..<5 {
                let angle = (-90 + CGFloat(index) * 72) * .pi / 180
                let petal = NSPoint(x: blossom.x + cos(angle) * 2.22, y: blossom.y + sin(angle) * 2.22)
                NSBezierPath(ovalIn: NSRect(
                    x: petal.x - petalRadius, y: petal.y - petalRadius, width: petalRadius * 2, height: petalRadius * 2
                )).fill()
            }
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: NSRect(x: blossom.x - 0.95, y: blossom.y - 0.95, width: 1.9, height: 1.9)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
