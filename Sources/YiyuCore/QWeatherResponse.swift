import Foundation

/// Why a 和风天气 request failed, in words the panel can show.
public enum QWeatherError: Error, Equatable, Sendable {
    case unauthorized
    case noCredit
    case badHost
    case rejected(String)
    case noSuchLocation
    case tooManyRequests
    case overMonthlyLimit
    case server(Int)
    /// An HTTP error without 和风天气's error body, e.g. from a proxy or a captive portal.
    case unexpected(Int)
    case unreadable

    public var userMessage: String {
        switch self {
        case .unauthorized: "和风天气没认出这个 API KEY，请检查密钥和 API Host 是不是同一个账号的"
        case .noCredit: "和风天气账户的额度不够，或者有没付的账单"
        case .badHost: "API Host 好像不对，请到和风天气控制台的「设置」里复制"
        case .rejected(let reason): reason.isEmpty ? "和风天气拒绝了请求" : "和风天气拒绝了请求：\(reason)"
        case .noSuchLocation: "和风天气查不到这个地点的天气"
        case .tooManyRequests: "请求太频繁了，稍后会自动再试"
        case .overMonthlyLimit: "和风天气这个月的请求额度用完了，下个月或调整套餐后会恢复"
        case .server(let status): "和风天气暂时出错了（\(status)），稍后会自动再试"
        case .unexpected(let status): "和风天气返回了意外的结果（\(status)），稍后会自动再试"
        case .unreadable: "和风天气返回的数据读不懂，稍后会自动再试"
        }
    }

    /// Whether waiting can help. A wrong key, host or account needs the settings changed first,
    /// and 和风天气 may freeze accounts that keep sending failing requests.
    public var isRetryable: Bool {
        switch self {
        case .tooManyRequests, .server, .unexpected, .unreadable: true
        case .unauthorized, .noCredit, .badHost, .rejected, .noSuchLocation, .overMonthlyLimit: false
        }
    }
}

/// Reads 和风天气 responses: the v1 weather APIs (`/weather/v1/...`) and the GeoAPI city lookup.
public enum QWeatherResponse {
    public static func current(from data: Data) throws -> CurrentWeather {
        let raw: RawCurrent = try decode(data)
        return CurrentWeather(
            temperature: raw.temperature.value, feelsLike: raw.feelsLike.value, humidity: raw.humidity,
            windScale: raw.wind?.scale, condition: raw.condition
        )
    }

    public static func hours(from data: Data) throws -> [HourlyWeather] {
        let raw: RawHourly = try decode(data)
        return try raw.hours.map { hour in
            HourlyWeather(
                time: try date(hour.forecastTime), temperature: hour.temperature.value, feelsLike: hour.feelsLike.value,
                condition: hour.condition, precipitationProbability: hour.precipitation?.probability,
                precipitationType: hour.precipitation?.type ?? .unknown, windScale: hour.wind?.scale, uvIndex: hour.uvIndex
            )
        }
    }

    public static func days(from data: Data) throws -> [DailyWeather] {
        let raw: RawDaily = try decode(data)
        return try raw.days.map { day in
            DailyWeather(
                start: try date(day.forecastStartTime), end: try date(day.forecastEndTime),
                temperatureMax: day.temperatureMax.value, temperatureMin: day.temperatureMin.value,
                uvIndexMax: day.uvIndexMax, daytime: day.daytime?.condition,
                precipitationProbability: day.daytime?.precipitation?.probability,
                sunrise: day.astro?.sunrise.flatMap(QWeatherDate.parse),
                sunset: day.astro?.sunset.flatMap(QWeatherDate.parse)
            )
        }
    }

    /// No match ("204", or "404" for an unknown place) is an empty list, not an error.
    public static func cities(from data: Data) throws -> [WeatherCity] {
        let raw: RawLookup = try decode(data)
        switch raw.code {
        case "200": break
        case "204", "404": return []
        default: throw legacyError(code: raw.code) ?? .unreadable
        }
        return (raw.location ?? []).compactMap { place in
            guard let latitude = Double(place.lat), let longitude = Double(place.lon) else { return nil }
            return WeatherCity(
                id: place.id, name: place.name, adm1: place.adm1 ?? "", adm2: place.adm2 ?? "",
                country: place.country ?? "", latitude: latitude, longitude: longitude, timeZoneID: place.tz ?? ""
            )
        }
    }

