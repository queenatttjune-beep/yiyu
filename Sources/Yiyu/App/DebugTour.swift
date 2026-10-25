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

    let panel: PanelController
    let model: AppModel
    let ui: PanelState
    let polisher: DiaryPolisher

    private var window: NSPanel { panel.debugWindow }

    static var requestedMode: Mode? {
        ProcessInfo.processInfo.environment["YIYU_TOUR"].flatMap(Mode.init(rawValue:))
    }

    static var isRequested: Bool { requestedMode != nil }

    static func runIfRequested(panel: PanelController, model: AppModel, ui: PanelState, polisher: DiaryPolisher) {
        guard let mode = requestedMode else { return }
        let tour = DebugTour(panel: panel, model: model, ui: ui, polisher: polisher)
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
        for tab in [PanelTab.today, .backlog, .reminders, .memos] {
            ui.tab = tab
            await step(tab.rawValue)
        }
        ui.openMemoID = model.memos(matching: "").first?.id
        await step("memo-editor")
        ui.openMemoID = nil

        ui.tab = .diary
        await step("diary")
        await polishTour()

        model.addReminder("一隅提醒测试", at: Date().addingTimeInterval(1), repeatRule: .none)
        try? await Task.sleep(for: .seconds(2))
        model.tick()
        ui.tab = .today
        check("a reminder going off shows the banner", model.firedReminders.contains { $0.title == "一隅提醒测试" })
        await step("fired-banner")

        panel.collapse()
        await settle()
        check("collapsing shrinks the panel to a strip", ui.isCollapsed && window.frame.height < 60)
        check("the panel never took the keyboard", !window.isKeyWindow)
        await step("collapsed")

        panel.expand(focus: false)
        await settle()
        check("expanding restores the panel", !ui.isCollapsed && window.frame.height > 300)
    }

    /// Runs against scripts/mock-ai-server.py when ui-tour.sh started it.
    private func polishTour() async {
        guard ProcessInfo.processInfo.environment["YIYU_TOUR_AI_URL"] != nil else {
            log("SKIP polish checks: no mock AI server")
            return
        }
        let today = model.today
        let original = model.diaryText(for: today)

        polisher.open()
        polisher.isShowingSettings = true
        await step("polish-settings")
        polisher.isShowingSettings = false

        model.addStyle(name: "第三人称", instruction: "改成第三人称叙述")
        let poetic = WritingStyle.builtIns[1]
        polisher.selectedStyleID = poetic.id
        await step("polish-styles")

        polisher.polish(original, style: poetic)
        for _ in 0..<50 where polisher.phase == .working {
            try? await Task.sleep(for: .milliseconds(100))
        }
        let expected = "诗意风格：\(original.trimmingCharacters(in: .whitespacesAndNewlines))"
        check("polishing sends the chosen style and strips <think>", polisher.phase == .done(expected))
        await step("polish-result")

        polisher.accept(into: model, day: today)
        check("using the version replaces the entry", model.diaryText(for: today) == expected)
        check("undo is offered right after", polisher.canUndo(in: model, day: today))
        await step("polish-accepted")

        polisher.undo(in: model, day: today)
        check("undo restores the original", model.diaryText(for: today) == original)

        polisher.open()
        polisher.polish("", style: poetic)
        check("an empty day explains itself", polisher.phase == .failed(PolishError.emptyDiary.userMessage))
        polisher.close()
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

    private func step(_ name: String) async {
        log("STEP \(name)")
        try? await Task.sleep(for: Self.shotPause)
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
