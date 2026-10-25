import Foundation

/// Human-readable Chinese date and time labels.
public struct Labels: Sendable {
    private static let weekdayNames = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]

    public let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func weekday(_ day: DayKey) -> String {
        let index = calendar.component(.weekday, from: day.startOfDay(in: calendar)) - 1
        return Self.weekdayNames[index]
    }

    public func headerDate(_ day: DayKey) -> String {
        "\(day.month)月\(day.day)日 \(weekday(day))"
    }

    public func relativeDay(_ day: DayKey, today: DayKey) -> String {
        switch day.days(since: today, calendar: calendar) {
        case 0: return "今天"
        case -1: return "昨天"
        case 1: return "明天"
        case 2: return "后天"
        case let past where past < -1: return "\(-past)天前"
        default: return calendarDay(day, today: today)
        }
    }

    public func reminderTime(_ date: Date, now: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let clock = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        let day = DayKey(date, calendar: calendar)
        let today = DayKey(now, calendar: calendar)
        if day == today { return clock }
        if day.days(since: today, calendar: calendar) == 1 { return "明天 \(clock)" }
        return "\(calendarDay(day, today: today)) \(clock)"
    }

    public static func todaySummary(remaining: Int, total: Int) -> String {
        if total == 0 { return "今天还没有安排" }
        if remaining == 0 { return "今天的事都做完了" }
        return "今天还有 \(remaining) 件事"
    }

    public static func chineseMonth(_ month: Int) -> String {
        "\(chineseCount(month))月"
    }

    public func lunarDate(_ day: DayKey) -> String {
        var lunar = Calendar(identifier: .chinese)
        lunar.timeZone = calendar.timeZone
        let parts = lunar.dateComponents([.month, .day], from: day.startOfDay(in: calendar))
        return Self.lunarName(month: parts.month ?? 1, day: parts.day ?? 1, isLeapMonth: parts.isLeapMonth ?? false)
    }

    public static func lunarName(month: Int, day: Int, isLeapMonth: Bool) -> String {
        let monthName: String
        switch month {
        case 1: monthName = "正月"
        case 11: monthName = "冬月"
        case 12: monthName = "腊月"
        default: monthName = chineseMonth(month)
        }
        return (isLeapMonth ? "闰" : "") + monthName + lunarDay(day)
    }

    private static let chineseDigits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    /// 1...99 as Chinese numerals: 一, 十, 十二, 二十, 二十三.
    private static func chineseCount(_ value: Int) -> String {
        let tens = value / 10
        let ones = value % 10
        guard tens > 0 else { return chineseDigits[ones] }
        return (tens == 1 ? "" : chineseDigits[tens]) + "十" + chineseDigits[ones]
    }

    private static func lunarDay(_ day: Int) -> String {
        switch day {
        case 1...10: return "初" + (day == 10 ? "十" : chineseDigits[day])
        case 11...19: return "十" + chineseDigits[day - 10]
        case 20: return "二十"
        case 21...29: return "廿" + chineseDigits[day - 20]
        case 30: return "三十"
        default: return chineseCount(day)
        }
    }

    private func calendarDay(_ day: DayKey, today: DayKey) -> String {
        day.year == today.year ? "\(day.month)月\(day.day)日" : "\(day.year)年\(day.month)月\(day.day)日"
    }
}
