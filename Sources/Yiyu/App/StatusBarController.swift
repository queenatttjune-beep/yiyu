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

        item.button?.image = Self.cornerIcon()
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// A rounded square with its top-right corner filled in: "一隅", a corner.
    private static func cornerIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            let outline = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 2.5, width: 13, height: 13), xRadius: 3.2, yRadius: 3.2)
            outline.lineWidth = 1.4
            outline.stroke()
            NSBezierPath(roundedRect: NSRect(x: 9.2, y: 9.2, width: 4.4, height: 4.4), xRadius: 1.2, yRadius: 1.2).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
