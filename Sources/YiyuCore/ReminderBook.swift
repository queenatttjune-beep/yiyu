import Foundation

/// Pure operations on reminders. Every function returns a new array.
public enum ReminderBook {
    /// A repeating reminder's next occurrence is always within this many days.
    private static let searchWindowDays = 8

    public static func adding(
        _ title: String,
        fireAt: Date,
        repeatRule: RepeatRule,
        to reminders: [Reminder],
        now: Date,
        id: UUID = UUID()
    ) -> [Reminder] {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return reminders }
        let reminder = Reminder(
            id: id, title: trimmed, fireAt: fireAt, repeatRule: repeatRule, isDone: false, createdAt: now
        )
        return reminders + [reminder]
    }

    public static func togglingDone(_ id: UUID, in reminders: [Reminder]) -> [Reminder] {
        reminders.map { reminder in
            guard reminder.id == id else { return reminder }
            var copy = reminder
            copy.isDone.toggle()
            return copy
        }
    }

    public static func removing(_ id: UUID, from reminders: [Reminder]) -> [Reminder] {
        reminders.filter { $0.id != id }
    }

    /// Moves a reminder to a new time and makes it active again.
    public static func rescheduling(_ id: UUID, to fireAt: Date, in reminders: [Reminder]) -> [Reminder] {
        reminders.map { reminder in
            guard reminder.id == id else { return reminder }
            var copy = reminder
            copy.fireAt = fireAt
            copy.isDone = false
            return copy
        }
    }

    /// "Remind me again later". A one-off reminder moves; a repeating one keeps its
    /// schedule and gets a one-off copy at the snooze time.
    public static func snoozing(
        _ id: UUID,
        until date: Date,
        in reminders: [Reminder],
        now: Date,
        newID: UUID = UUID()
    ) -> [Reminder] {
        guard let target = reminders.first(where: { $0.id == id }) else { return reminders }
        guard target.repeatRule != .none else {
            return rescheduling(id, to: date, in: reminders)
        }
        let copy = Reminder(id: newID, title: target.title, fireAt: date, repeatRule: .none, isDone: false, createdAt: now)
        return reminders + [copy]
    }

    /// The checkmark: a one-off reminder toggles done; a repeating one skips to its following time.
    public static func completing(_ id: UUID, in reminders: [Reminder], now: Date, calendar: Calendar) -> [Reminder] {
        reminders.map { reminder in
            guard reminder.id == id else { return reminder }
            var copy = reminder
            if reminder.repeatRule == .none {
                copy.isDone.toggle()
            } else if let next = nextFire(
                after: max(now, reminder.fireAt), from: reminder.fireAt, rule: reminder.repeatRule, calendar: calendar
            ) {
                copy.fireAt = next
            }
            return copy
        }
    }

    public struct Occurrence: Equatable, Sendable {
        public let reminder: Reminder
        public let date: Date
    }

    /// Every future time a notification should go off: one-off reminders once, repeating ones
    /// for each occurrence in the next `days`, so they keep notifying while the app is closed.
    public static func occurrences(
        of reminders: [Reminder],
        after now: Date,
        days: Int,
        limit: Int,
        calendar: Calendar
    ) -> [Occurrence] {
        let horizon = calendar.date(byAdding: .day, value: days, to: now) ?? now
        let all = reminders
            .filter { !$0.isDone && $0.fireAt > now }
            .flatMap { reminder in
                repeatDates(of: reminder, through: horizon, calendar: calendar)
                    .map { Occurrence(reminder: reminder, date: $0) }
            }
        return Array(all.sorted { $0.date < $1.date }.prefix(limit))
    }

    private static func repeatDates(of reminder: Reminder, through horizon: Date, calendar: Calendar) -> [Date] {
        guard reminder.repeatRule != .none else { return [reminder.fireAt] }
        var dates: [Date] = []
        var next: Date? = reminder.fireAt
        while let date = next, date <= horizon {
            dates.append(date)
            next = nextFire(after: date, from: reminder.fireAt, rule: reminder.repeatRule, calendar: calendar)
        }
        return dates
    }

    public static func clearingDone(from reminders: [Reminder]) -> [Reminder] {
        reminders.filter { !$0.isDone }
    }

    public static func upcoming(_ reminders: [Reminder], now: Date) -> [Reminder] {
        reminders.filter { !$0.isDone && $0.fireAt > now }.sorted { $0.fireAt < $1.fireAt }
    }

    /// Reminders whose time has passed but that nobody has ticked off yet.
    public static func due(_ reminders: [Reminder], now: Date) -> [Reminder] {
        reminders.filter { !$0.isDone && $0.fireAt <= now }.sorted { $0.fireAt < $1.fireAt }
    }

    /// Reminders that went off in the window `(start, end]`.
    public static func firing(_ reminders: [Reminder], after start: Date, through end: Date) -> [Reminder] {
        reminders
            .filter { !$0.isDone && $0.fireAt > start && $0.fireAt <= end }
            .sorted { $0.fireAt < $1.fireAt }
    }

    /// Moves repeating reminders whose time has passed to their next occurrence.
    public static func rollingForward(_ reminders: [Reminder], now: Date, calendar: Calendar) -> [Reminder] {
        reminders.map { reminder in
            guard !reminder.isDone,
                  reminder.repeatRule != .none,
                  reminder.fireAt <= now,
                  let next = nextFire(after: now, from: reminder.fireAt, rule: reminder.repeatRule, calendar: calendar)
            else { return reminder }
            var copy = reminder
            copy.fireAt = next
            return copy
        }
    }

    /// The first occurrence strictly after `reference`, keeping the time of day (and weekday) of `anchor`.
    public static func nextFire(after reference: Date, from anchor: Date, rule: RepeatRule, calendar: Calendar) -> Date? {
        guard rule != .none else { return nil }
        let anchorWeekday = calendar.component(.weekday, from: anchor)
        if anchor > reference, matches(anchor, rule: rule, anchorWeekday: anchorWeekday, calendar: calendar) {
            return anchor
        }
        let time = calendar.dateComponents([.hour, .minute, .second], from: anchor)
        let firstDay = calendar.startOfDay(for: max(reference, anchor))
        for offset in 0...searchWindowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let candidate = calendar.date(
                    bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day
                  )
            else { continue }
            if candidate > reference, matches(candidate, rule: rule, anchorWeekday: anchorWeekday, calendar: calendar) {
                return candidate
            }
        }
        return nil
    }

    private static func matches(_ date: Date, rule: RepeatRule, anchorWeekday: Int, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        switch rule {
        case .none: return false
        case .daily: return true
        case .weekdays: return (2...6).contains(weekday)
        case .weekly: return weekday == anchorWeekday
        }
    }
}
