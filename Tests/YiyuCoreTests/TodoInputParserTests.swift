import Testing
@testable import YiyuCore

struct TodoInputParserTests {
    let parser = TodoInputParser(calendar: Fixtures.calendar)

    @Test(arguments: [
        ("把明天的周报写了", "写周报"),
        ("帮我把明天的周报写完", "写周报"),
        ("请帮我明天写周报", "写周报"),
        ("把 明天 的周报 写好了", "写周报"),
        ("明天把报告提交了", "提交报告"),
        ("将明天的材料打印一下", "打印材料"),
        ("帮我把明天的牛奶买了", "买牛奶"),
    ])
    func spokenTasksSeparateDateAndAction(input: String, title: String) {
        let result = parser.parse(input, now: Fixtures.now)
        #expect(result.title == title)
        #expect(result.plannedDay == Fixtures.day(2026, 10, 26))
        #expect(result.unresolvedDate == nil)
    }

    @Test(arguments: [
        ("今天买菜", Fixtures.day(2026, 10, 25)),
        ("后天买菜", Fixtures.day(2026, 10, 27)),
        ("大后天买菜", Fixtures.day(2026, 10, 28)),
        ("三天后买菜", Fixtures.day(2026, 10, 28)),
        ("下周五买菜", Fixtures.day(2026, 10, 30)),
        ("下星期一买菜", Fixtures.day(2026, 10, 26)),
        ("11月3号买菜", Fixtures.day(2026, 11, 3)),
        ("下个月五号买菜", Fixtures.day(2026, 11, 5)),
        ("２８号买菜", Fixtures.day(2026, 10, 28)),
        ("周日买菜", Fixtures.day(2026, 10, 25)),
        ("25号买菜", Fixtures.day(2026, 10, 25)),
    ])
    func commonCalendarDatesDoNotDependOnReminderTime(input: String, day: DayKey) {
        let result = parser.parse(input, now: Fixtures.date(2026, 10, 25, 23))
        #expect(result.title == "买菜")
        #expect(result.plannedDay == day)
    }

    @Test func dateCrossesYearAndUsesTheGivenCalendar() {
        let result = parser.parse("明天写周报", now: Fixtures.date(2026, 12, 31, 23, 59))
        #expect(result.plannedDay == Fixtures.day(2027, 1, 1))
    }

    @Test func theFirstDateSchedulesTheTaskAndLaterDatesRemainContent() {
        let result = parser.parse("明天准备后天的会议", now: Fixtures.now)
        #expect(result.title == "准备后天的会议")
        #expect(result.plannedDay == Fixtures.day(2026, 10, 26))
    }

    @Test(arguments: ["买牛奶", "请假", "请客吃饭", "去5号楼取快递", "坐2号线", "读《明天会更好》", "联系明天科技", "每周五写周报", "上周五的会议记录"])
    func contentIsNotMistakenForASchedule(input: String) {
        let result = parser.parse(input, now: Fixtures.now)
        #expect(result.title == input)
        #expect(result.plannedDay == nil)
    }

    @Test func quotedContentAndNegationSurviveTitleCleanup() {
        let book = parser.parse("明天读《后天》", now: Fixtures.now)
        #expect(book.title == "读《后天》")
        #expect(book.plannedDay == Fixtures.day(2026, 10, 26))
        #expect(parser.parse("明天不要提交旧报告", now: Fixtures.now).title == "不要提交旧报告")
        #expect(parser.parse("把明天的周报写详细一点", now: Fixtures.now).title == "把周报写详细一点")
        #expect(parser.parse("把明天的周报写好再发", now: Fixtures.now).title == "把周报写好再发")
    }

    @Test func anImpossibleDateIsReportedAndNotStripped() {
        let result = parser.parse("11月31号交报告", now: Fixtures.now)
        #expect(result.title == "11月31号交报告")
        #expect(result.plannedDay == nil)
        #expect(result.unresolvedDate == "11月31号")
    }

    @Test func aDateWithoutATaskDoesNotInventATitle() {
        #expect(parser.parse("明天", now: Fixtures.now).title.isEmpty)
        #expect(parser.parse("请帮我明天", now: Fixtures.now).title.isEmpty)
        #expect(parser.parse("  ", now: Fixtures.now).title.isEmpty)
    }
}