    /// The error for a response whose HTTP status is not 2xx: the v1 `application/problem+json`
    /// body, the GeoAPI's `code`, or failing both, the status alone. Only 和风天气's own error
    /// body counts as a lasting problem: a proxy or captive portal can answer 401 or 403 too.
    public static func error(status: Int, body: Data) -> QWeatherError {
        if let problem = try? JSONDecoder().decode(RawProblem.self, from: body) {
            return classify(status: problem.error.status ?? status, title: problem.error.title ?? "")
        }
        if let legacy = try? JSONDecoder().decode(RawCode.self, from: body), let error = legacyError(code: legacy.code) {
            return error
        }
        switch status {
        case 429: return .tooManyRequests
        case 500...: return .server(status)
        default: return .unexpected(status)
        }
    }

    private static func classify(status: Int, title: String) -> QWeatherError {
        let lowered = title.lowercased()
        switch status {
        case 401: return .unauthorized
        case 403 where lowered.contains("credit") || lowered.contains("overdue"): return .noCredit
        case 403 where lowered.contains("host"): return .badHost
        case 403: return .rejected(title)
        case 400 where lowered.contains("location"): return .noSuchLocation
        case 400: return .rejected(title)
        case 404: return .badHost
        case 429 where lowered.contains("monthly"): return .overMonthlyLimit
        case 429: return .tooManyRequests
        case 500...: return .server(status)
        default: return .unexpected(status)
        }
    }

    private static func legacyError(code: String) -> QWeatherError? {
        switch code {
        case "401": .unauthorized
        case "402": .noCredit
        case "403": .rejected("没有访问这项数据的权限")
        case "404": .noSuchLocation
        case "429": .tooManyRequests
        default: Int(code).flatMap { $0 >= 500 ? .server($0) : nil }
        }
    }

    private static func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw QWeatherError.unreadable
        }
    }

    private static func date(_ text: String) throws -> Date {
        guard let date = QWeatherDate.parse(text) else { throw QWeatherError.unreadable }
        return date
    }
}

// MARK: - Wire format

private struct Measure: Decodable {
    let value: Double
}

private struct RawWind: Decodable {
    let scale: Int?
}

private struct RawPrecipitation: Decodable {
    let probability: Double?
    let type: PrecipitationType?
}

private struct RawCurrent: Decodable {
    let condition: WeatherCondition
    let temperature: Measure
    let feelsLike: Measure
    let humidity: Double?
    let wind: RawWind?
}

private struct RawHourly: Decodable {
    struct Hour: Decodable {
        let forecastTime: String
        let condition: WeatherCondition
        let temperature: Measure
        let feelsLike: Measure
        let wind: RawWind?
        let precipitation: RawPrecipitation?
        let uvIndex: Double?
    }

    let hours: [Hour]
}

private struct RawDaily: Decodable {
    struct Period: Decodable {
        let condition: WeatherCondition?
        let precipitation: RawPrecipitation?
    }

    struct Astro: Decodable {
        let sunrise: String?
        let sunset: String?
    }

    struct Day: Decodable {
        let forecastStartTime: String
        let forecastEndTime: String
        let astro: Astro?
        let temperatureMax: Measure
        let temperatureMin: Measure
        let uvIndexMax: Double?
        let daytime: Period?
    }

    let days: [Day]
}

private struct RawLookup: Decodable {
    struct Place: Decodable {
        let name: String
        let id: String
        let lat: String
        let lon: String
        let adm2: String?
        let adm1: String?
        let country: String?
        let tz: String?
    }

    let code: String
    let location: [Place]?
}

private struct RawCode: Decodable {
    let code: String
}

private struct RawProblem: Decodable {
    struct Detail: Decodable {
        let status: Int?
        let title: String?
    }

    let error: Detail
}
