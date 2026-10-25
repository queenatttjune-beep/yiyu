import AppKit
import Foundation
import Observation
import YiyuCore

/// Owns the app's data and every edit to it. Views call these intents; nothing else writes `data`.
@MainActor
@Observable
final class AppModel {
    private static let saveDelay: Duration = .milliseconds(600)

    private(set) var data: AppData
    private(set) var now: Date
    private(set) var saveError: String?
    /// Reminders that went off while the app was running, until the user acknowledges them.
    private(set) var firedReminders: [Reminder] = []

    let calendar: Calendar
    let labels: Labels
    let parser: QuickTimeParser
    let todoParser: TodoInputParser

    @ObservationIgnored private let store: DataStore?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var lastReminderCheck: Date
    @ObservationIgnored var onRemindersChanged: (([Reminder]) -> Void)?
    @ObservationIgnored var onRemindersFired: (([Reminder]) -> Void)?

    init(data: AppData, store: DataStore?, calendar: Calendar = .autoupdatingCurrent, now: Date = Date()) {
        self.data = data
        self.store = store
        self.calendar = calendar
        self.labels = Labels(calendar: calendar)
        self.parser = QuickTimeParser(calendar: calendar)
        self.todoParser = TodoInputParser(calendar: calendar)
        self.now = now
        self.lastReminderCheck = now
    }

    var today: DayKey { DayKey(now, calendar: calendar) }

    // MARK: - To-dos

    var todayTodos: [Todo] { TodoBook.todayList(data.todos, today: today, calendar: calendar) }
    var remainingToday: Int { TodoBook.remainingToday(data.todos, today: today) }
    var openTodos: [Todo] { TodoBook.openList(data.todos) }
    var completedTodos: [Todo] { TodoBook.completedList(data.todos) }

    var todaySummary: String {
        Labels.todaySummary(remaining: remainingToday, total: todayTodos.count)
    }

    @discardableResult
    func addTodo(_ input: String, forToday: Bool, now: Date = Date()) -> Todo? {
        let parsed = todoParser.parse(input, now: now)
        guard parsed.unresolvedDate == nil, !parsed.title.isEmpty else { return nil }
        let day = parsed.plannedDay ?? (forToday ? DayKey(now, calendar: calendar) : nil)
        let id = UUID()
        update { $0.with(todos: TodoBook.adding(parsed.title, plannedDay: day, to: $0.todos, now: now, id: id)) }
        return data.todos.first { $0.id == id }
    }

    func toggleTodo(_ id: UUID) {
        update { $0.with(todos: TodoBook.toggling(id, in: $0.todos, now: Date())) }
    }

    func planTodo(_ id: UUID, daysFromToday: Int?) {
        let day = daysFromToday.map { today.adding(days: $0, calendar: calendar) }
        update { $0.with(todos: TodoBook.planning(id, for: day, in: $0.todos)) }
    }

    func updateTodo(_ id: UUID, title: String, plannedDay: DayKey?) {
        update { $0.with(todos: TodoBook.editing(id, title: title, plannedDay: plannedDay, in: $0.todos)) }
    }

    func deleteTodo(_ id: UUID) {
        update { $0.with(todos: TodoBook.removing(id, from: $0.todos)) }
    }

    func clearCompletedTodos() {
        update { $0.with(todos: TodoBook.clearingCompleted(from: $0.todos)) }
    }

    // MARK: - Reminders

    var upcomingReminders: [Reminder] { ReminderBook.upcoming(data.reminders, now: now) }
    var dueReminders: [Reminder] { ReminderBook.due(data.reminders, now: now) }
    var doneReminderCount: Int { data.reminders.filter(\.isDone).count }

    var todaysReminders: [Reminder] {
        dueReminders + upcomingReminders.filter { DayKey($0.fireAt, calendar: calendar) == today }
    }

    var nextReminder: Reminder? { dueReminders.first ?? upcomingReminders.first }

    func addReminder(_ title: String, at fireAt: Date, repeatRule: RepeatRule) {
        update {
            $0.with(reminders: ReminderBook.adding(title, fireAt: fireAt, repeatRule: repeatRule, to: $0.reminders, now: Date()))
        }
    }

    func toggleReminder(_ id: UUID) {
        forgetFired(id)
        update { $0.with(reminders: ReminderBook.completing(id, in: $0.reminders, now: Date(), calendar: calendar)) }
    }

    func updateReminder(_ id: UUID, title: String, at fireAt: Date, repeatRule: RepeatRule) {
        let reminders = ReminderBook.editing(
            id, title: title, fireAt: fireAt, repeatRule: repeatRule,
            in: data.reminders, now: Date(), calendar: calendar
        )
        guard let previous = data.reminders.first(where: { $0.id == id }),
              let edited = reminders.first(where: { $0.id == id }), previous != edited
        else { return }
        if previous.fireAt != edited.fireAt || previous.repeatRule != edited.repeatRule {
            forgetFired(id)
        } else {
            firedReminders = firedReminders.map { reminder in
                guard reminder.id == id else { return reminder }
                var copy = reminder
                copy.title = edited.title
                return copy
            }
        }
        update { $0.with(reminders: reminders) }
    }

