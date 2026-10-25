import Foundation
import Testing
@testable import YiyuCore

struct QuickTimeParserTests {
    let parser = QuickTimeParser(calendar: Fixtures.calendar)
    let now = Fixtures.now  // Sunday 2026-10-25 10:00

    private func parse(_ text: String, at reference: Date = Fixtures.now) -> ParsedReminder {
        parser.parse(text, now: reference)
    }

    @Test func tomorrowAfternoon() {
        let result = parse("明天下午3点 交作业")
        #expect(result.title == "交作业")
        #expect(result.fireAt == Fixtures.date(2026, 10, 26, 15))
        #expect(result.repeatRule == .none)
    }

    @Test func relativeMinutesAndHours() {
        #expect(parse("30分钟后 关火").fireAt == now.addingTimeInterval(30 * 60))
        #expect(parse("30分钟后 关火").title == "关火")
        #expect(parse("半小时后 喝水").fireAt == now.addingTimeInterval(30 * 60))
        #expect(parse("两个小时后 取快递").fireAt == now.addingTimeInterval(2 * 3600))
    }

    @Test func fullWidthDigitsAreUnderstood() {
        let result = parse("１０分钟后")
        #expect(result.fireAt == now.addingTimeInterval(10 * 60))
        #expect(result.title == "提醒")
    }

    @Test func weekdaysFollowMondayFirstWeeks() {
        #expect(parse("下周五 交报告").fireAt == Fixtures.date(2026, 10, 30, 9))
        #expect(parse("周三 上午10点半 开会").fireAt == Fixtures.date(2026, 10, 28, 10, 30))

        let wednesday = Fixtures.date(2026, 10, 21, 10)
        #expect(parse("周五 交报告", at: wednesday).fireAt == Fixtures.date(2026, 10, 23, 9))
        #expect(parse("下周五 交报告", at: wednesday).fireAt == Fixtures.date(2026, 10, 30, 9))
    }

    @Test func repeatingPhrases() {
        let daily = parse("每天早上8点 吃药")
        #expect(daily.repeatRule == .daily)
        #expect(daily.title == "吃药")
        #expect(daily.fireAt == Fixtures.date(2026, 10, 26, 8))

        let workdays = parse("工作日 9:30 站会")
        #expect(workdays.repeatRule == .weekdays)
        #expect(workdays.fireAt == Fixtures.date(2026, 10, 26, 9, 30))

        let weekly = parse("每周一 晚上7点 健身")
        #expect(weekly.repeatRule == .weekly)
        #expect(weekly.fireAt == Fixtures.date(2026, 10, 26, 19))
    }

    @Test func bareHoursPreferWakingTime() {
        #expect(parse("3点 开会").fireAt == Fixtures.date(2026, 10, 25, 15))
        #expect(parse("8点 跑步").fireAt == Fixtures.date(2026, 10, 25, 20))
        #expect(parse("明天3点 开会").fireAt == Fixtures.date(2026, 10, 26, 15))
        #expect(parse("明天8点 开会").fireAt == Fixtures.date(2026, 10, 26, 8))
    }

    @Test func passedTimeMovesToTomorrow() {
        #expect(parse("早上8点 跑步").fireAt == Fixtures.date(2026, 10, 26, 8))
    }

    @Test func periodsAndChineseNumerals() {
        #expect(parse("今晚 看电影").fireAt == Fixtures.date(2026, 10, 25, 20))
        #expect(parse("中午12点 吃饭").fireAt == Fixtures.date(2026, 10, 25, 12))
        #expect(parse("晚上十点 睡觉").fireAt == Fixtures.date(2026, 10, 25, 22))
        #expect(parse("下午3点一刻 喝茶").fireAt == Fixtures.date(2026, 10, 25, 15, 15))
    }

    @Test func calendarDates() {
        #expect(parse("11月3号 体检").fireAt == Fixtures.date(2026, 11, 3, 9))
        #expect(parse("28号 交房租").fireAt == Fixtures.date(2026, 10, 28, 9))
        #expect(parse("20号 交房租").fireAt == Fixtures.date(2026, 11, 20, 9))
        #expect(parse("3天后 还书").fireAt == Fixtures.date(2026, 10, 28, 9))
    }

    @Test func titleDropsFillerWords() {
        let result = parse("提醒我 明天 带伞")
        #expect(result.title == "带伞")
        #expect(result.fireAt == Fixtures.date(2026, 10, 26, 9))
        #expect(parse("下午3点的会").title == "会")
    }

    @Test func plainTextHasNoTime() {
        let result = parse("买牛奶")
        #expect(result.title == "买牛奶")
        #expect(result.fireAt == nil)
        #expect(result.repeatRule == .none)
    }

    @Test func compoundRelativeDurations() {
        #expect(parse("一个半小时后 收衣服").fireAt == now.addingTimeInterval(90 * 60))
        #expect(parse("1小时30分钟后 收衣服").fireAt == now.addingTimeInterval(90 * 60))
        #expect(parse("1.5小时后 收衣服").fireAt == now.addingTimeInterval(90 * 60))
        #expect(parse("一个半小时后 收衣服").title == "收衣服")
    }

    @Test func midnightWordsMeanTheComingMidnight() {
        let evening = Fixtures.date(2026, 10, 25, 20)
        #expect(parse("今晚12点 关电脑", at: evening).fireAt == Fixtures.date(2026, 10, 26, 0))
        #expect(parse("晚上12点 关电脑", at: evening).fireAt == Fixtures.date(2026, 10, 26, 0))
        #expect(parse("凌晨12点 关电脑", at: evening).fireAt == Fixtures.date(2026, 10, 26, 0))
    }

    @Test func singleCharacterPeriodsBeforeAnHour() {
        #expect(parse("晚8点 跑步", at: Fixtures.date(2026, 10, 25, 7)).fireAt == Fixtures.date(2026, 10, 25, 20))
        #expect(parse("早7点 起床").fireAt == Fixtures.date(2026, 10, 26, 7))
    }

    @Test func nextMonthAndBuildingNumbers() {
        let october3 = Fixtures.date(2026, 10, 3, 10)
        let nextMonth = parse("下个月5号 交房租", at: october3)
        #expect(nextMonth.fireAt == Fixtures.date(2026, 11, 5, 9))
        #expect(nextMonth.title == "交房租")

        let building = parse("去5号楼 下午3点")
        #expect(building.fireAt == Fixtures.date(2026, 10, 25, 15))
        #expect(building.title == "去5号楼")
    }

    @Test func minutesWrittenWithZero() {
        let result = parse("下午三点零五 打电话")
        #expect(result.fireAt == Fixtures.date(2026, 10, 25, 15, 5))
        #expect(result.title == "打电话")
    }

    @Test func aLittleIsNotOneOClock() {
        let result = parse("喝一点水")
        #expect(result.fireAt == nil)
        #expect(result.title == "喝一点水")
        #expect(parse("下午一点 开会").fireAt == Fixtures.date(2026, 10, 25, 13))
    }

    @Test func clockMinutesFollowedByLaterAreNotARelativeOffset() {
        #expect(parse("3点20分以后 打电话").fireAt == Fixtures.date(2026, 10, 25, 15, 20))
    }

    @Test func explicitTodayInThePastStaysInThePast() {
        let afternoon = Fixtures.date(2026, 10, 25, 16)
        let result = parse("今天下午3点 交作业", at: afternoon)
        #expect(result.fireAt == Fixtures.date(2026, 10, 25, 15))
        #expect(result.isInThePast(now: afternoon))
        #expect(!parse("明天下午3点 交作业", at: afternoon).isInThePast(now: afternoon))
    }
}
