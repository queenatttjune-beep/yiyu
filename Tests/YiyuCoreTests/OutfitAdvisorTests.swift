import Foundation
import Testing
@testable import YiyuCore

struct OutfitAdvisorTests {
    private let today = Fixtures.today
    private let tomorrow = Fixtures.day(2026, 10, 26)

    private func advice(
        _ hours: [HourlyWeather], days: [DailyWeather], at now: Date
    ) -> OutfitAdvice? {
        OutfitAdvisor.advice(for: WeatherSamples.snapshot(hours: hours, days: days), now: now, calendar: Fixtures.calendar)
    }

    /// A whole day of even weather at `feelsLike`, with `tweak` applied to each hour.
    private func evenDay(
        _ day: DayKey, feelsLike: Double, tweak: (Int) -> (pop: Double?, type: PrecipitationType, code: String, wind: Int?, uv: Double?) = { _ in
            (0.1, .none, "101", 2, 2)
        }
    ) -> [HourlyWeather] {
        WeatherSamples.hours(on: day, from: 0, through: 23) { date, hour in
            let change = tweak(hour)
            return WeatherSamples.hour(
                date, feelsLike: feelsLike, code: change.code, pop: change.pop, type: change.type,
                wind: change.wind, uv: change.uv
            )
        }
    }

    private static let bands: [(Double, OutfitLevel)] = [
        (30, .hot), (28, .hot), (27.9, .warm), (24, .warm), (23, .comfortable),
        (20, .comfortable), (19.9, .mild), (15, .mild), (12, .cool), (10, .cool), (7, .cold),
        (5, .cold), (4.9, .freezing), (-3, .freezing),
    ]

    @Test(arguments: bands)
    func levelsFollowTheFeelsLikeBands(feelsLike: Double, level: OutfitLevel) {
        #expect(OutfitLevel(feelsLike: feelsLike) == level)
    }

