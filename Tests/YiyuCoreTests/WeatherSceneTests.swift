import Foundation
import Testing
@testable import YiyuCore

struct WeatherSceneTests {
    @Test func aClearDayIsFullSunshine() {
        let scene = WeatherScene(code: "100")
        #expect(scene.sky == .sun(.strong))
        #expect(scene.rain == nil && scene.snow == nil && scene.mist == nil)
        #expect(scene.motif == .sun)
    }

    @Test(arguments: ["102", "103"])
    func aFewCloudsLeaveSoftSunshine(code: String) {
        #expect(WeatherScene(code: code) == WeatherScene(sky: .sun(.faint)))
    }

    /// The v1 API sends daytime codes at night; the scene is told it is night instead.
    @Test func clearSkiesAtNightHaveTheMoon() {
        #expect(WeatherScene(code: "100", atNight: true) == WeatherScene(sky: .moon(.strong)))
        #expect(WeatherScene(code: "103", atNight: true) == WeatherScene(sky: .moon(.faint)))
        #expect(WeatherScene(code: "305", atNight: true) == WeatherScene(code: "305"))
        #expect(WeatherScene(code: "101", atNight: true) == .calm)
    }

    @Test func aClearNightHasTheMoon() {
        #expect(WeatherScene(code: "150") == WeatherScene(sky: .moon(.strong)))
        #expect(WeatherScene(code: "152") == WeatherScene(sky: .moon(.faint)))
        #expect(WeatherScene(code: "150").motif == .moon)
    }

    @Test(arguments: ["101", "104", "151", "900", "901", "999", "", "abc"])
    func cloudsAndUnknownCodesLeaveThePanelAsItIs(code: String) {
        let scene = WeatherScene(code: code)
        #expect(scene == .calm)
        #expect(scene.isCalm)
        #expect(scene.motif == .blossom)
    }

    /// 小雨 and 毛毛雨 are the misty drizzle: fine rain with a veil of mist.
    @Test(arguments: ["305", "309"])
    func lightRainIsAMistyDrizzle(code: String) {
        let scene = WeatherScene(code: code)
        #expect(scene == WeatherScene(rain: .faint, mist: .faint))
        #expect(scene.motif == .rain)
    }

    @Test(arguments: [
        ("300", WeatherScene.Strength.medium), ("350", .medium), ("306", .medium), ("314", .medium),
        ("399", .medium), ("302", .medium), ("313", .medium),
        ("301", .strong), ("351", .strong), ("303", .strong), ("304", .strong), ("307", .strong),
        ("308", .strong), ("310", .strong), ("312", .strong), ("315", .strong), ("318", .strong),
    ])
    func heavierRainFallsHarder(code: String, strength: WeatherScene.Strength) {
        #expect(WeatherScene(code: code) == WeatherScene(rain: strength))
    }

    @Test(arguments: [
        ("400", WeatherScene.Strength.faint), ("407", .faint), ("457", .faint),
        ("401", .medium), ("408", .medium), ("499", .medium),
        ("402", .strong), ("403", .strong), ("409", .strong), ("410", .strong),
    ])
    func snowFallsAsFlakes(code: String, strength: WeatherScene.Strength) {
        let scene = WeatherScene(code: code)
        #expect(scene == WeatherScene(snow: strength))
        #expect(scene.motif == .snow)
    }

    @Test(arguments: ["404", "405", "406", "456"])
    func sleetIsRainAndSnowTogether(code: String) {
        let scene = WeatherScene(code: code)
        #expect(scene == WeatherScene(rain: .faint, snow: .faint))
        #expect(scene.motif == .rain)
    }

