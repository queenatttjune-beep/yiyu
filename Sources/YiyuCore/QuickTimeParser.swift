import Foundation

public struct ParsedReminder: Equatable, Sendable {
    public let title: String
    /// `nil` when the text names no time at all.
    public let fireAt: Date?
    public let repeatRule: RepeatRule

    /// True for a one-off time that has already passed, such as "今天下午3点" typed at 4 pm.
    public func isInThePast(now: Date) -> Bool {
        guard let fireAt, repeatRule == .none else { return false }
        return fireAt <= now
    }
}

/// Reads phrases like "明天下午3点 交作业", "30分钟后 关火" or "每周一 晚上7点 健身".
public struct QuickTimeParser: Sendable {
    private static let defaultHour = 9

    enum Period {
        case earlyMorning, morning, forenoon, noon, afternoon, dusk, evening

        var defaultHour: Int {
            switch self {
            case .earlyMorning: 6
            case .morning: 8
            case .forenoon: 9
            case .noon: 12
            case .afternoon: 15
            case .dusk: 18
            case .evening: 20
            }
        }

        /// The 24-hour time for an hour said with this period. "晚上12点" is the coming
        /// midnight, so it lands on the next day.
        func clockTime(_ hour: Int) -> (hour: Int, dayShift: Int) {
            switch self {
            case .earlyMorning: (hour == 12 ? 0 : hour, 0)
            case .morning, .forenoon: (hour, 0)
            case .noon: (hour < 11 ? hour + 12 : hour, 0)
            case .afternoon, .dusk: (hour < 12 ? hour + 12 : hour, 0)
            case .evening: hour == 12 ? (0, 1) : (hour < 12 ? hour + 12 : hour, 0)
            }
        }
    }

    enum DayKind {
        case offset(Int)
        /// Weekday 1 = Monday ... 7 = Sunday.
        case weekday(Int, nextWeek: Bool)
        case monthDay(month: Int, day: Int)
        case dayOfMonth(Int)
        case dayOfNextMonth(Int)
    }

    struct DaySpec {
        let kind: DayKind
        var impliedPeriod: Period?
    }

    struct RepeatSpec {
        let rule: RepeatRule
        var weekday: Int?
        var impliedPeriod: Period?
    }

    struct Clock {
        let hour: Int
        let minute: Int
        /// Written as "9:30", so the hour is taken literally.
        let isTwentyFourHour: Bool
    }

    public let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func parse(_ input: String, now: Date) -> ParsedReminder {
        var scan = ParseScan(text: ChineseNumber.normalizingDigits(input))

        if let offset = takeRelativeOffset(&scan) {
            return ParsedReminder(title: scan.title, fireAt: now.addingTimeInterval(offset), repeatRule: .none)
        }

        let repeating = takeRepeat(&scan)
        let day = takeDay(&scan)
        let period = takePeriod(&scan)
        let impliedPeriod = period ?? day?.impliedPeriod ?? repeating?.impliedPeriod
        let clock = takeClock(&scan, hasPeriod: impliedPeriod != nil)

        guard repeating != nil || day != nil || period != nil || clock != nil else {
            return ParsedReminder(title: scan.title, fireAt: nil, repeatRule: .none)
        }
        let fireAt = resolve(repeating: repeating, day: day, period: impliedPeriod, clock: clock, now: now)
        return ParsedReminder(title: scan.title, fireAt: fireAt, repeatRule: repeating?.rule ?? .none)
    }

    // MARK: - Recognisers

    private static let clockMarks: Set<Character> = ["点", "时"]

