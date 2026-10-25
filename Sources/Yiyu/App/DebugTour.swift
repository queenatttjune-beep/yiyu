#if DEBUG
import AppKit
import YiyuCore

/// UI smoke test for debug builds, printing `STEP <name>` before each pause so
/// `scripts/ui-tour.sh` can screenshot the window. Needs no Accessibility permission.
///
/// - `YIYU_TOUR=gallery` only changes UI state in code; the panel never takes the keyboard.
/// - `YIYU_TOUR=interactive` also sends synthetic clicks, typing and shortcuts. That makes the
///   panel the key window for about a minute, so anything typed on the Mac meanwhile lands in it.
@MainActor
struct DebugTour {
    enum Mode: String {
        case gallery
        case interactive
    }

    private static let settle: Duration = .milliseconds(450)
    private static let shotPause: Duration = .milliseconds(1800)
    /// Longest wait for `ui-tour.sh` to write a step's screenshot.
    private static let shotTimeout: Duration = .seconds(8)
    private static var stepsTaken = 0

    let panel: PanelController
    let model: AppModel
    let ui: PanelState

    private var window: NSPanel { panel.debugWindow }

    static var requestedMode: Mode? {
        ProcessInfo.processInfo.environment["YIYU_TOUR"].flatMap(Mode.init(rawValue:))
    }

    static var isRequested: Bool { requestedMode != nil }

    static func runIfRequested(panel: PanelController, model: AppModel, ui: PanelState) {
        guard let mode = requestedMode else { return }
        let tour = DebugTour(panel: panel, model: model, ui: ui)
        Task {
            tour.log("WINDOW \(panel.debugWindow.windowNumber)")
            try? await Task.sleep(for: .seconds(1))
            switch mode {
            case .gallery: await tour.runGallery()
            case .interactive: await tour.runInteractive()
            }
            tour.log("DONE")
        }
    }

    private func runGallery() async {
        panel.keepsKeyboardAway = true
        check("the panel starts as a small badge",
              ui.isCollapsed && window.frame.width <= PanelBadge.size && window.frame.height <= PanelBadge.size)
        await step("badge")
        panel.expand(focus: false)
        await settle()

        for tab in [PanelTab.today, .backlog, .reminders, .memos] {
            ui.tab = tab
            await step(tab.rawValue)
        }
        ui.openMemoID = model.memos(matching: "").first?.id
        await step("memo-editor")
        ui.openMemoID = nil

        ui.tab = .diary
        await step("diary")

        model.addReminder("一隅提醒测试", at: Date().addingTimeInterval(1), repeatRule: .none)
        try? await Task.sleep(for: .seconds(2))
        model.tick()
        ui.tab = .today
        check("a reminder going off shows the banner", model.firedReminders.contains { $0.title == "一隅提醒测试" })
        await step("fired-banner")

        panel.collapse()
        await settle()
        check("collapsing shrinks the panel to the badge", ui.isCollapsed && window.frame.width <= PanelBadge.size)
        check("a due reminder marks the badge",
              PanelBadge(todaySummary: model.todaySummary, dueReminders: model.dueReminders.count).needsAttention)
        await step("badge-attention")

        model.acknowledgeFired()
        for reminder in model.dueReminders {
            model.toggleReminder(reminder.id)
        }
        await settle()
        await step("badge-calm")

        panel.expand(focus: false)
        await settle()
        check("expanding restores the panel", !ui.isCollapsed && window.frame.height > 300)

        await runDragChecks()
        check("the panel never took the keyboard", !window.isKeyWindow)
    }

