import Foundation
import Testing
@testable import YiyuCore

struct TodoBookTests {
    let calendar = Fixtures.calendar
    let now = Fixtures.now
    let today = Fixtures.today

    private func todo(
        _ title: String,
        planned: DayKey? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Fixtures.now
    ) -> Todo {
        Todo(title: title, plannedDay: planned, completedAt: completedAt, createdAt: createdAt)
    }

    @Test func addingTrimsTitleAndKeepsPlannedDay() {
        let result = TodoBook.adding("  交读书报告 \n", plannedDay: today, to: [], now: now)
        #expect(result.count == 1)
        #expect(result[0].title == "交读书报告")
        #expect(result[0].plannedDay == today)
        #expect(result[0].isDone == false)
    }

    @Test func addingIgnoresBlankTitles() {
        let existing = [todo("买菜")]
        #expect(TodoBook.adding("   ", plannedDay: nil, to: existing, now: now) == existing)
    }

    @Test func togglingMarksDoneAndBack() {
        let original = [todo("买菜")]
        let done = TodoBook.toggling(original[0].id, in: original, now: now)
        #expect(done[0].completedAt == now)
        #expect(original[0].completedAt == nil)
        let undone = TodoBook.toggling(original[0].id, in: done, now: now)
        #expect(undone[0].completedAt == nil)
    }

    @Test func todayListHoldsPlannedOverdueAndFinishedToday() {
        let plannedToday = todo("今天的事", planned: today, createdAt: Fixtures.date(2026, 10, 25, 8))
        let overdue = todo("昨天没做完", planned: today.adding(days: -1, calendar: calendar),
                           createdAt: Fixtures.date(2026, 10, 24, 9))
        let tomorrow = todo("明天的事", planned: today.adding(days: 1, calendar: calendar))
        let inbox = todo("没排期")
        let doneToday = todo("已完成", planned: today, completedAt: Fixtures.date(2026, 10, 25, 9))
        let doneYesterday = todo("昨天完成", planned: today.adding(days: -1, calendar: calendar),
                                 completedAt: Fixtures.date(2026, 10, 24, 20))

        let list = TodoBook.todayList(
            [plannedToday, overdue, tomorrow, inbox, doneToday, doneYesterday],
            today: today, calendar: calendar
        )

        #expect(list.map(\.title) == ["今天的事", "昨天没做完", "已完成"])
    }

    @Test func remainingTodayCountsOnlyOpenItems() {
        let items = [
            todo("a", planned: today),
            todo("b", planned: today.adding(days: -2, calendar: calendar)),
            todo("c", planned: today, completedAt: now),
            todo("d"),
        ]
        #expect(TodoBook.remainingToday(items, today: today) == 2)
    }

    @Test func planningMovesItemBetweenDays() {
        let original = [todo("写周报")]
        let planned = TodoBook.planning(original[0].id, for: today, in: original)
        #expect(planned[0].plannedDay == today)
        let unplanned = TodoBook.planning(original[0].id, for: nil, in: planned)
        #expect(unplanned[0].plannedDay == nil)
    }

    @Test func renamingKeepsOldTitleWhenBlank() {
        let original = [todo("旧标题")]
        #expect(TodoBook.renaming(original[0].id, to: " 新标题 ", in: original)[0].title == "新标题")
        #expect(TodoBook.renaming(original[0].id, to: "  ", in: original)[0].title == "旧标题")
    }

    @Test func removingAndClearingCompleted() {
        let open = todo("open")
        let done = todo("done", completedAt: now)
        #expect(TodoBook.removing(open.id, from: [open, done]) == [done])
        #expect(TodoBook.clearingCompleted(from: [open, done]) == [open])
    }

    @Test func editingUpdatesTitleAndDateWithoutChangingIdentityOrCompletion() {
        let original = todo("旧标题", planned: today, completedAt: now)
        let other = todo("另一件事")
        let tomorrow = today.adding(days: 1, calendar: calendar)
        let edited = TodoBook.editing(original.id, title: " 新标题 \n", plannedDay: tomorrow, in: [original, other])
        #expect(edited[0].title == "新标题")
        #expect(edited[0].plannedDay == tomorrow)
        #expect(edited[0].id == original.id)
        #expect(edited[0].createdAt == original.createdAt)
        #expect(edited[0].completedAt == original.completedAt)
        #expect(edited[1] == other)
        #expect(original.title == "旧标题")
        #expect(TodoBook.editing(original.id, title: "新标题", plannedDay: nil, in: edited)[0].plannedDay == nil)
    }

    @Test func invalidEditsDoNotChangeTitleOrDate() {
        let original = [todo("保留", planned: today)]
        #expect(TodoBook.editing(original[0].id, title: " \n ", plannedDay: nil, in: original) == original)
        #expect(TodoBook.editing(UUID(), title: "不存在", plannedDay: nil, in: original) == original)
    }

    @Test func openListIsNewestFirstAndCompletedListIsRecentFirst() {
        let older = todo("older", createdAt: Fixtures.date(2026, 10, 20))
        let newer = todo("newer", createdAt: Fixtures.date(2026, 10, 24))
        let doneEarly = todo("doneEarly", completedAt: Fixtures.date(2026, 10, 21))
        let doneLate = todo("doneLate", completedAt: Fixtures.date(2026, 10, 23))
        let all = [older, newer, doneEarly, doneLate]

        #expect(TodoBook.openList(all).map(\.title) == ["newer", "older"])
        #expect(TodoBook.completedList(all).map(\.title) == ["doneLate", "doneEarly"])
    }
}