    @Test func mildRainyDayAdvisesLongSleevesAJacketAndAnUmbrella() throws {
        let hours = evenDay(today, feelsLike: 21) { hour in
            (hour >= 14 ? 0.55 : 0.1, hour >= 14 ? .rain : .none, "101", 2, 3)
        }
        let result = try #require(advice(
            hours, days: [WeatherSamples.day(today, min: 16.8, max: 24.3, text: "小雨")],
            at: Fixtures.date(2026, 10, 25, 7, 30)
        ))

        #expect(result.isToday)
        #expect(result.dayKey == today)
        #expect(result.level == .comfortable)
        #expect(result.title == "今日穿衣 · 舒适")
        #expect(result.headline == "今天 17–24° · 小雨")
        #expect(result.summary == "长袖衬衫或 T 恤；早晚只有 17°，带件薄外套；下午降水概率 55%，记得带伞。")
    }

    @Test func averagesOnlyTheDaytimeHoursStillAhead() throws {
        let hours = WeatherSamples.hours(on: today, from: 0, through: 23) { date, hour in
            WeatherSamples.hour(date, feelsLike: hour < 15 || hour >= 20 ? 30 : 18)
        }
        let result = try #require(advice(
            hours, days: [WeatherSamples.day(today, min: 16, max: 21)], at: Fixtures.date(2026, 10, 25, 15, 20)
        ))

        #expect(result.level == .mild)
        #expect(result.isToday)
    }

    @Test func eveningAdviceIsForTomorrow() throws {
        let hours = evenDay(today, feelsLike: 20) + evenDay(tomorrow, feelsLike: 8)
        let result = try #require(advice(
            hours,
            days: [WeatherSamples.day(today, min: 15, max: 22), WeatherSamples.day(tomorrow, min: 5, max: 10, text: "阴")],
            at: Fixtures.date(2026, 10, 25, 18, 30)
        ))

        #expect(!result.isToday)
        #expect(result.dayKey == tomorrow)
        #expect(result.title == "明日穿衣 · 冷")
        #expect(result.headline == "明天 5–10° · 阴")
        #expect(result.summary == "毛衣加厚外套。")
    }

    @Test func noForecastForTheDaytimeGivesNoAdvice() {
        let yesterday = Fixtures.day(2026, 10, 24)
        #expect(advice(evenDay(yesterday, feelsLike: 20), days: [], at: Fixtures.now) == nil)
    }

    @Test func withoutADailyForecastTheRangeComesFromTheHours() throws {
        let hours = WeatherSamples.hours(on: today, from: 8, through: 19) { date, hour in
            WeatherSamples.hour(date, feelsLike: Double(hour + 6))
        }
        let result = try #require(advice(hours, days: [], at: Fixtures.date(2026, 10, 25, 6)))

        #expect(result.temperatureMin == 14)
        #expect(result.temperatureMax == 25)
        #expect(result.headline == "今天 14–25° · 多云")
    }

    @Test func aWideSwingOnACoolDaySuggestsLayers() throws {
        let result = try #require(advice(
            evenDay(today, feelsLike: 12), days: [WeatherSamples.day(today, min: 6, max: 16)], at: Fixtures.now
        ))
        #expect(result.tips == ["早晚温差 10°，里面穿薄些，方便增减"])
    }

    @Test func aSmallSwingAddsNoTip() throws {
        let result = try #require(advice(
            evenDay(today, feelsLike: 25), days: [WeatherSamples.day(today, min: 20, max: 26)], at: Fixtures.now
        ))
        #expect(result.tips.isEmpty)
        #expect(result.summary == "短袖加薄长裤。")
    }

    @Test func possibleRainSuggestsAFoldingUmbrella() throws {
        let hours = evenDay(today, feelsLike: 22) { hour in
            (hour == 11 ? 0.35 : 0.05, hour == 11 ? .rain : .none, "101", 2, 2)
        }
        let result = try #require(advice(hours, days: [WeatherSamples.day(today, min: 19, max: 24)], at: Fixtures.now))
        #expect(result.tips == ["上午可能有雨（35%），带把折叠伞"])
    }

    @Test func rainyCodesWithoutAProbabilityStillMentionAnUmbrella() throws {
        let hours = evenDay(today, feelsLike: 22) { hour in
            (nil, .unknown, hour == 16 ? "306" : "104", 2, 2)
        }
        let result = try #require(advice(hours, days: [WeatherSamples.day(today, min: 19, max: 24)], at: Fixtures.now))
        #expect(result.tips == ["可能下雨，记得带伞"])
    }

    @Test func snowReplacesTheUmbrellaTip() throws {
        let hours = evenDay(today, feelsLike: -2) { hour in
            (hour >= 12 ? 0.7 : 0.2, hour >= 12 ? .snow : .none, hour >= 12 ? "400" : "104", 2, 1)
        }
        let result = try #require(advice(hours, days: [WeatherSamples.day(today, min: -4, max: 1)], at: Fixtures.now))
        #expect(result.tips == ["可能下雪，穿防滑的鞋"])
        #expect(result.summary == "羽绒服，戴上帽子、手套和围巾；可能下雪，穿防滑的鞋。")
    }

    @Test func sleetAsksForGoodShoesAndAnUmbrella() throws {
        let hours = evenDay(today, feelsLike: 3) { hour in
            (0.6, hour == 13 ? .mixed : .rain, hour == 13 ? "404" : "305", 2, 1)
        }
        let result = try #require(advice(hours, days: [WeatherSamples.day(today, min: 1, max: 5)], at: Fixtures.now))
        #expect(result.tips == ["可能有雨夹雪或冻雨，穿防滑的鞋、带伞"])
    }

    @Test func strongWindAndSunAreMentionedLast() throws {
        let hours = evenDay(today, feelsLike: 17) { hour in
            (0.0, .none, "100", hour == 13 ? 6 : 3, hour == 12 ? 7 : 3)
        }
        let result = try #require(advice(hours, days: [WeatherSamples.day(today, min: 13, max: 19)], at: Fixtures.now))
        #expect(result.tips == ["风大（6 级），外套选防风的", "紫外线强，记得防晒"])
    }

    @Test func windOnAHotDayNeedsNoJacket() throws {
        let hours = evenDay(today, feelsLike: 31) { _ in (0.0, .none, "100", 5, 4) }
        let result = try #require(advice(hours, days: [WeatherSamples.day(today, min: 27, max: 33)], at: Fixtures.now))
        #expect(result.tips == ["风大（5 级），出门留意"])
    }
}
