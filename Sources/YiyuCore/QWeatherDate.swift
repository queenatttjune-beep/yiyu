import Foundation

/// 和风天气 times are ISO 8601 to the minute ("2024-05-31T03:00Z", "2024-05-31T11:00+08:00"),
/// which `ISO8601DateFormatter` rejects without seconds.
enum QWeatherDate {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    static func parse(_ text: String) -> Date? {
        let halves = text.split(separator: "T", omittingEmptySubsequences: false)
        guard halves.count == 2, let (time, offset) = splitOffset(String(halves[1])) else { return nil }
        let day = halves[0].split(separator: "-").compactMap { Int($0) }
        let clock = time.split(separator: ":").compactMap { Int($0) }
        guard day.count == 3, (1...12).contains(day[1]), (1...31).contains(day[2]),
              (2...3).contains(clock.count), (0...23).contains(clock[0]), (0...59).contains(clock[1])
        else { return nil }

        let parts = DateComponents(
            year: day[0], month: day[1], day: day[2],
            hour: clock[0], minute: clock[1], second: clock.count == 3 ? clock[2] : 0
        )
        return utc.date(from: parts).map { $0.addingTimeInterval(-TimeInterval(offset)) }
    }

    /// "03:00Z" → ("03:00", 0); "11:00+08:00" → ("11:00", 28800). A time without a zone is rejected.
    private static func splitOffset(_ time: String) -> (String, Int)? {
        if time.hasSuffix("Z") {
            return (String(time.dropLast()), 0)
        }
        guard let signIndex = time.lastIndex(where: { $0 == "+" || $0 == "-" }) else { return nil }
        let sign = time[signIndex] == "-" ? -1 : 1
        let digits = time[time.index(after: signIndex)...].filter { $0 != ":" }
        guard digits.count == 4, let hours = Int(digits.prefix(2)), let minutes = Int(digits.suffix(2)) else { return nil }
        return (String(time[..<signIndex]), sign * (hours * 3600 + minutes * 60))
    }
}
