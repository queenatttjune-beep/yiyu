import Foundation
import Testing
import YiyuCore
@testable import Yiyu

@MainActor
struct TodoInputTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test(arguments: [true, false])
    func explicitTomorrowOverridesBothInputPages(forToday: Bool) {
        let model = AppModel(data: .empty, store: nil, calendar: calendar, now: now)
        let todo = model.addTodo("把明天的周报写了", forToday: forToday, now: now)
        #expect(todo?.title == "写周报")
        #expect(todo?.plannedDay == model.today.adding(days: 1, calendar: calendar))
        #expect(model.todayTodos.isEmpty)
        #expect(model.openTodos.count == 1)
        #expect(model.data.reminders.isEmpty)
        model.tick(at: calendar.date(byAdding: .day, value: 1, to: now)!)
        #expect(model.todayTodos.map(\.title) == ["写周报"])
    }

    @Test func plainInputKeepsEachPagesDefaultAndDateOnlyInputAddsNothing() {
        let model = AppModel(data: .empty, store: nil, calendar: calendar, now: now)
        #expect(model.addTodo("买菜", forToday: true, now: now)?.plannedDay == model.today)
        #expect(model.addTodo("买牛奶", forToday: false, now: now)?.plannedDay == nil)
        #expect(model.addTodo("明天", forToday: true, now: now) == nil)
        #expect(model.addTodo("11月31号交报告", forToday: true, now: now) == nil)
        #expect(model.data.todos.count == 2)
    }

    @Test func recognizedTitleAndDaySurviveReloading() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = DataStore(directory: folder)
        let model = AppModel(data: .empty, store: store, calendar: calendar, now: now)
        let added = model.addTodo("把明天的周报写了", forToday: true, now: now)
        model.saveNow()
        let loaded = try store.load().data
        #expect(loaded.todos == [added].compactMap { $0 })
        #expect(loaded.reminders.isEmpty)
    }
}
