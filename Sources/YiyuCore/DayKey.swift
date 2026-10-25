import Foundation

/// A calendar day independent of time of day, stored as "yyyy-MM-dd".
public struct DayKey: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else {
            return nil
        }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public func startOfDay(in calendar: Calendar) -> Date {
        let parts = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }

    public func adding(days: Int, calendar: Calendar) -> DayKey {
        let start = startOfDay(in: calendar)
        let shifted = calendar.date(byAdding: .day, value: days, to: start) ?? start
        return DayKey(shifted, calendar: calendar)
    }

    /// Whole days from `other` to this day; negative when this day is earlier.
    public func days(since other: DayKey, calendar: Calendar) -> Int {
        let from = other.startOfDay(in: calendar)
        let to = startOfDay(in: calendar)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

extension DayKey: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let key = DayKey(string: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid day key: \(raw)")
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
