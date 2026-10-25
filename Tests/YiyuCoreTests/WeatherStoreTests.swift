import AppKit
import Foundation
import Testing
@testable import YiyuCore

struct WeatherStoreTests {
    private func makeStore() -> WeatherStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("yiyu-weather-\(UUID().uuidString)", isDirectory: true)
        return WeatherStore(directory: directory)
    }

    private func write(_ text: String, to store: WeatherStore) throws {
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: store.fileURL)
    }

    @Test func missingFileLoadsAnEmptyState() throws {
        let result = try makeStore().load()
        #expect(result.state == .empty)
        #expect(result.outcome == .fresh)
        #expect(result.state.settings.briefing == .default)
    }

    @Test func savesAndLoadsSettingsAndTheLastForecast() throws {
        let store = makeStore()
        let today = Fixtures.today
        let snapshot = WeatherSamples.snapshot(
            hours: [WeatherSamples.hour(Fixtures.now, feelsLike: 20, pop: nil, type: .rain, uv: nil)],
            days: [WeatherSamples.day(today, min: 15, max: 22)]
        )
        let state = WeatherState.empty
            .with(settings: WeatherSettings(
                apiHost: "abcxyz.qweatherapi.com", city: WeatherSamples.hangzhou,
                briefing: BriefingSchedule(isEnabled: false, hour: 6, minute: 45)
            ))
            .with(snapshot: snapshot)
            .with(lastBriefingDay: today)
            .with(hiddenAdvice: AdviceDismissal(day: today, wasToday: true))

        try store.save(state)
        let result = try store.load()

        #expect(result.state == state)
        #expect(result.outcome == .loaded)
    }

    @Test func unreadableFileIsSetAside() throws {
        let store = makeStore()
        try write("{ nope", to: store)

        let result = try store.load()

        #expect(result.state == .empty)
        guard case .recovered(let backupURL) = result.outcome else {
            Issue.record("Expected recovered outcome, got \(result.outcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
    }

    @Test func missingFieldsFallBackToDefaults() throws {
        let store = makeStore()
        try write(#"{"settings": {"apiHost": "abcxyz.qweatherapi.com"}}"#, to: store)

        let state = try store.load().state

        #expect(state.settings.apiHost == "abcxyz.qweatherapi.com")
        #expect(state.settings.city == nil)
        #expect(state.settings.briefing == .default)
        #expect(state.settings.showsScene)
        #expect(state.snapshot == nil)
    }

    @Test func turningTheWeatherSceneOffIsSaved() throws {
        let store = makeStore()
        let settings = WeatherSettings(apiHost: "h", city: WeatherSamples.hangzhou, briefing: .default, showsScene: false)
        try store.save(WeatherState.empty.with(settings: settings))
        #expect(try store.load().state.settings.showsScene == false)
        #expect(WeatherSettings.default.showsScene)
    }

    @Test func aForecastForAnotherCityIsNotUsed() {
        let state = WeatherState.empty
            .with(settings: WeatherSettings(apiHost: "h", city: WeatherSamples.hangzhou, briefing: .default))
            .with(snapshot: WeatherSamples.snapshot(hours: [], days: [], cityID: "101010100"))
        #expect(state.currentSnapshot == nil)
        #expect(state.with(snapshot: WeatherSamples.snapshot(hours: [], days: [])).currentSnapshot != nil)
    }
}

struct AdviceDismissalTests {
    private func advice(day: DayKey, isToday: Bool) -> OutfitAdvice {
        OutfitAdvice(
            dayKey: day, isToday: isToday, level: .mild, tips: [], temperatureMin: 15, temperatureMax: 20, conditionText: "多云"
        )
    }

    @Test func closingTodaysCardHidesItForTheDay() {
        let state = WeatherState.empty.with(hiddenAdvice: AdviceDismissal(day: Fixtures.today, wasToday: true))
        #expect(state.isHidden(advice(day: Fixtures.today, isToday: true)))
        #expect(!state.isHidden(advice(day: Fixtures.day(2026, 10, 26), isToday: false)))
    }

    /// Put away in the evening, tomorrow's card must still be there the next morning as 今日穿衣.
    @Test func closingTomorrowsCardInTheEveningKeepsItForTheMorning() {
        let tomorrow = Fixtures.day(2026, 10, 26)
        let state = WeatherState.empty.with(hiddenAdvice: AdviceDismissal(day: tomorrow, wasToday: false))
        #expect(state.isHidden(advice(day: tomorrow, isToday: false)))
        #expect(!state.isHidden(advice(day: tomorrow, isToday: true)))
    }
}

struct WeatherCityTests {
    @Test func regionSkipsTheCityItselfAndChina() {
        #expect(WeatherSamples.hangzhou.region == "浙江省")
        let dongcheng = WeatherCity(
            id: "101011600", name: "东城", adm1: "北京市", adm2: "北京", country: "中国",
            latitude: 39.9, longitude: 116.4, timeZoneID: "Asia/Shanghai"
        )
        #expect(dongcheng.region == "北京")
        let tokyo = WeatherCity(
            id: "1", name: "东京", adm1: "东京都", adm2: "东京", country: "日本",
            latitude: 35.7, longitude: 139.7, timeZoneID: "Asia/Tokyo"
        )
        #expect(tokyo.region == "东京都 · 日本")
    }

    @Test func calendarRunsOnTheCitysTimeZone() {
        let tokyo = WeatherCity(
            id: "1", name: "东京", adm1: "东京都", adm2: "东京", country: "日本",
            latitude: 35.7, longitude: 139.7, timeZoneID: "Asia/Tokyo"
        )
        #expect(tokyo.calendar(basedOn: Fixtures.calendar).timeZone.identifier == "Asia/Tokyo")
        let nowhere = WeatherCity(
            id: "2", name: "某地", adm1: "", adm2: "", country: "", latitude: 0, longitude: 0, timeZoneID: "Mars/Base"
        )
        #expect(nowhere.calendar(basedOn: Fixtures.calendar).timeZone.identifier == "Asia/Shanghai")
    }
}

struct WeatherConditionTests {
    @Test(arguments: [
        ("100", "150"), ("101", "151"), ("102", "152"), ("103", "153"), ("300", "350"), ("301", "351"),
        ("406", "456"), ("407", "457"), ("150", "150"), ("305", "305"), ("104", "104"), ("abc", "abc"),
    ])
    func daytimeCodesHaveNightVersions(day: String, night: String) {
        #expect(WeatherCondition.nightCode(for: day) == night)
    }
}

struct WeatherSnapshotNightTests {
    private func snapshot(sunrise: Double?, sunset: Double?) -> WeatherSnapshot {
        WeatherSamples.snapshot(hours: [], days: [
            WeatherSamples.day(Fixtures.today, min: 15, max: 22, sunrise: sunrise, sunset: sunset),
        ])
    }

    @Test(arguments: [(5.5, true), (6.1, false), (12.0, false), (17.4, true), (23.5, true)])
    func nightIsBeforeSunriseOrAfterSunset(hour: Double, isNight: Bool) {
        let moment = Fixtures.today.startOfDay(in: Fixtures.calendar).addingTimeInterval(hour * 3600)
        #expect(snapshot(sunrise: 6.1, sunset: 17.4).isNight(at: moment) == isNight)
    }

    @Test func withoutSunTimesNightIsUnknown() {
        #expect(snapshot(sunrise: nil, sunset: nil).isNight(at: Fixtures.now) == nil)
        #expect(snapshot(sunrise: 6.1, sunset: 17.4).isNight(at: Fixtures.date(2026, 10, 27, 1)) == nil)
    }
}

struct WeatherSnapshotTests {
    private static let ages: [(TimeInterval, String)] = [
        (30, "刚刚更新"), (25 * 60, "25 分钟前更新"), (3 * 3600, "3 小时前更新"), (50 * 3600, "2 天前更新"),
    ]

    @Test(arguments: ages)
    func ageIsWrittenInWords(seconds: TimeInterval, label: String) {
        let snapshot = WeatherSamples.snapshot(hours: [], days: [], fetchedAt: Fixtures.now)
        #expect(snapshot.ageLabel(now: Fixtures.now.addingTimeInterval(seconds)) == label)
    }

    @Test func goesStaleAfterSixHours() {
        let snapshot = WeatherSamples.snapshot(hours: [], days: [], fetchedAt: Fixtures.now)
        #expect(!snapshot.isStale(now: Fixtures.now.addingTimeInterval(6 * 3600 - 1)))
        #expect(snapshot.isStale(now: Fixtures.now.addingTimeInterval(6 * 3600)))
    }

    @Test func findsTheDayAroundADate() {
        let today = Fixtures.today
        let tomorrow = Fixtures.day(2026, 10, 26)
        let snapshot = WeatherSamples.snapshot(
            hours: [], days: [WeatherSamples.day(today, min: 1, max: 2), WeatherSamples.day(tomorrow, min: 3, max: 4)]
        )
        #expect(snapshot.day(containing: Fixtures.date(2026, 10, 26, 12))?.temperatureMin == 3)
        #expect(snapshot.day(containing: Fixtures.date(2026, 10, 28, 12)) == nil)
    }
}

struct WeatherSymbolTests {
    private static let symbols: [(String, String)] = [
        ("100", "sun.max"), ("150", "moon.stars"), ("101", "cloud.sun"), ("103", "cloud.sun"), ("151", "cloud.moon"),
        ("104", "cloud"), ("300", "cloud.sun.rain"), ("350", "cloud.moon.rain"), ("302", "cloud.bolt.rain"),
        ("305", "cloud.drizzle"), ("306", "cloud.rain"), ("307", "cloud.heavyrain"), ("313", "cloud.sleet"),
        ("400", "cloud.snow"), ("404", "cloud.sleet"), ("501", "cloud.fog"), ("502", "sun.haze"), ("507", "sun.dust"),
        ("900", "thermometer.sun"), ("901", "thermometer.snowflake"), ("999", "thermometer.medium"), ("", "thermometer.medium"),
    ]

    @Test(arguments: symbols)
    func codesMapToSymbols(code: String, symbol: String) {
        #expect(WeatherSymbol.name(for: code) == symbol)
    }

    /// 和风天气's v1 weather API sends "100" for a clear sky at midnight too.
    @Test func nightShowsTheMoon() {
        #expect(WeatherSymbol.name(for: "100", atNight: true) == "moon.stars")
        #expect(WeatherSymbol.name(for: "103", atNight: true) == "cloud.moon")
        #expect(WeatherSymbol.name(for: "300", atNight: true) == "cloud.moon.rain")
        #expect(WeatherSymbol.name(for: "305", atNight: true) == "cloud.drizzle")
    }

    @Test func everySymbolExistsOnThisMac() {
        let codes = Array(100...104) + Array(150...153) + Array(300...318) + [350, 351, 399]
            + Array(400...410) + [456, 457, 499] + Array(500...515) + [900, 901, 999]
        for code in codes {
            let name = WeatherSymbol.name(for: String(code))
            #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(code) → \(name)")
        }
    }
}
