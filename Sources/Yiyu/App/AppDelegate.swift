import AppKit
import Carbon.HIToolbox
import YiyuCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// How often reminders are checked and the date rolls over.
    private static let tickInterval: TimeInterval = 15
    private static let dataDirectoryOverride = "YIYU_DATA_DIR"

    private var model: AppModel?
    private var appearance: AppearanceModel?
    private var appearanceWindow: AppearanceWindowController?
    private var panel: PanelController?
    private var statusBar: StatusBarController?
    private var hotKey: HotKey?
    private var notifier: ReminderNotifier?
    private var ticker: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var terminationSignal: DispatchSourceSignal?
    private var folderLock: DataStore.FolderLock?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isAnotherCopyRunning() else {
            NSApp.terminate(nil)
            return
        }
        guard let store = openStore(), lockDataFolder(of: store), let loaded = load(from: store) else {
            NSApp.terminate(nil)
            return
        }

        let model = AppModel(data: initialData(for: loaded), store: store)
        if case .recovered(let backupURL) = loaded.outcome {
            model.reportLoadProblem("数据文件读不出来，已另存为 \(backupURL.lastPathComponent)，现在从空白开始。")
        }
        let appearance = loadAppearance(in: store.directory)
        Theme.appearance = appearance

        let ui = PanelState()
        let panel = PanelController(model: model, ui: ui, dataFolder: store.directory)
        panel.applyAppearance(isDark: appearance.selectedSkin.palette.isDark)
        appearance.onSkinChanged = { [weak panel] skin in panel?.applyAppearance(isDark: skin.palette.isDark) }
        let appearanceWindow = AppearanceWindowController(model: appearance)
        let notifier = ReminderNotifier(calendar: model.calendar)
        model.onRemindersChanged = { [weak notifier] reminders in notifier?.sync(reminders) }
        model.onRemindersFired = { [weak notifier] fired in notifier?.reminderFiredInApp(fired) }
        notifier.onOpenReminders = { [weak panel] in panel?.expand(focus: false, tab: .reminders) }

        let hotKey = HotKey(keyCode: kVK_ANSI_T, modifiers: controlKey | optionKey) { [weak panel] in
            panel?.toggleFromHotKey()
        }

        self.model = model
        self.appearance = appearance
        self.appearanceWindow = appearanceWindow
        self.panel = panel
        self.notifier = notifier
        self.hotKey = hotKey
        self.statusBar = StatusBarController(panel: panel, dataFolder: store.directory, isHotKeyAvailable: hotKey != nil)

        model.tick()
        model.pruneEmptyMemos(keeping: nil)
        notifier.start { [weak model] in model?.data.reminders ?? [] }
        startTicking(model)
        quitCleanlyOnSIGTERM()
        panel.show()
        if !isUsingCustomDataDirectory {
            LoginItem.enableOnFirstLaunch()
        }
        #if DEBUG
        DebugTour.runIfRequested(panel: panel, model: model, ui: ui, appearanceWindow: appearanceWindow)
        #endif
    }

    private func initialData(for loaded: DataStore.LoadResult) -> AppData {
        #if DEBUG
        if DebugTour.isRequested && loaded.outcome == .fresh {
            return DebugTour.sampleData(now: Date(), calendar: .current)
        }
        #endif
        return loaded.data
    }

    /// `YIYU_DATA_DIR` points a test copy at throwaway data; such a copy never registers itself at login.
    private var isUsingCustomDataDirectory: Bool {
        !(ProcessInfo.processInfo.environment[Self.dataDirectoryOverride] ?? "").isEmpty
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.saveNow()
        appearance?.saveNow()
    }

    /// Reached through the responder chain from the panel's ⋯ menu and the menu bar icon (`AppearanceCommand`).
    @objc func showAppearanceSettings(_ sender: Any?) {
        appearanceWindow?.show()
    }

    /// Skins are a preference: if they cannot be read, the panel still opens with the default skin.
    private func loadAppearance(in directory: URL) -> AppearanceModel {
        let store = AppearanceStore(directory: directory)
        do {
            let loaded = try store.load()
            let appearance = AppearanceModel(settings: loaded.settings, store: store)
            if case .recovered(let backupURL) = loaded.outcome {
                appearance.reportLoadProblem("皮肤设置读不出来，已另存为 \(backupURL.lastPathComponent)，现在用的是默认皮肤。")
            }
            return appearance
        } catch {
            NSLog("Yiyu: reading %@ failed: %@", store.fileURL.path, String(describing: error))
            let appearance = AppearanceModel(settings: .default, store: nil)
            appearance.reportLoadProblem("没能读取皮肤设置（\(error.localizedDescription)），这次的改动不会保存。")
            return appearance
        }
    }

    /// `kill`, `pkill` and logout send SIGTERM; go through normal termination so edits get saved.
    private func quitCleanlyOnSIGTERM() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
        source.resume()
        terminationSignal = source
    }

    private func startTicking(_ model: AppModel) {
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { _ in
            MainActor.assumeIsolated { model.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { model.tick() }
        }
    }

    private func isAnotherCopyRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let current = NSRunningApplication.current
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.processIdentifier != current.processIdentifier }
    }

    private func openStore() -> DataStore? {
        let store: DataStore
        if let override = ProcessInfo.processInfo.environment[Self.dataDirectoryOverride], !override.isEmpty {
            store = DataStore(directory: URL(fileURLWithPath: override, isDirectory: true))
        } else {
            do {
                store = DataStore(directory: try DataStore.defaultDirectory())
            } catch {
                showFatalError("找不到存放数据的文件夹", detail: error.localizedDescription)
                return nil
            }
        }
        do {
            try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        } catch {
            showFatalError("没能创建数据文件夹", detail: "\(store.directory.path)\n\(error.localizedDescription)")
            return nil
        }
        return store
    }

    /// Refuses to start rather than risk saving an empty list over data it could not read.
    private func load(from store: DataStore) -> DataStore.LoadResult? {
        do {
            return try store.load()
        } catch {
            showFatalError(
                "一隅没能读取数据，为了不覆盖原文件，先退出了",
                detail: "\(store.fileURL.path)\n\(error.localizedDescription)"
            )
            return nil
        }
    }

    /// Two copies saving to the same file would overwrite each other, so only one may use a folder.
    private func lockDataFolder(of store: DataStore) -> Bool {
        do {
            folderLock = try store.lockForExclusiveUse()
            return true
        } catch DataStore.LockError.alreadyInUse {
            showFatalError("一隅已经在运行", detail: "另一个一隅正在使用 \(store.directory.path)，这一个先退出了。")
        } catch {
            showFatalError("没能锁定数据文件夹", detail: "\(store.directory.path)\n\(error)")
        }
        return false
    }

    private func showFatalError(_ message: String, detail: String) {
        NSLog("Yiyu: %@ — %@", message, detail)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }
}
