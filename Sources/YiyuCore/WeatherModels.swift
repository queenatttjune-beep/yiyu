import Foundation

/// A place picked from 和风天气's city search.
public struct WeatherCity: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let adm1: String
    public let adm2: String
    public let country: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneID: String

    public init(
        id: String, name: String, adm1: String, adm2: String, country: String,
        latitude: Double, longitude: Double, timeZoneID: String
    ) {
        self.id = id
        self.name = name
        self.adm1 = adm1
        self.adm2 = adm2
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneID = timeZoneID
    }

    /// The areas above the place, e.g. "浙江省" for 杭州: its own name and 中国 are left out,
    /// and "北京" / "北京市" count as one.
    public var region: String {
        func base(_ name: String) -> String { name.hasSuffix("市") ? String(name.dropLast()) : name }
        var seen: Set<String> = [base(name)]
        let parts = [adm2, adm1, country == "中国" ? "" : country].filter { part in
            !part.isEmpty && seen.insert(base(part)).inserted
        }
        return parts.joined(separator: " · ")
    }

    /// `base` moved to the city's time zone, so "today" and "8 a.m." mean the city's.
    public func calendar(basedOn base: Calendar) -> Calendar {
        guard let zone = TimeZone(identifier: timeZoneID) else { return base }
        var calendar = base
        calendar.timeZone = zone
        return calendar
    }
}

/// 和风天气's weather code ("101") and its Chinese text ("多云").
public struct WeatherCondition: Codable, Equatable, Sendable {
    public let code: String
    public let text: String

    public init(code: String, text: String) {
        self.code = code
        self.text = text
    }

    var number: Int? { Int(code) }
}

public enum PrecipitationType: String, Codable, Sendable {
    case rain, snow, ice, mixed, none, unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PrecipitationType(rawValue: raw) ?? .unknown
    }
}

public struct CurrentWeather: Codable, Equatable, Sendable {
    public let temperature: Double
    public let feelsLike: Double
    /// 0...1
    public let humidity: Double?
    /// Beaufort scale.
    public let windScale: Int?
    public let condition: WeatherCondition

    public init(temperature: Double, feelsLike: Double, humidity: Double?, windScale: Int?, condition: WeatherCondition) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.windScale = windScale
        self.condition = condition
    }
}

public struct HourlyWeather: Codable, Equatable, Sendable {
    /// Start of the hour.
    public let time: Date
    public let temperature: Double
    public let feelsLike: Double
    public let condition: WeatherCondition
    /// 0...1
    public let precipitationProbability: Double?
    public let precipitationType: PrecipitationType
    public let windScale: Int?
    public let uvIndex: Double?

    public init(
        time: Date, temperature: Double, feelsLike: Double, condition: WeatherCondition,
        precipitationProbability: Double?, precipitationType: PrecipitationType, windScale: Int?, uvIndex: Double?
    ) {
        self.time = time
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.condition = condition
        self.precipitationProbability = precipitationProbability
        self.precipitationType = precipitationType
        self.windScale = windScale
        self.uvIndex = uvIndex
    }
}

public struct DailyWeather: Codable, Equatable, Sendable {
    public let start: Date
    /// Exclusive.
    public let end: Date
    public let temperatureMax: Double
    public let temperatureMin: Double
    public let uvIndexMax: Double?
    /// The weather from 7:00 to 19:00.
    public let daytime: WeatherCondition?
    /// 0...1, for the daytime.
    public let precipitationProbability: Double?

    public init(
        start: Date, end: Date, temperatureMax: Double, temperatureMin: Double, uvIndexMax: Double?,
        daytime: WeatherCondition?, precipitationProbability: Double?
    ) {
        self.start = start
        self.end = end
        self.temperatureMax = temperatureMax
        self.temperatureMin = temperatureMin
        self.uvIndexMax = uvIndexMax
        self.daytime = daytime
        self.precipitationProbability = precipitationProbability
    }
}

/// Everything fetched in one refresh, kept so the panel still has weather to show offline.
public struct WeatherSnapshot: Codable, Equatable, Sendable {
    /// A forecast older than this may be wrong, so the panel greys it out.
    public static let staleAfter: TimeInterval = 6 * 3600

    public let cityID: String
    public let fetchedAt: Date
    public let current: CurrentWeather
    public let hours: [HourlyWeather]
    public let days: [DailyWeather]

    public init(cityID: String, fetchedAt: Date, current: CurrentWeather, hours: [HourlyWeather], days: [DailyWeather]) {
        self.cityID = cityID
        self.fetchedAt = fetchedAt
        self.current = current
        self.hours = hours
        self.days = days
    }

    public func day(containing date: Date) -> DailyWeather? {
        days.first { $0.start <= date && date < $0.end }
    }

    public func isStale(now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) >= Self.staleAfter
    }

    public func ageLabel(now: Date) -> String {
        let minutes = Int(max(0, now.timeIntervalSince(fetchedAt)) / 60)
        switch minutes {
        case ..<2: return "刚刚更新"
        case ..<60: return "\(minutes) 分钟前更新"
        case ..<(24 * 60): return "\(minutes / 60) 小时前更新"
        default: return "\(minutes / (24 * 60)) 天前更新"
        }
    }
}