    /// Drives the drag handles through the same steps a mouse drag uses, without making the panel key.
    private func runDragChecks() async {
        panel.resetPosition()
        await settle()
        let home = window.frame
        guard let clickedHeader = dragHandles().first else {
            check("the header has a drag handle", false)
            return
        }

        clickedHeader.beginDrag(at: CGPoint(x: 1000, y: 800))
        clickedHeader.continueDrag(to: CGPoint(x: 1002, y: 801))
        clickedHeader.endDrag()
        await settle()
        check("clicking the header collapses the panel in place",
              ui.isCollapsed && PanelPlacement.anchor(of: window.frame) == PanelPlacement.anchor(of: home))
        dragHandles().first?.beginDrag(at: CGPoint(x: 500, y: 500))
        dragHandles().first?.endDrag()
        await settle()
        check("clicking the badge expands it again", !ui.isCollapsed && window.frame == home)
        guard let header = dragHandles().first else {
            check("the expanded header has a drag handle", false)
            return
        }

        let start = CGPoint(x: home.midX, y: home.maxY - 20)
        header.beginDrag(at: start)
        header.continueDrag(to: CGPoint(x: start.x - 200, y: start.y - 60))
        header.continueDrag(to: CGPoint(x: start.x - 400, y: start.y - 150))
        header.endDrag()
        await settle()
        let moved = window.frame
        check("dragging the header moves the panel with the pointer",
              moved.origin == CGPoint(x: home.minX - 400, y: home.minY - 150))
        check("the new position is saved", PanelAnchorStore().anchor == PanelPlacement.anchor(of: moved))
        check("the panel never took the keyboard while dragging", !window.isKeyWindow)
        await step("dragged")

        panel.collapse()
        await settle()
        check("collapsing keeps the dragged top-right corner",
              PanelPlacement.anchor(of: window.frame) == PanelPlacement.anchor(of: moved))
        if let strip = dragHandles().first {
            strip.beginDrag(at: CGPoint(x: 500, y: 500))
            strip.endDrag()
            await settle()
            check("clicking the dragged badge expands it", !ui.isCollapsed)
        } else {
            check("the badge has a drag handle", false)
        }

        dragHandles().first?.beginDrag(at: start)
        dragHandles().first?.continueDrag(to: CGPoint(x: -20000, y: -20000))
        dragHandles().first?.endDrag()
        await settle()
        let screens = NSScreen.screens.map(\.visibleFrame)
        check("a panel dragged off screen is pulled back on", screens.contains { $0.contains(window.frame) })

        panel.resetPosition()
        await settle()
        check("放回右上角 restores the default spot", window.frame == home && PanelAnchorStore().anchor == nil)
    }

    private func dragHandles() -> [DragHandleView] {
        func collect(_ view: NSView) -> [DragHandleView] {
            ((view as? DragHandleView).map { [$0] } ?? []) + view.subviews.flatMap(collect)
        }
        return window.contentView.map(collect) ?? []
    }

