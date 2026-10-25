import Foundation
import Testing
@testable import YiyuCore

struct LabelsTests {
    let labels = Labels(calendar: Fixtures.calendar)
    let today = Fixtures.today

    @Test func headerDateUsesChineseWeekday() {
        #expect(labels.headerDate(today) == "10月25日 星期日")
        #expect(labels.weekday(Fixtures.day(2026, 10, 26)) == "星期一")
    }

    @Test func relativeDayNamesNearbyDays() {
        #expect(labels.relativeDay(today, today: today) == "今天")
        #expect(labels.relativeDay(Fixtures.day(2026, 10, 24), today: today) == "昨天")
        #expect(labels.relativeDay(Fixtures.day(2026, 10, 26), today: today) == "明天")
        #expect(labels.relativeDay(Fixtures.day(2026, 10, 27), today: today) == "后天")
        #expect(labels.relativeDay(Fixtures.day(2026, 10, 21), today: today) == "4天前")
        #expect(labels.relativeDay(Fixtures.day(2026, 11, 3), today: today) == "11月3日")
        #expect(labels.relativeDay(Fixtures.day(2027, 1, 2), today: today) == "2027年1月2日")
    }

    @Test func reminderTimeShowsDayOnlyWhenNotToday() {
        let now = Fixtures.now
        #expect(labels.reminderTime(Fixtures.date(2026, 10, 25, 15, 5), now: now) == "15:05")
        #expect(labels.reminderTime(Fixtures.date(2026, 10, 26, 9), now: now) == "明天 09:00")
        #expect(labels.reminderTime(Fixtures.date(2026, 11, 3, 9), now: now) == "11月3日 09:00")
    }

    @Test func chineseMonthNames() {
        #expect(Labels.chineseMonth(1) == "一月")
        #expect(Labels.chineseMonth(10) == "十月")
        #expect(Labels.chineseMonth(12) == "十二月")
    }

    @Test func lunarNamesFollowTraditionalForms() {
        #expect(Labels.lunarName(month: 1, day: 1, isLeapMonth: false) == "正月初一")
        #expect(Labels.lunarName(month: 9, day: 15, isLeapMonth: false) == "九月十五")
        #expect(Labels.lunarName(month: 10, day: 20, isLeapMonth: false) == "十月二十")
        #expect(Labels.lunarName(month: 11, day: 10, isLeapMonth: false) == "冬月初十")
        #expect(Labels.lunarName(month: 12, day: 21, isLeapMonth: false) == "腊月廿一")
        #expect(Labels.lunarName(month: 4, day: 30, isLeapMonth: true) == "闰四月三十")
    }

    @Test func lunarDateIsReadFromTheChineseCalendar() {
        // Spring Festival 2026 fell on 17 February.
        #expect(labels.lunarDate(Fixtures.day(2026, 2, 17)) == "正月初一")
    }

    @Test func todaySummaryReadsNaturally() {
        #expect(Labels.todaySummary(remaining: 0, total: 0) == "今天还没有安排")
        #expect(Labels.todaySummary(remaining: 0, total: 4) == "今天的事都做完了")
        #expect(Labels.todaySummary(remaining: 3, total: 5) == "今天还有 3 件事")
    }
}
