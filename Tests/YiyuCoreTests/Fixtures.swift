import Foundation
@testable import YiyuCore

enum Fixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        guard let date = calendar.date(from: parts) else {
            preconditionFailure("Invalid fixture date \(parts)")
        }
        return date
    }

    static func day(_ year: Int, _ month: Int, _ day: Int) -> DayKey {
        DayKey(year: year, month: month, day: day)
    }

    /// Sunday 2026-10-25 10:00 in Shanghai.
    static let now = date(2026, 10, 25, 10, 0)
    static let today = day(2026, 10, 25)
}
