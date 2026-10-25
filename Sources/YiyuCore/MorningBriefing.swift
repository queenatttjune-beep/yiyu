import Foundation

/// When the morning outfit notification goes out.
public struct BriefingSchedule: Codable, Equatable, Sendable {
    public static let `default` = BriefingSchedule(isEnabled: true, hour: 7, minute: 30)

    public let isEnabled: Bool
    public let hour: Int
    public let minute: Int

    public init(isEnabled: Bool, hour: Int, minute: Int) {
        self.isEnabled = isEnabled
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.default
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? fallback.isEnabled,
            hour: try container.decodeIfPresent(Int.self, forKey: .hour) ?? fallback.hour,
            minute: try container.decodeIfPresent(Int.self, forKey: .minute) ?? fallback.minute
        )
    }

    /// "7:30"
    public var timeLabel: String { String(format: "%d:%02d", hour, minute) }
}

/// Decides when the morning notification is due. The Mac may be asleep at the set time, so a
/// missed one is still sent on waking, but only until noon (or an hour after a late set time).
public enum MorningBriefing {
    private static let latestHour = 12
    private static let minimumGrace: TimeInterval = 3600

    public static func isDue(_ schedule: BriefingSchedule, now: Date, lastSentDay: DayKey?, calendar: Calendar) -> Bool {
        let today = DayKey(now, calendar: calendar)
        guard schedule.isEnabled, lastSentDay != today else { return false }
        let start = today.startOfDay(in: calendar)
        guard let sendAt = calendar.date(bySettingHour: schedule.hour, minute: schedule.minute, second: 0, of: start),
              let noon = calendar.date(bySettingHour: latestHour, minute: 0, second: 0, of: start)
        else { return false }
        let deadline = max(noon, sendAt.addingTimeInterval(minimumGrace))
        return sendAt <= now && now < deadline
    }
}
