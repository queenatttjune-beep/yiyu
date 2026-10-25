import Foundation
@testable import YiyuCore

/// Forecast building blocks for the weather tests, on the Shanghai calendar of `Fixtures`.
enum WeatherSamples {
    static let hangzhou = WeatherCity(
        id: "101210101", name: "杭州", adm1: "浙江省", adm2: "杭州", country: "中国",
        latitude: 30.29365, longitude: 120.16142, timeZoneID: "Asia/Shanghai"
    )

    static func hour(
        _ date: Date,
        feelsLike: Double,
        code: String = "101",
        text: String = "多云",
        pop: Double? = 0.1,
        type: PrecipitationType = .none,
        wind: Int? = 2,
        uv: Double? = 2
    ) -> HourlyWeather {
        HourlyWeather(
            time: date, temperature: feelsLike, feelsLike: feelsLike,
            condition: WeatherCondition(code: code, text: text),
            precipitationProbability: pop, precipitationType: type, windScale: wind, uvIndex: uv
        )
    }

    /// One entry per hour of `day` from `first` through `last`, built by `make`.
    static func hours(
        on day: DayKey, from first: Int, through last: Int,
        _ make: (Date, Int) -> HourlyWeather
    ) -> [HourlyWeather] {
        (first...last).map { hour in
            make(Fixtures.date(day.year, day.month, day.day, hour), hour)
        }
    }

    /// Sunrise and sunset are hours of `day`, e.g. 6.1 for 6:06.
    static func day(
        _ day: DayKey, min: Double, max: Double, text: String = "多云", uv: Double? = 4,
        sunrise: Double? = nil, sunset: Double? = nil
    ) -> DailyWeather {
        let start = day.startOfDay(in: Fixtures.calendar)
        let end = day.adding(days: 1, calendar: Fixtures.calendar).startOfDay(in: Fixtures.calendar)
        return DailyWeather(
            start: start, end: end, temperatureMax: max, temperatureMin: min, uvIndexMax: uv,
            daytime: WeatherCondition(code: "101", text: text), precipitationProbability: nil,
            sunrise: sunrise.map { start.addingTimeInterval($0 * 3600) },
            sunset: sunset.map { start.addingTimeInterval($0 * 3600) }
        )
    }

    static func snapshot(
        hours: [HourlyWeather], days: [DailyWeather], fetchedAt: Date = Fixtures.now, cityID: String = hangzhou.id
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            cityID: cityID, fetchedAt: fetchedAt,
            current: CurrentWeather(
                temperature: 19.6, feelsLike: 20.9, humidity: 0.76, windScale: 3,
                condition: WeatherCondition(code: "101", text: "多云")
            ),
            hours: hours, days: days
        )
    }
}
