import Foundation
import Testing
@testable import YiyuCore

struct ReminderBookTests {
    let calendar = Fixtures.calendar
    let now = Fixtures.now

    private func reminder(
        _ title: String,
        at fireAt: Date,
        rule: RepeatRule = .none,
        isDone: Bool = false
    ) -> Reminder {
        Reminder(title: title, fireAt: fireAt, repeatRule: rule, isDone: isDone, createdAt: Fixtures.date(2026, 10, 1))
    }

    @Test func dailyRuleFindsNextTimeAfterReference() {
        let anchor = Fixtures.date(2026, 10, 24, 8)
        #expect(ReminderBook.nextFire(after: now, from: anchor, rule: .daily, calendar: calendar)
                == Fixtures.date(2026, 10, 26, 8))
        let earlyMorning = Fixtures.date(2026, 10, 25, 7)
        #expect(ReminderBook.nextFire(after: earlyMorning, from: anchor, rule: .daily, calendar: calendar)
                == Fixtures.date(2026, 10, 25, 8))
    }

    @Test func weekdayRuleSkipsTheWeekend() {
        let fridayMorning = Fixtures.date(2026, 10, 23, 9)
        let fridayLater = Fixtures.date(2026, 10, 23, 10)
        #expect(ReminderBook.nextFire(after: fridayLater, from: fridayMorning, rule: .weekdays, calendar: calendar)
                == Fixtures.date(2026, 10, 26, 9))
    }

    @Test func weeklyRuleKeepsTheAnchorWeekday() {
        let mondayEvening = Fixtures.date(2026, 10, 19, 19)
        #expect(ReminderBook.nextFire(after: now, from: mondayEvening, rule: .weekly, calendar: calendar)
                == Fixtures.date(2026, 10, 26, 19))
    }

    @Test func oneShotHasNoNextFire() {
        #expect(ReminderBook.nextFire(after: now, from: Fixtures.date(2026, 10, 24), rule: .none, calendar: calendar) == nil)
    }

    @Test func futureMatchingAnchorIsItsOwnNextFire() {
        let tomorrow = Fixtures.date(2026, 10, 26, 8)
        #expect(ReminderBook.nextFire(after: now, from: tomorrow, rule: .daily, calendar: calendar) == tomorrow)
    }

    @Test func rollingForwardAdvancesOnlyPastRepeatingReminders() {
        let repeating = reminder("吃药", at: Fixtures.date(2026, 10, 25, 8), rule: .daily)
        let oneShot = reminder("开会", at: Fixtures.date(2026, 10, 25, 9))
        let finished = reminder("旧的", at: Fixtures.date(2026, 10, 25, 8), rule: .daily, isDone: true)
        let future = reminder("晚饭", at: Fixtures.date(2026, 10, 25, 18), rule: .daily)

        let rolled = ReminderBook.rollingForward([repeating, oneShot, finished, future], now: now, calendar: calendar)

        #expect(rolled[0].fireAt == Fixtures.date(2026, 10, 26, 8))
        #expect(rolled[1] == oneShot)
        #expect(rolled[2] == finished)
        #expect(rolled[3] == future)
    }

    @Test func firingWindowExcludesStartIncludesEndAndSkipsDone() {
        let start = Fixtures.date(2026, 10, 25, 9)
        let atStart = reminder("start", at: start)
        let inside = reminder("inside", at: Fixtures.date(2026, 10, 25, 9, 30))
        let atEnd = reminder("end", at: now)
        let done = reminder("done", at: Fixtures.date(2026, 10, 25, 9, 40), isDone: true)

        let fired = ReminderBook.firing([atStart, inside, atEnd, done], after: start, through: now)
        #expect(fired.map(\.title) == ["inside", "end"])
    }

    @Test func splitsDueAndUpcoming() {
        let past = reminder("past", at: Fixtures.date(2026, 10, 25, 9))
        let soon = reminder("soon", at: Fixtures.date(2026, 10, 25, 11))
        let later = reminder("later", at: Fixtures.date(2026, 10, 27, 9))
        let done = reminder("done", at: Fixtures.date(2026, 10, 25, 8), isDone: true)
        let all = [later, done, soon, past]

        #expect(ReminderBook.due(all, now: now).map(\.title) == ["past"])
        #expect(ReminderBook.upcoming(all, now: now).map(\.title) == ["soon", "later"])
    }

    @Test func reschedulingMovesTimeAndReopens() {
        let original = [reminder("开会", at: Fixtures.date(2026, 10, 25, 9), isDone: true)]
        let later = Fixtures.date(2026, 10, 25, 10, 10)
        let moved = ReminderBook.rescheduling(original[0].id, to: later, in: original)
        #expect(moved[0].fireAt == later)
        #expect(moved[0].isDone == false)
        #expect(original[0].fireAt == Fixtures.date(2026, 10, 25, 9))
    }

    @Test func editingContentPreservesIdentityScheduleAndCompletion() {
        let original = reminder("旧内容", at: Fixtures.date(2026, 10, 25, 9), isDone: true)
        let other = reminder("另一条", at: Fixtures.date(2026, 10, 26, 8))
        let edited = ReminderBook.editing(
            original.id, title: " 新内容 \n", fireAt: original.fireAt, repeatRule: .none,
            in: [original, other], now: now, calendar: calendar
        )
        #expect(edited[0].title == "新内容")
        #expect(edited[0].id == original.id)
        #expect(edited[0].createdAt == original.createdAt)
        #expect(edited[0].fireAt == original.fireAt)
        #expect(edited[0].isDone)
        #expect(edited[1] == other)
        #expect(original.title == "旧内容")
    }

    @Test func editingScheduleReopensAndReplacesTheSeriesWithoutAddingCopies() {
        let original = reminder("吃药", at: Fixtures.date(2026, 10, 26, 8), rule: .daily, isDone: true)
        let date = Fixtures.date(2026, 10, 27, 9, 30)
        let edited = ReminderBook.editing(
            original.id, title: "早餐后吃药", fireAt: date, repeatRule: .weekdays,
            in: [original], now: now, calendar: calendar
        )
        #expect(edited.count == 1)
        #expect(edited[0].id == original.id)
        #expect(edited[0].fireAt == date)
        #expect(edited[0].repeatRule == .weekdays)
        #expect(!edited[0].isDone)
        let scheduled = ReminderBook.occurrences(of: edited, after: now, days: 7, limit: 60, calendar: calendar)
        #expect(scheduled.first?.date == date)
        #expect(scheduled.allSatisfy { $0.reminder.title == "早餐后吃药" })
        #expect(scheduled.allSatisfy { calendar.component(.hour, from: $0.date) == 9 })
    }

    @Test func changingOnlyRepeatRuleReopensAndSkipsNonMatchingDays() {
        let original = reminder("站会", at: Fixtures.date(2026, 10, 25, 15), isDone: true)
        let edited = ReminderBook.editing(
            original.id, title: original.title, fireAt: original.fireAt, repeatRule: .weekdays,
            in: [original], now: now, calendar: calendar
        )[0]
        #expect(edited.fireAt == Fixtures.date(2026, 10, 26, 15))
        #expect(edited.repeatRule == .weekdays)
        #expect(!edited.isDone)
    }

    @Test func removingRepeatKeepsChosenTimeEvenWhenItIsPast() {
        let original = reminder("取药", at: Fixtures.date(2026, 10, 24, 8), rule: .daily)
        let edited = ReminderBook.editing(
            original.id, title: original.title, fireAt: original.fireAt, repeatRule: .none,
            in: [original], now: now, calendar: calendar
        )[0]
        #expect(edited.repeatRule == .none)
        #expect(edited.fireAt == original.fireAt)
        #expect(ReminderBook.due([edited], now: now) == [edited])
    }

    @Test func invalidEditsKeepTheEntireReminderUnchanged() {
        let original = [reminder("保留", at: Fixtures.date(2026, 10, 25, 9), isDone: true)]
        for id in [original[0].id, UUID()] {
            #expect(ReminderBook.editing(
                id, title: id == original[0].id ? " \n " : "不存在", fireAt: now, repeatRule: .weekly,
                in: original, now: now, calendar: calendar
            ) == original)
        }
    }

    @Test func snoozingOneOffMovesItButSnoozingSeriesAddsAOneOffCopy() {
        let oneOff = reminder("开会", at: Fixtures.date(2026, 10, 25, 9))
        let series = reminder("吃药", at: Fixtures.date(2026, 10, 25, 8), rule: .daily)
        let later = Fixtures.date(2026, 10, 25, 10, 10)

        let snoozedOneOff = ReminderBook.snoozing(oneOff.id, until: later, in: [oneOff, series], now: now)
        #expect(snoozedOneOff.count == 2)
        #expect(snoozedOneOff[0].fireAt == later)

        let snoozedSeries = ReminderBook.snoozing(series.id, until: later, in: [oneOff, series], now: now)
        #expect(snoozedSeries.count == 3)
        #expect(snoozedSeries[1] == series)
        #expect(snoozedSeries[2].title == "吃药")
        #expect(snoozedSeries[2].fireAt == later)
        #expect(snoozedSeries[2].repeatRule == .none)
    }

    @Test func completingOneOffTogglesButCompletingSeriesSkipsToNextTime() {
        let oneOff = reminder("开会", at: Fixtures.date(2026, 10, 25, 9))
        #expect(ReminderBook.completing(oneOff.id, in: [oneOff], now: now, calendar: calendar)[0].isDone)

        let upcomingDaily = reminder("吃药", at: Fixtures.date(2026, 10, 26, 8), rule: .daily)
        let skipped = ReminderBook.completing(upcomingDaily.id, in: [upcomingDaily], now: now, calendar: calendar)
        #expect(skipped[0].isDone == false)
        #expect(skipped[0].fireAt == Fixtures.date(2026, 10, 27, 8))
    }

    @Test func occurrencesListRepeatsAheadSoNotificationsSurviveTheAppBeingClosed() {
        let daily = reminder("吃药", at: Fixtures.date(2026, 10, 26, 8), rule: .daily)
        let workdays = reminder("站会", at: Fixtures.date(2026, 10, 26, 9, 30), rule: .weekdays)
        let oneOff = reminder("开会", at: Fixtures.date(2026, 10, 25, 15))
        let past = reminder("过期", at: Fixtures.date(2026, 10, 25, 9))
        let done = reminder("完成", at: Fixtures.date(2026, 10, 25, 16), isDone: true)

        let upcoming = ReminderBook.occurrences(
            of: [daily, workdays, oneOff, past, done], after: now, days: 7, limit: 60, calendar: calendar
        )

        #expect(upcoming.filter { $0.reminder.id == daily.id }.count == 7)
        #expect(upcoming.filter { $0.reminder.id == workdays.id }.count == 5)
        #expect(upcoming.filter { $0.reminder.id == oneOff.id }.map(\.date) == [Fixtures.date(2026, 10, 25, 15)])
        let scheduledIDs = Set(upcoming.map(\.reminder.id))
        #expect(!scheduledIDs.contains(past.id))
        #expect(!scheduledIDs.contains(done.id))
        let dates = upcoming.map(\.date)
        #expect(dates == dates.sorted())
        #expect(ReminderBook.occurrences(of: [daily], after: now, days: 7, limit: 3, calendar: calendar).count == 3)
    }

    @Test func addingToggleRemoveAndClear() {
        let added = ReminderBook.adding(" 取快递 ", fireAt: now, repeatRule: .none, to: [], now: now)
        #expect(added.map(\.title) == ["取快递"])
        #expect(ReminderBook.adding("  ", fireAt: now, repeatRule: .none, to: added, now: now) == added)

        let toggled = ReminderBook.togglingDone(added[0].id, in: added)
        #expect(toggled[0].isDone)
        #expect(ReminderBook.clearingDone(from: toggled).isEmpty)
        #expect(ReminderBook.removing(added[0].id, from: added).isEmpty)
    }
}