    /// "30分钟后", "半小时后", "一个半小时后", "1小时30分钟后", "1.5小时后".
    private func takeRelativeOffset(_ scan: inout ParseScan) -> TimeInterval? {
        let hours = #/(\d{1,2}(?:\.\d+)?|[零一二两三四五六七八九十]{1,3}|半)\s*个?\s*(半)?\s*(?:小时|钟头)(?:\s*(\d{1,2}|[零一二两三四五六七八九十]{1,3})\s*分钟?)?\s*(?:以后|之后|后)/#
        if let interval = scan.take(hours, { output -> TimeInterval? in
            guard let whole = Self.amount(output.1) else { return nil }
            let half = output.2 == nil ? 0 : 0.5
            let minutes = output.3.flatMap { ChineseNumber.value($0) } ?? 0
            return (whole + half) * 3600 + Double(minutes) * 60
        }) {
            return interval
        }
        let minutes = #/(\d{1,3}|[零一二两三四五六七八九十]{1,3}|半)\s*(?:分钟|分)\s*(?:以后|之后|后)/#
        return scan.take(minutes, notPrecededBy: Self.clockMarks) { output -> TimeInterval? in
            Self.amount(output.1).map { $0 * 60 }
        }
    }

    private static func amount(_ token: Substring) -> Double? {
        if token == "半" { return 0.5 }
        if let decimal = Double(token) { return decimal }
        return ChineseNumber.value(token).map(Double.init)
    }

    private func takeRepeat(_ scan: inout ParseScan) -> RepeatSpec? {
        if let weekday = scan.take(#/每个?(?:周|星期|礼拜)([一二三四五六日天1-7])/#, { ChineseNumber.weekday($0.1) }) {
            return RepeatSpec(rule: .weekly, weekday: weekday)
        }
        if scan.take(#/(?:每个?)?工作日/#, { _ in true }) != nil {
            return RepeatSpec(rule: .weekdays)
        }
        let dailyWords: [(String, Period?)] = [
            ("每天", nil), ("每日", nil), ("天天", nil), ("每晚", .evening), ("每早", .morning),
        ]
        if let implied = scan.takeWord(from: dailyWords) {
            return RepeatSpec(rule: .daily, impliedPeriod: implied)
        }
        return nil
    }

