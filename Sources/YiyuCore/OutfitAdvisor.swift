import Foundation

/// How warmly to dress, after the seven bands of the 中国气象局 穿衣指数.
public enum OutfitLevel: Int, CaseIterable, Comparable, Sendable {
    case freezing, cold, cool, mild, comfortable, warm, hot

    /// Lowest daytime feels-like temperature for each band, warmest first.
    private static let lowerBounds: [(OutfitLevel, Double)] = [
        (.hot, 28), (.warm, 24), (.comfortable, 20), (.mild, 15), (.cool, 10), (.cold, 5),
    ]

    public init(feelsLike: Double) {
        self = Self.lowerBounds.first { feelsLike >= $0.1 }?.0 ?? .freezing
    }

    public var title: String {
        switch self {
        case .freezing: "寒冷"
        case .cold: "冷"
        case .cool: "较冷"
        case .mild: "较舒适"
        case .comfortable: "舒适"
        case .warm: "热"
        case .hot: "炎热"
        }
    }

    public var clothing: String {
        switch self {
        case .freezing: "羽绒服，戴上帽子、手套和围巾"
        case .cold: "毛衣加厚外套"
        case .cool: "卫衣、夹克或风衣"
        case .mild: "长袖加薄外套或针织衫"
        case .comfortable: "长袖衬衫或 T 恤"
        case .warm: "短袖加薄长裤"
        case .hot: "短袖短裤或裙装，选轻薄透气的"
        }
    }

