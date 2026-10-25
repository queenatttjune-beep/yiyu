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
        case editing
    }

    private static let settle: Duration = .milliseconds(450)
    private static let shotPause: Duration = .milliseconds(1800)
    /// Longest wait for `ui-tour.sh` to write a step's screenshot.
    private static let shotTimeout: Duration = .seconds(8)
    private static var stepsTaken = 0

    let panel: PanelController
    let model: AppModel
    let ui: PanelState
    let polisher: DiaryPolisher
    let appearanceWindow: AppearanceWindowController
    let weatherWindow: WeatherWindowController

    private var window: NSPanel { panel.debugWindow }

    static var requestedMode: Mode? {
        ProcessInfo.processInfo.environment["YIYU_TOUR"].flatMap(Mode.init(rawValue:))
    }

    static var isRequested: Bool { requestedMode != nil }

    static func runIfRequested(
        panel: PanelController, model: AppModel, ui: PanelState,
        polisher: DiaryPolisher, appearanceWindow: AppearanceWindowController, weatherWindow: WeatherWindowController
    ) {
        guard let mode = requestedMode else { return }
        let tour = DebugTour(
            panel: panel, model: model, ui: ui, polisher: polisher,
            appearanceWindow: appearanceWindow, weatherWindow: weatherWindow
        )
        Task {
            tour.log("WINDOW \(panel.debugWindow.windowNumber)")
            try? await Task.sleep(for: .seconds(1))
            switch mode {
            case .gallery:
                await tour.runGallery()
                await tour.runSkins()
                await tour.closeOutfitCard()
            case .interactive: await tour.runInteractive()
            case .editing: await tour.runEditing()
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
        await polishTour()
        await weatherTour()

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

    /// Runs against scripts/mock-ai-server.py when ui-tour.sh started it.
    private func polishTour() async {
        guard ProcessInfo.processInfo.environment["YIYU_TOUR_AI_URL"] != nil else {
            log("SKIP polish checks: no mock AI server")
            return
        }
        let today = model.today
        let original = model.diaryText(for: today)

        polisher.open(for: today)
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

        polisher.accept(into: model)
        check("using the version replaces the entry", model.diaryText(for: today) == expected)
        check("undo is offered right after", polisher.canUndo(in: model, day: today))
        await step("polish-accepted")

        polisher.undo(in: model, day: today)
        check("undo restores the original", model.diaryText(for: today) == original)

        polisher.open(for: today)
        polisher.polish("", style: poetic)
        check("an empty day explains itself", polisher.phase == .failed(PolishError.emptyDiary.userMessage))

        polisher.polish(original, style: poetic)
        ui.tab = .memos
        await settle()
        ui.tab = .diary
        await settle()
        check("a result stays with the day it was made for", polisher.targetDay == today)
        polisher.close()
    }

    /// Runs against scripts/mock-qweather-server.py when ui-tour.sh started it.
    private func weatherTour() async {
        guard let url = ProcessInfo.processInfo.environment["YIYU_TOUR_WEATHER_URL"] else {
            log("SKIP weather checks: no mock weather server")
            return
        }
        let weather = weatherWindow.model
        for _ in 0..<50 where weather.snapshot == nil {
            try? await Task.sleep(for: .milliseconds(100))
        }
        check("the forecast loads from 和风天气", weather.snapshot != nil && weather.problem == nil)
        check("the header shows the temperature now", weather.snapshot?.current.temperature == 19.6)
        check("the outfit card gives clothing advice",
              weather.visibleAdvice?.summary == "长袖衬衫或 T 恤；早晚只有 17°，带件薄外套；下午降水概率 55%，记得带伞。")
        ui.tab = .today
        await step("weather-today")

        let found = try? await weather.searchCities("杭州", host: url, newKey: "")
        check("city search finds 杭州", found?.first?.name == "杭州")
        do {
            _ = try await weather.searchCities("杭州", host: url, newKey: "wrong-key")
            check("a wrong API KEY is reported", false)
        } catch {
            check("a wrong API KEY is reported", WeatherFailure(error) == .service(.unauthorized))
        }

        weatherWindow.show(activate: false)
        await settle()
        if let settingsWindow = weatherWindow.debugWindow {
            await step("weather-settings", window: settingsWindow)
            log("INFO app active \(NSApp.isActive), settings key \(settingsWindow.isKeyWindow), panel key \(window.isKeyWindow), key window \(NSApp.keyWindow?.title ?? "none")")
            check("opening the weather settings left the keyboard alone",
                  !settingsWindow.isKeyWindow && !window.isKeyWindow)
        } else {
            check("the weather settings window opens", false)
        }
        weatherWindow.close()
    }

    /// Last, so the skin screenshots still show the card.
    private func closeOutfitCard() async {
        guard ProcessInfo.processInfo.environment["YIYU_TOUR_WEATHER_URL"] != nil else { return }
        let weather = weatherWindow.model
        ui.tab = .today
        weather.hideAdvice()
        await settle()
        check("closing the outfit card hides it for the day", weather.advice != nil && weather.visibleAdvice == nil)
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

    /// Uses only throwaway data, with real clicks and keyboard input through the row editors.
    private func runEditing() async {
        guard let folder = ProcessInfo.processInfo.environment["YIYU_DATA_DIR"], !folder.isEmpty else {
            check("editing tests require a throwaway data folder (YIYU_DATA_DIR)", false)
            return
        }
        panel.toggleFromHotKey()
        model.addTodo("编辑待办测试", forToday: true)
        await settle()
        click(x: 90, y: 163)
        click(x: 90, y: 163, count: 2)
        await settle()
        check("double-clicking a today to-do opens its existing content", currentFieldText() == "编辑待办测试")
        await step("todo-editor")
        pressCommand("a")
        insert("修改后的待办")
        submit()
        await settle()
        check("Return saves the to-do edit", model.todayTodos.first?.title == "修改后的待办")

        click(x: 90, y: 163)
        click(x: 90, y: 163, count: 2)
        await settle()
        pressCommand("a")
        insert("这次不保存")
        sendAction(#selector(NSResponder.cancelOperation(_:)))
        await settle()
        check("Escape cancels editing without collapsing the panel",
              !ui.isCollapsed && model.todayTodos.first?.title == "修改后的待办"
                  && currentFieldText() != "这次不保存")

        ui.tab = .backlog
        await settle()
        click(x: 90, y: 163)
        click(x: 90, y: 163, count: 2)
        await settle()
        check("the backlog also opens the saved to-do for editing", currentFieldText() == "修改后的待办")
        pressCommand("a")
        insert("   ")
        submit()
        await settle()
        check("a blank title stays in the editor and leaves the to-do unchanged",
              currentFieldText() == "   " && model.openTodos.first?.title == "修改后的待办")
        sendAction(#selector(NSResponder.cancelOperation(_:)))
        await settle()

        // Keep the reminder list deterministic, without the sample's due reminders or section labels.
        for reminder in model.data.reminders { model.deleteReminder(reminder.id) }
        model.addReminder("编辑提醒测试", at: Date().addingTimeInterval(7200), repeatRule: .none)
        ui.tab = .reminders
        await settle()
        click(x: 90, y: 183)
        click(x: 90, y: 183, count: 2)
        await settle()
        check("double-clicking a reminder opens its existing content", currentFieldText() == "编辑提醒测试")
        await step("reminder-editor")
        pressCommand("a")
        insert("修改后的提醒")
        submit()
        await settle()
        check("Return saves the reminder edit", model.data.reminders.first?.title == "修改后的提醒")
        await step("edited-items")

        model.saveNow()
        let saved = try? DataStore(directory: URL(fileURLWithPath: folder)).load().data
        check("both UI edits survive reloading data.json",
              saved?.todos.contains { $0.title == "修改后的待办" } == true
                  && saved?.reminders.first?.title == "修改后的提醒")
        panel.collapse()
    }

    /// Every built-in skin on the panel, an edit to one, and the 外观与皮肤 window, without taking the keyboard.
    private func runSkins() async {
        // It saves and switches skins, which must never touch the user's real settings.
        guard let dataDirectory = ProcessInfo.processInfo.environment["YIYU_DATA_DIR"].map({ URL(fileURLWithPath: $0) }) else {
            check("the skin tour runs on a throwaway data folder (YIYU_DATA_DIR)", false)
            return
        }
        let appearance = appearanceWindow.model
        ui.tab = .today
        for skin in Skin.builtIns.dropFirst() {
            appearance.select(skin.id)
            await settle()
            check("\(skin.name) gives the panel a \(skin.palette.isDark ? "dark" : "light") appearance",
                  isDark(window) == skin.palette.isDark)
            await step("skin-\(skin.id)")
        }
        ui.tab = .diary
        await step("skin-diary")
        ui.tab = .today
        panel.collapse()
        await settle()
        await step("skin-badge")
        panel.expand(focus: false)
        await settle()

        appearance.select(Skin.default.id)
        appearance.setColor(ThemeColor(rgb: 0x7FB8A4), for: .accent)
        let copy = appearance.selectedSkin
        check("editing a built-in skin selects an edited copy",
              !appearance.isSelectedBuiltIn && copy.name == "我的磁青泥金" && copy.palette.accent.rgb == 0x7FB8A4)
        check("the built-in skin itself is unchanged", Skin.default.palette.accent.hex == "#C8A96A")
        appearance.saveNow()
        let saved = try? AppearanceStore(directory: dataDirectory).load().settings
        check("the edited copy is saved to appearance.json", saved == appearance.settings)

        appearanceWindow.show(activate: false)
        await settle()
        if let settingsWindow = appearanceWindow.debugWindow {
            await step("appearance-window", window: settingsWindow)
            appearance.select("xuanzhi")
            await settle()
            await step("appearance-window-light", window: settingsWindow)
            check("opening the appearance window left the keyboard alone",
                  !settingsWindow.isKeyWindow && !window.isKeyWindow)
            await pickColorsTwice(in: settingsWindow)
        } else {
            check("the appearance window opens", false)
        }
        appearanceWindow.close()

        for skin in appearance.customSkins {
            appearance.delete(skin.id)
        }
        appearance.select(Skin.default.id)
        await settle()
        check("back on the default skin the panel is dark again", isDark(window) && appearance.customSkins.isEmpty)
    }

    /// Two picks in the accent colour well of a built-in skin: the first makes the copy,
    /// the second must still reach it through the same well.
    private func pickColorsTwice(in settingsWindow: NSWindow) async {
        let appearance = appearanceWindow.model
        let builtIn = appearance.selectedSkin
        guard let well = colorWells(in: settingsWindow.contentView).first(where: { well in
            well.color.usingColorSpace(.sRGB).map { ThemeColor(red: $0.redComponent, green: $0.greenComponent, blue: $0.blueComponent) }
                == builtIn.palette.accent
        }) else {
            check("the accent colour well is on screen", false)
            return
        }
        for rgb: UInt32 in [0x1F6E8C, 0x8C1F5A] {
            let color = ThemeColor(rgb: rgb)
            well.color = NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
            _ = well.sendAction(well.action, to: well.target)
            await settle()
        }
        let copy = appearance.selectedSkin
        check("a colour well keeps working after its first pick copies a built-in skin",
              !appearance.isSelectedBuiltIn && copy.palette.accent.rgb == 0x8C1F5A
                  && appearance.customSkins.count == 2 && well.window === settingsWindow)
    }

    private func colorWells(in view: NSView?) -> [NSColorWell] {
        guard let view else { return [] }
        return ((view as? NSColorWell).map { [$0] } ?? []) + view.subviews.flatMap(colorWells)
    }

    private func isDark(_ window: NSWindow) -> Bool {
        window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    // MARK: - Helpers

    /// Logs `STEP <name>` (plus the window number when the shot is of a window other than the panel)
    /// and pauses until `ui-tour.sh` has captured it (it sets `YIYU_TOUR_SHOTS` to its screenshot
    /// folder), so slow captures never show a later state.
    private func step(_ name: String, window shot: NSWindow? = nil) async {
        Self.stepsTaken += 1
        log("STEP \(name)" + (shot.map { " \($0.windowNumber)" } ?? ""))
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
    private func click(x: CGFloat, y: CGFloat, count: Int = 1) {
        let location = NSPoint(x: x, y: window.frame.height - y)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(
                with: type, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: count, pressure: type == .leftMouseDown ? 1 : 0
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