    /// A believable week of data around `now`, used when the tour starts from an empty folder.
    static func sampleData(now: Date, calendar: Calendar) -> AppData {
        let today = DayKey(now, calendar: calendar)
        func day(_ offset: Int) -> DayKey { today.adding(days: offset, calendar: calendar) }
        func at(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let start = day(offset).startOfDay(in: calendar)
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) ?? start
        }
        let hourAgo = now.addingTimeInterval(-3600)
        return AppData(
            todos: [
                Todo(title: "整理这周的照片", plannedDay: today, createdAt: at(0, 8, 30)),
                Todo(title: "回复房东的消息", plannedDay: day(-1), createdAt: at(-1, 9)),
                Todo(title: "买打印纸", plannedDay: today, completedAt: hourAgo, createdAt: at(-1, 23)),
                Todo(title: "备份手机相册", plannedDay: today, createdAt: at(0, 8, 10)),
                Todo(title: "看完《小王子》", createdAt: at(-3, 20)),
                Todo(title: "周末去拍银杏", plannedDay: day(6), createdAt: at(-2, 20)),
                Todo(title: "学做一道新菜", createdAt: at(-4, 20)),
            ],
            reminders: [
                Reminder(title: "取快递", fireAt: hourAgo, repeatRule: .none, isDone: false, createdAt: at(-1, 20)),
                Reminder(title: "开组会", fireAt: at(0, 21), repeatRule: .none, isDone: false, createdAt: at(-1, 20)),
                Reminder(title: "吃维生素", fireAt: at(1, 8), repeatRule: .daily, isDone: false, createdAt: at(-5, 20)),
                Reminder(title: "站会", fireAt: at(1, 9, 30), repeatRule: .weekdays, isDone: false, createdAt: at(-5, 20)),
            ],
            memos: [
                Memo(text: "出门清单\n钥匙、充电宝、雨伞、水杯", isPinned: true, createdAt: at(-5, 20), updatedAt: at(-2, 20)),
                Memo(text: "快递单号\nSF1234567890", isPinned: false, createdAt: at(-1, 20), updatedAt: at(-1, 20)),
                Memo(text: "周末想做的菜\n番茄炒蛋、红烧排骨、紫菜汤", isPinned: false, createdAt: at(-4, 20), updatedAt: at(0, 10)),
            ],
            diary: [
                DiaryEntry(
                    day: today,
                    text: "上午去公园走了一圈，银杏开始黄了，风一吹落了一地。\n\n下午把攒了好久的待办理了一遍，划掉了一半，心里轻松多了。",
                    updatedAt: at(0, 12)
                ),
                DiaryEntry(day: day(-2), text: "下雨，在家看书。", updatedAt: at(-2, 22)),
                DiaryEntry(day: day(-4), text: "试了楼下新开的面馆。", updatedAt: at(-4, 22)),
                DiaryEntry(day: day(-7), text: "和朋友去爬山。", updatedAt: at(-7, 22)),
            ]
        )
    }

    /// Kept short on purpose: the panel holds the keyboard for the whole run.
    private func runInteractive() async {
        panel.toggleFromHotKey()
        await settle()
        check("hot key focuses the panel", window.isKeyWindow && !ui.isCollapsed)
        insert("给绿萝浇水")
        submit()
        await settle()
        check("typed to-do lands in today", model.todayTodos.first?.title == "给绿萝浇水")

        click(x: 22, y: 163)
        await settle()
        check("clicking the circle completes it", model.data.todos.contains { $0.title == "给绿萝浇水" && $0.isDone })

        click(x: 71, y: 87)
        await settle()
        check("clicking 待办 switches tab", ui.tab == .backlog)

        pressCommand("3")
        await settle()
        check("⌘3 opens reminders", ui.tab == .reminders)
        focusInput()
        await settle()
        insert("明天下午3点 交读书报告")
        await step("reminder-preview")
        submit()
        await settle()
        let added = model.data.reminders.first { $0.title == "交读书报告" }
        check("parsed reminder is added for tomorrow 15:00",
              added.map { model.labels.reminderTime($0.fireAt, now: model.now) } == "明天 15:00")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("从剪贴板粘贴", forType: .string)
        pressCommand("v")
        await settle()
        check("⌘V pastes into the field", currentFieldText() == "从剪贴板粘贴")

        pressCommand("4")
        await settle()
        check("⌘4 works while a text field has focus", ui.tab == .memos)
        click(x: 323, y: 125)
        await settle()
        insert("周末拍摄")
        await settle()
        check("new memo is written", model.data.memos.contains { $0.title == "周末拍摄" })

        window.cancelOperation(nil)
        await settle()
        check("Esc collapses and gives the keyboard back", ui.isCollapsed && !window.isKeyWindow)
    }

    // MARK: - Helpers

    /// Pauses until `ui-tour.sh` has captured this step (it sets `YIYU_TOUR_SHOTS` to its
    /// screenshot folder), so slow captures never show a later state.
    private func step(_ name: String) async {
        Self.stepsTaken += 1
        log("STEP \(name)")
        guard let folder = ProcessInfo.processInfo.environment["YIYU_TOUR_SHOTS"] else {
            try? await Task.sleep(for: Self.shotPause)
            return
        }
        let deadline = ContinuousClock.now + Self.shotTimeout
        while ContinuousClock.now < deadline {
            let shots = (try? FileManager.default.contentsOfDirectory(atPath: folder))?
                .filter { $0.hasSuffix(".png") } ?? []
            if shots.count >= Self.stepsTaken { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
        log("SLOW screenshot for \(name)")
    }

    private func settle() async {
        try? await Task.sleep(for: Self.settle)
    }

    private func log(_ message: String) {
        print("TOUR \(message)")
        fflush(stdout)
    }

    private func check(_ name: String, _ passed: Bool) {
        log("\(passed ? "PASS" : "FAIL") \(name)")
    }

    /// `x`, `y` are points from the panel's top-left corner.
    private func click(x: CGFloat, y: CGFloat) {
        let location = NSPoint(x: x, y: window.frame.height - y)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(
                with: type, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0
            ) else { continue }
            NSApp.sendEvent(event)
        }
    }

    private func pressCommand(_ key: String) {
        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0
        ) else { return }
        NSApp.sendEvent(event)
    }

    private func focusInput() {
        ui.focusRequest += 1
    }

    private func insert(_ text: String) {
        NSApp.sendAction(#selector(NSResponder.insertText(_:)), to: nil, from: text)
    }

    private func submit() {
        sendAction(#selector(NSResponder.insertNewline(_:)))
    }

    private func sendAction(_ action: Selector) {
        NSApp.sendAction(action, to: nil, from: nil)
    }

    private func currentFieldText() -> String? {
        (window.firstResponder as? NSText)?.string
    }
}
#endif