    private func takeDay(_ scan: inout ParseScan) -> DaySpec? {
        if let day = scan.take(#/下个?月\s*(\d{1,2}|[零一二两三四五六七八九十]{1,3})\s*[日号]/#, {
            ChineseNumber.value($0.1)
        }) {
            return DaySpec(kind: .dayOfNextMonth(day))
        }
        if let kind = scan.take(#/(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]/#, { output -> DayKind? in
            guard let month = Int(output.1), let day = Int(output.2) else { return nil }
            return .monthDay(month: month, day: day)
        }) {
            return DaySpec(kind: kind)
        }
        if let kind = scan.take(#/(下个?|这个?|本)?(?:周|星期|礼拜)([一二三四五六日天1-7])/#, { output -> DayKind? in
            guard let weekday = ChineseNumber.weekday(output.2) else { return nil }
            let isNextWeek = output.1?.hasPrefix("下") ?? false
            return .weekday(weekday, nextWeek: isNextWeek)
        }) {
            return DaySpec(kind: kind)
        }
        if let days = scan.take(#/(\d{1,3}|[零一二两三四五六七八九十]{1,3})\s*天\s*(?:以后|之后|后)/#, {
            ChineseNumber.value($0.1)
        }) {
            return DaySpec(kind: .offset(days))
        }
        let dayWords: [(String, DaySpec)] = [
            ("大后天", DaySpec(kind: .offset(3))),
            ("后天", DaySpec(kind: .offset(2))),
            ("明天", DaySpec(kind: .offset(1))),
            ("明日", DaySpec(kind: .offset(1))),
            ("明早", DaySpec(kind: .offset(1), impliedPeriod: .morning)),
            ("明晚", DaySpec(kind: .offset(1), impliedPeriod: .evening)),
            ("今天", DaySpec(kind: .offset(0))),
            ("今日", DaySpec(kind: .offset(0))),
            ("今早", DaySpec(kind: .offset(0), impliedPeriod: .morning)),
            ("今晚", DaySpec(kind: .offset(0), impliedPeriod: .evening)),
            ("今夜", DaySpec(kind: .offset(0), impliedPeriod: .evening)),
        ]
        if let spec = scan.takeWord(from: dayWords) {
            return spec
        }
        // "5号楼", "2号线" and the like are places, not dates.
        if let day = scan.take(#/(\d{1,2})\s*[日号](?![楼线房门院床机馆厅座栋层室])/#, { Int($0.1) }) {
            return DaySpec(kind: .dayOfMonth(day))
        }
        return nil
    }

    private func takePeriod(_ scan: inout ParseScan) -> Period? {
        let periodWords: [(String, Period)] = [
            ("凌晨", .earlyMorning), ("清晨", .morning), ("早上", .morning), ("早晨", .morning),
            ("上午", .forenoon), ("中午", .noon), ("下午", .afternoon), ("傍晚", .dusk),
            ("晚上", .evening), ("夜里", .evening), ("夜晚", .evening),
        ]
        if let period = scan.takeWord(from: periodWords) {
            return period
        }
        // A bare 早 / 晚 counts only right before an hour: "晚8点", not "晚饭".
        return scan.take(#/([早晚])(?=\s*(?:\d|[零一二两三四五六七八九十]))/#) { output -> Period? in
            output.1 == "早" ? .morning : .evening
        }
    }

    private func takeClock(_ scan: inout ParseScan, hasPeriod: Bool) -> Clock? {
        if let clock = scan.take(#/(\d{1,2})\s*[:：]\s*(\d{2})/#, { output -> Clock? in
            guard let hour = Int(output.1), let minute = Int(output.2) else { return nil }
            return Self.validClock(hour: hour, minute: minute, isTwentyFourHour: true)
        }) {
            return clock
        }
        let spoken = #/(\d{1,2}|[零一二两三四五六七八九十]{1,3})\s*[点时]钟?(半|一刻|三刻|(\d{1,2}|[零一二两三四五六七八九十]{1,3})分?)?/#
        return scan.take(spoken) { output -> Clock? in
            // "喝一点水" means "a little water", not one o'clock.
            if output.1 == "一", output.2 == nil, !hasPeriod { return nil }
            guard let hour = ChineseNumber.value(output.1) else { return nil }
            let minute: Int?
            switch output.2 {
            case nil: minute = 0
            case "半": minute = 30
            case "一刻": minute = 15
            case "三刻": minute = 45
            default: minute = output.3.flatMap { ChineseNumber.value($0) }
            }
            guard let minute else { return nil }
            return Self.validClock(hour: hour, minute: minute, isTwentyFourHour: false)
        }
    }

    private static func validClock(hour: Int, minute: Int, isTwentyFourHour: Bool) -> Clock? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return Clock(hour: hour, minute: minute, isTwentyFourHour: isTwentyFourHour)
    }

    // MARK: - Resolution

    private func resolve(repeating: RepeatSpec?, day: DaySpec?, period: Period?, clock: Clock?, now: Date) -> Date? {
        let today = calendar.startOfDay(for: now)
        let time = timeOfDay(clock: clock, period: period)

        let candidate: Date?
        if let day {
            candidate = resolveDay(day.kind, hour: time.hour, minute: time.minute, today: today, now: now)
                .flatMap { shifted($0, days: time.dayShift) }
        } else if let weekday = repeating?.weekday {
            candidate = upcomingWeekday(weekday, nextWeek: false, hour: time.hour, minute: time.minute, today: today, now: now)
                .flatMap { shifted($0, days: time.dayShift) }
        } else {
            let usesWakingGuess = repeating == nil && period == nil && clock.map { !$0.isTwentyFourHour } == true
            candidate = shifted(today, days: time.dayShift).flatMap {
                soonest(from: $0, hour: time.hour, minute: time.minute, now: now, guessEvening: usesWakingGuess)
            }
        }

        guard let candidate else { return nil }
        guard let rule = repeating?.rule else { return candidate }
        return ReminderBook.nextFire(after: now, from: candidate, rule: rule, calendar: calendar) ?? candidate
    }

    private func timeOfDay(clock: Clock?, period: Period?) -> (hour: Int, minute: Int, dayShift: Int) {
        guard let clock else {
            return (period?.defaultHour ?? Self.defaultHour, 0, 0)
        }
        if let period {
            let time = period.clockTime(clock.hour)
            return (time.hour, clock.minute, time.dayShift)
        }
        if clock.isTwentyFourHour {
            return (clock.hour, clock.minute, 0)
        }
        // "3点" almost always means the afternoon.
        let hour = (1...6).contains(clock.hour) ? clock.hour + 12 : clock.hour
        return (hour, clock.minute, 0)
    }

    /// The first time at `hour:minute` on `day` or later that is still ahead of `now`.
    private func soonest(from day: Date, hour: Int, minute: Int, now: Date, guessEvening: Bool) -> Date? {
        guard var candidate = at(day, hour: hour, minute: minute) else { return nil }
        if candidate <= now, guessEvening, (7...11).contains(hour),
           let evening = calendar.date(byAdding: .hour, value: 12, to: candidate), evening > now {
            candidate = evening
        }
        if candidate <= now {
            return calendar.date(byAdding: .day, value: 1, to: candidate)
        }
        return candidate
    }

    private func shifted(_ date: Date, days: Int) -> Date? {
        days == 0 ? date : calendar.date(byAdding: .day, value: days, to: date)
    }

    private func resolveDay(_ kind: DayKind, hour: Int, minute: Int, today: Date, now: Date) -> Date? {
        switch kind {
        case .offset(let days):
            guard let day = calendar.date(byAdding: .day, value: days, to: today) else { return nil }
            return at(day, hour: hour, minute: minute)
        case .weekday(let weekday, let nextWeek):
            return upcomingWeekday(weekday, nextWeek: nextWeek, hour: hour, minute: minute, today: today, now: now)
        case .monthDay(let month, let dayNumber):
            let year = calendar.component(.year, from: today)
            if let thisYear = exactDate(year: year, month: month, day: dayNumber, hour: hour, minute: minute),
               thisYear > now {
                return thisYear
            }
            return exactDate(year: year + 1, month: month, day: dayNumber, hour: hour, minute: minute)
        case .dayOfMonth(let dayNumber):
            let (year, month) = yearMonth(of: today, addingMonths: 0)
            if let thisMonth = exactDate(year: year, month: month, day: dayNumber, hour: hour, minute: minute),
               thisMonth > now {
                return thisMonth
            }
            let next = yearMonth(of: today, addingMonths: 1)
            return exactDate(year: next.year, month: next.month, day: dayNumber, hour: hour, minute: minute)
        case .dayOfNextMonth(let dayNumber):
            let next = yearMonth(of: today, addingMonths: 1)
            return exactDate(year: next.year, month: next.month, day: dayNumber, hour: hour, minute: minute)
        }
    }

    private func yearMonth(of date: Date, addingMonths months: Int) -> (year: Int, month: Int) {
        let shiftedDate = calendar.date(byAdding: .month, value: months, to: date) ?? date
        let parts = calendar.dateComponents([.year, .month], from: shiftedDate)
        return (parts.year ?? 1970, parts.month ?? 1)
    }

    /// Weeks start on Monday. A bare weekday that has already passed this week means next week's.
    private func upcomingWeekday(
        _ weekday: Int, nextWeek: Bool, hour: Int, minute: Int, today: Date, now: Date
    ) -> Date? {
        let gregorianWeekday = calendar.component(.weekday, from: today)
        let todayIndex = gregorianWeekday == 1 ? 7 : gregorianWeekday - 1
        var offset = weekday - todayIndex
        if nextWeek {
            offset += 7
        } else if offset < 0 {
            offset += 7
        }
        guard let day = calendar.date(byAdding: .day, value: offset, to: today),
              let candidate = at(day, hour: hour, minute: minute)
        else { return nil }
        if !nextWeek, candidate <= now {
            return calendar.date(byAdding: .day, value: 7, to: candidate)
        }
        return candidate
    }

    private func at(_ day: Date, hour: Int, minute: Int) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    private func exactDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        let wanted = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        guard let date = calendar.date(from: wanted) else { return nil }
        let actual = calendar.dateComponents([.year, .month, .day], from: date)
        guard actual.year == year, actual.month == month, actual.day == day else { return nil }
        return date
    }
}