    @Test(arguments: [
        ("500", WeatherScene.Strength.faint), ("503", .faint), ("504", .faint),
        ("501", .medium), ("502", .medium), ("511", .medium), ("507", .medium), ("508", .medium),
        ("509", .strong), ("510", .strong), ("512", .strong), ("513", .strong), ("514", .strong), ("515", .strong),
    ])
    func fogAndHazeDriftAsMist(code: String, strength: WeatherScene.Strength) {
        let scene = WeatherScene(code: code)
        #expect(scene == WeatherScene(mist: strength))
        #expect(scene.motif == .mist)
    }

    @Test func strengthsAreOrdered() {
        #expect(WeatherScene.Strength.faint < .medium)
        #expect(WeatherScene.Strength.medium < .strong)
    }
}

struct WeatherSceneNowTests {
    private func snapshot(
        fetched minutesAgo: Double, current code: String, hours: [HourlyWeather] = [], at now: Date = Fixtures.now,
        days: [DailyWeather] = []
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            cityID: WeatherSamples.hangzhou.id,
            fetchedAt: now.addingTimeInterval(-minutesAgo * 60),
            current: CurrentWeather(
                temperature: 19, feelsLike: 19, humidity: nil, windScale: nil,
                condition: WeatherCondition(code: code, text: "")
            ),
            hours: hours, days: days
        )
    }

    @Test func aClearSkyAfterSunsetIsMoonlit() {
        let today = [WeatherSamples.day(Fixtures.today, min: 15, max: 22, sunrise: 6.1, sunset: 17.4)]
        let evening = Fixtures.date(2026, 10, 25, 22)
        #expect(WeatherScene.now(in: snapshot(fetched: 10, current: "100", at: evening, days: today), at: evening)
            == WeatherScene(sky: .moon(.strong)))
        #expect(WeatherScene.now(in: snapshot(fetched: 10, current: "100", days: today), at: Fixtures.now)
            == WeatherScene(sky: .sun(.strong)))
    }

    @Test func thisHoursForecastAfterSunsetIsMoonlitToo() {
        let today = [WeatherSamples.day(Fixtures.today, min: 15, max: 22, sunrise: 6.1, sunset: 17.4)]
        let evening = Fixtures.date(2026, 10, 25, 21, 20)
        let older = snapshot(fetched: 150, current: "305", hours: [hour(21, code: "102")], at: evening, days: today)
        #expect(WeatherScene.now(in: older, at: evening) == WeatherScene(sky: .moon(.faint)))
    }

    private func hour(_ hour: Int, code: String) -> HourlyWeather {
        WeatherSamples.hour(Fixtures.date(2026, 10, 25, hour), feelsLike: 19, code: code)
    }

    @Test func withoutAForecastThePanelStaysCalm() {
        #expect(WeatherScene.now(in: nil, at: Fixtures.now) == .calm)
    }

    @Test func aFreshForecastShowsTheWeatherNow() {
        let fresh = snapshot(fetched: 20, current: "305", hours: [hour(10, code: "100")])
        #expect(WeatherScene.now(in: fresh, at: Fixtures.now) == WeatherScene(code: "305"))
    }

    /// When refreshing keeps failing, the hourly forecast says what the sky is doing by now.
    @Test func anOlderForecastFallsBackToThisHour() {
        let older = snapshot(fetched: 150, current: "100", hours: [hour(9, code: "101"), hour(10, code: "307"), hour(11, code: "100")])
        #expect(WeatherScene.now(in: older, at: Fixtures.now.addingTimeInterval(25 * 60)) == WeatherScene(code: "307"))
    }

    @Test func anOlderForecastWithoutThisHourStaysCalm() {
        let older = snapshot(fetched: 150, current: "305", hours: [hour(8, code: "305")])
        #expect(WeatherScene.now(in: older, at: Fixtures.now) == .calm)
    }

    /// A forecast the header greys out as out of date is not painted on the panel either.
    @Test func aStaleForecastIsNotPainted() {
        let stale = snapshot(fetched: 7 * 60, current: "305", hours: [hour(10, code: "305")])
        #expect(WeatherScene.now(in: stale, at: Fixtures.now) == .calm)
    }
}