    public static func < (lhs: OutfitLevel, rhs: OutfitLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// What to wear for the daytime ahead: today's, or tomorrow's once it is evening.
public struct OutfitAdvice: Equatable, Sendable {
    public let dayKey: DayKey
    public let isToday: Bool
    public let level: OutfitLevel
    /// Extra advice beyond the clothes: a cool morning, rain or snow, wind, sun.
    public let tips: [String]
    public let temperatureMin: Int
    public let temperatureMax: Int
    public let conditionText: String

    /// "今日穿衣 · 舒适"
    public var title: String { "\(isToday ? "今日" : "明日")穿衣 · \(level.title)" }

    /// "长袖衬衫或 T 恤；早晚只有 17°，带件薄外套。"
    public var summary: String { ([level.clothing] + tips).joined(separator: "；") + "。" }

    /// "今天 17–24° · 小雨", the title of the morning notification.
    public var headline: String {
        let range = "\(isToday ? "今天" : "明天") \(temperatureMin)–\(temperatureMax)°"
        return conditionText.isEmpty ? range : "\(range) · \(conditionText)"
    }
}

/// Turns a forecast into clothing advice, from the feels-like temperature of the daytime hours
/// still ahead (8:00 to 20:00) plus rain, snow, wind and sun.
public enum OutfitAdvisor {
    private static let daytimeStartHour = 8
    private static let daytimeEndHour = 20
    /// From this hour on, today's daytime is nearly over and the advice is for tomorrow.
    private static let eveningHour = 18
    private static let swingThreshold = 7
    private static let rainLikely = 0.5
    private static let rainPossible = 0.3
    private static let strongWindScale = 5
    private static let strongUVIndex = 6.0

    public static func advice(for snapshot: WeatherSnapshot, now: Date, calendar: Calendar) -> OutfitAdvice? {
        let today = DayKey(now, calendar: calendar)
        let isToday = calendar.component(.hour, from: now) < eveningHour
        let day = isToday ? today : today.adding(days: 1, calendar: calendar)
        let start = day.startOfDay(in: calendar)
        guard let daytimeStart = calendar.date(bySettingHour: daytimeStartHour, minute: 0, second: 0, of: start),
              let daytimeEnd = calendar.date(bySettingHour: daytimeEndHour, minute: 0, second: 0, of: start)
        else { return nil }
        let currentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let from = isToday ? max(daytimeStart, currentHour) : daytimeStart
        let hours = snapshot.hours.filter { $0.time >= from && $0.time < daytimeEnd }
        guard !hours.isEmpty else { return nil }

        let level = OutfitLevel(feelsLike: hours.map(\.feelsLike).reduce(0, +) / Double(hours.count))
        let daily = snapshot.day(containing: calendar.date(byAdding: .hour, value: 12, to: start) ?? start)
        let low = Int((daily?.temperatureMin ?? hours.map(\.temperature).min() ?? 0).rounded())
        let high = Int((daily?.temperatureMax ?? hours.map(\.temperature).max() ?? 0).rounded())
        let tips = [
            swingTip(low: low, high: high, level: level),
            precipitationTip(hours, calendar: calendar),
            windTip(hours, level: level),
            sunTip(hours, daily: daily),
        ].compactMap { $0 }

        return OutfitAdvice(
            dayKey: day, isToday: isToday, level: level, tips: tips, temperatureMin: low, temperatureMax: high,
            conditionText: daily?.daytime?.text ?? mostCommonCondition(hours)
        )
    }

    private static func swingTip(low: Int, high: Int, level: OutfitLevel) -> String? {
        guard high - low >= swingThreshold else { return nil }
        return level >= .comfortable ? "早晚只有 \(low)°，带件薄外套" : "早晚温差 \(high - low)°，里面穿薄些，方便增减"
    }

    private enum Wintry { case snow, sleet }

    private static func wintry(_ hour: HourlyWeather) -> Wintry? {
        let isLikely = (hour.precipitationProbability ?? 1) >= rainPossible
        switch hour.precipitationType {
        case .snow where isLikely: return .snow
        case .ice where isLikely, .mixed where isLikely: return .sleet
        default: break
        }
        switch hour.condition.number ?? 0 {
        case 313, 404...406, 456: return .sleet
        case 400...499: return .snow
        default: return nil
        }
    }

    private static func precipitationTip(_ hours: [HourlyWeather], calendar: Calendar) -> String? {
        let wintryKinds = hours.compactMap(wintry)
        if wintryKinds.contains(.sleet) { return "可能有雨夹雪或冻雨，穿防滑的鞋、带伞" }
        if wintryKinds.contains(.snow) { return "可能下雪，穿防滑的鞋" }

        guard let peak = hours.compactMap(\.precipitationProbability).max() else {
            let isRainy = hours.contains { (300...399).contains($0.condition.number ?? 0) }
            return isRainy ? "可能下雨，记得带伞" : nil
        }
        let threshold = peak >= rainLikely ? rainLikely : rainPossible
        guard peak >= rainPossible,
              let first = hours.first(where: { ($0.precipitationProbability ?? 0) >= threshold })
        else { return nil }
        let when = period(of: first.time, calendar: calendar)
        let percent = Int((peak * 100).rounded())
        return peak >= rainLikely ? "\(when)降水概率 \(percent)%，记得带伞" : "\(when)可能有雨（\(percent)%），带把折叠伞"
    }

    private static func period(of date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case ..<12: "上午"
        case ..<14: "中午"
        case ..<18: "下午"
        default: "傍晚"
        }
    }

    private static func windTip(_ hours: [HourlyWeather], level: OutfitLevel) -> String? {
        guard let scale = hours.compactMap(\.windScale).max(), scale >= strongWindScale else { return nil }
        return level >= .warm ? "风大（\(scale) 级），出门留意" : "风大（\(scale) 级），外套选防风的"
    }

    private static func sunTip(_ hours: [HourlyWeather], daily: DailyWeather?) -> String? {
        guard let uv = hours.compactMap(\.uvIndex).max() ?? daily?.uvIndexMax, uv >= strongUVIndex else { return nil }
        return "紫外线强，记得防晒"
    }

    private static func mostCommonCondition(_ hours: [HourlyWeather]) -> String {
        let counts = Dictionary(hours.map { ($0.condition.text, 1) }, uniquingKeysWith: +)
        return hours.map(\.condition.text).max { counts[$0, default: 0] < counts[$1, default: 0] } ?? ""
    }
}