    func snoozeReminder(_ id: UUID, by interval: TimeInterval) {
        forgetFired(id)
        let target = Date().addingTimeInterval(interval)
        update { $0.with(reminders: ReminderBook.snoozing(id, until: target, in: $0.reminders, now: Date())) }
    }

    func deleteReminder(_ id: UUID) {
        forgetFired(id)
        update { $0.with(reminders: ReminderBook.removing(id, from: $0.reminders)) }
    }

    func clearDoneReminders() {
        update { $0.with(reminders: ReminderBook.clearingDone(from: $0.reminders)) }
    }

    /// Clears the "it's time" banner. A one-off reminder that is still due counts as done.
    func acknowledgeFired() {
        let firedIDs = Set(firedReminders.map(\.id))
        let currentTime = Date()
        firedReminders = []
        update { data in
            data.with(reminders: data.reminders.map { reminder in
                guard firedIDs.contains(reminder.id), reminder.repeatRule == .none,
                      !reminder.isDone, reminder.fireAt <= currentTime
                else { return reminder }
                var copy = reminder
                copy.isDone = true
                return copy
            })
        }
    }

    private func forgetFired(_ id: UUID) {
        firedReminders = firedReminders.filter { $0.id != id }
    }

    // MARK: - Memos

    func memos(matching query: String) -> [Memo] {
        MemoBook.searching(MemoBook.sorted(data.memos), query: query)
    }

    func memo(_ id: UUID) -> Memo? {
        data.memos.first { $0.id == id }
    }

    func createMemo() -> UUID {
        let id = UUID()
        update { $0.with(memos: MemoBook.creating(id: id, in: $0.memos, now: Date())) }
        return id
    }

    func updateMemo(_ id: UUID, text: String) {
        update { $0.with(memos: MemoBook.updating(id, text: text, in: $0.memos, now: Date())) }
    }

    func toggleMemoPin(_ id: UUID) {
        update { $0.with(memos: MemoBook.togglingPin(id, in: $0.memos)) }
    }

    func deleteMemo(_ id: UUID) {
        update { $0.with(memos: MemoBook.removing(id, from: $0.memos)) }
    }

    func pruneEmptyMemos(keeping id: UUID?) {
        update { $0.with(memos: MemoBook.pruningEmpty($0.memos, keeping: id)) }
    }

    // MARK: - Diary

    func diaryText(for day: DayKey) -> String {
        DiaryBook.text(for: day, in: data.diary)
    }

    func writeDiary(_ text: String, for day: DayKey) {
        update { $0.with(diary: DiaryBook.writing(text, for: day, in: $0.diary, now: Date())) }
    }

    var diaryDays: Set<DayKey> { DiaryBook.writtenDays(in: data.diary) }

    // MARK: - Writing styles

    var writingStyles: [WritingStyle] { WritingStyle.all(custom: data.customStyles) }

    func addStyle(name: String, instruction: String) {
        update { $0.with(customStyles: StyleBook.adding(name: name, instruction: instruction, to: $0.customStyles)) }
    }

    func removeStyle(_ id: String) {
        update { $0.with(customStyles: StyleBook.removing(id, from: $0.customStyles)) }
    }

    // MARK: - Clock

    /// Called every few seconds: advances "now", reports reminders that just went off
    /// and moves repeating ones to their next time.
    func tick(at date: Date = Date()) {
        now = date
        let fired = ReminderBook.firing(data.reminders, after: lastReminderCheck, through: date)
        lastReminderCheck = date
        if !fired.isEmpty {
            let known = Set(firedReminders.map(\.id))
            firedReminders += fired.filter { !known.contains($0.id) }
            onRemindersFired?(fired)
        }
        update { $0.with(reminders: ReminderBook.rollingForward($0.reminders, now: date, calendar: calendar)) }
    }

    // MARK: - Persistence

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard let store else { return }
        do {
            try store.backupIfNeeded(day: today)
        } catch {
            // A missing backup must never stop the save itself.
            NSLog("Yiyu: daily backup in %@ failed: %@", store.backupDirectory.path, String(describing: error))
        }
        do {
            try store.save(data)
            saveError = nil
        } catch {
            NSLog("Yiyu: saving %@ failed: %@", store.fileURL.path, String(describing: error))
            saveError = "没能保存到磁盘：\(error.localizedDescription)"
        }
    }

    func reportLoadProblem(_ message: String) {
        saveError = message
    }

    private func update(_ transform: (AppData) -> AppData) {
        let next = transform(data)
        guard next != data else { return }
        let remindersChanged = next.reminders != data.reminders
        data = next
        scheduleSave()
        if remindersChanged {
            onRemindersChanged?(next.reminders)
        }
    }

    private func scheduleSave() {
        guard store != nil else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.saveDelay)
            } catch {
                return  // Superseded by a newer edit.
            }
            self?.saveNow()
        }
    }
}

extension AppData {
    func with(
        todos: [Todo]? = nil,
        reminders: [Reminder]? = nil,
        memos: [Memo]? = nil,
        diary: [DiaryEntry]? = nil,
        customStyles: [WritingStyle]? = nil
    ) -> AppData {
        AppData(
            version: version,
            todos: todos ?? self.todos,
            reminders: reminders ?? self.reminders,
            memos: memos ?? self.memos,
            diary: diary ?? self.diary,
            customStyles: customStyles ?? self.customStyles
        )
    }
}
