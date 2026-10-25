import Foundation
import Testing
import YiyuCore
@testable import Yiyu

@MainActor
struct AppModelEditingTests {
    @Test func reminderEditsNotifyTheSchedulerAndSaveToDisk() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = DataStore(directory: folder)
        let now = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let original = Reminder(title: "旧内容", fireAt: now.addingTimeInterval(3600), repeatRule: .none,
                                isDone: false, createdAt: now)
        let model = AppModel(data: AppData(reminders: [original]), store: store, now: now)
        var scheduled: [[Reminder]] = []
        model.onRemindersChanged = { scheduled.append($0) }
        let later = now.addingTimeInterval(7200)

        model.updateReminder(original.id, title: " 新内容 ", at: later, repeatRule: .daily)
        #expect(scheduled == [model.data.reminders])
        #expect(scheduled[0][0].title == "新内容")
        #expect(scheduled[0][0].fireAt == later)
        #expect(scheduled[0][0].repeatRule == .daily)
        model.saveNow()
        #expect(model.saveError == nil)
        #expect(try store.load().data == model.data)
    }

    @Test func titleEditsRefreshFiredBannerAndScheduleEditsClearIt() {
        let now = Date()
        let original = Reminder(title: "旧内容", fireAt: now.addingTimeInterval(1), repeatRule: .none,
                                isDone: false, createdAt: now)
        let model = AppModel(data: AppData(reminders: [original]), store: nil, now: now)
        model.tick(at: now.addingTimeInterval(2))
        #expect(model.firedReminders.map(\.id) == [original.id])

        model.updateReminder(original.id, title: "新内容", at: original.fireAt, repeatRule: .none)
        #expect(model.firedReminders.map(\.title) == ["新内容"])
        model.updateReminder(original.id, title: "新内容", at: now.addingTimeInterval(3600), repeatRule: .none)
        #expect(model.firedReminders.isEmpty)
        #expect(model.dueReminders.isEmpty)
    }

    @Test func invalidAndUnchangedEditsDoNotNotifyOrDismissTheBanner() {
        let now = Date()
        let original = Reminder(title: "保留", fireAt: now.addingTimeInterval(1), repeatRule: .none,
                                isDone: false, createdAt: now)
        let model = AppModel(data: AppData(reminders: [original]), store: nil, now: now)
        model.tick(at: now.addingTimeInterval(2))
        var updates = 0
        model.onRemindersChanged = { _ in updates += 1 }

        model.updateReminder(original.id, title: " \n ", at: now.addingTimeInterval(3600), repeatRule: .daily)
        model.updateReminder(original.id, title: original.title, at: original.fireAt, repeatRule: original.repeatRule)
        model.updateReminder(UUID(), title: "不存在", at: now, repeatRule: .weekly)
        #expect(model.data.reminders == [original])
        #expect(model.firedReminders == [original])
        #expect(updates == 0)
    }

    @Test func todoEditsUpdateTodayListAndPersistTogether() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = DataStore(directory: folder)
        let now = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let todo = Todo(title: "旧待办", createdAt: now)
        let model = AppModel(data: AppData(todos: [todo]), store: store, now: now)

        model.updateTodo(todo.id, title: " 今天做 ", plannedDay: model.today)
        #expect(model.todayTodos.map(\.title) == ["今天做"])
        model.saveNow()
        #expect(try store.load().data == model.data)
        model.updateTodo(todo.id, title: "以后再做", plannedDay: nil)
        #expect(model.todayTodos.isEmpty)
        #expect(model.openTodos.map(\.title) == ["以后再做"])
    }
}
