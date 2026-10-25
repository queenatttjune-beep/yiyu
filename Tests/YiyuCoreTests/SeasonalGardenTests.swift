import Foundation
import Testing
@testable import YiyuCore

struct SeasonalGardenTests {
    private func scene(_ date: Date = Fixtures.now, code: String = "100", wind: Int? = 2,
                       fetchedAt: Date? = nil, city: WeatherCity? = WeatherSamples.hangzhou,
                       snapshotCityID: String = WeatherSamples.hangzhou.id) -> GardenScene {
        let snapshot = WeatherSnapshot(
            cityID: snapshotCityID, fetchedAt: fetchedAt ?? date,
            current: CurrentWeather(temperature: 20, feelsLike: 20, humidity: nil, windScale: wind,
                                    condition: WeatherCondition(code: code, text: "")),
            hours: [], days: []
        )
        return .resolve(at: date, city: city, snapshot: snapshot, calendar: Fixtures.calendar)
    }

    @Test func eachMonthHasASeasonalFlowerWithoutWeather() {
        let expected: [GardenFlower] = [
            .plum, .plum, .magnolia, .crabapple, .gardenia, .gardenia,
            .lotus, .lotus, .osmanthus, .chrysanthemum, .chrysanthemum, .camellia,
        ]
        for month in 1...12 {
            let garden = GardenScene.resolve(at: Fixtures.date(2026, month, 15), city: nil, snapshot: nil,
                                             calendar: Fixtures.calendar)
            #expect(garden.flower == expected[month - 1])
            #expect(garden.weather == .quiet)
        }
    }

    @Test func rainSnowSleetAndNightCodesKeepTheirMeaning() {
        for code in ["300", "302", "305", "313", "318", "350", "351", "399"] {
            #expect(scene(code: code).weather == .rain)
        }
        for code in ["400", "403", "407", "410", "457", "499"] {
            #expect(scene(code: code).weather == .snow)
        }
        for code in ["404", "405", "406", "456"] { #expect(scene(code: code).weather == .sleet) }
        #expect(scene(code: "150").weather == .clear)
        #expect(scene(code: "153").weather == .cloudy)
        #expect(scene(code: "501").weather == .mist)
        #expect(scene(code: "999").weather == .quiet)
        #expect(scene(code: "invalid").weather == .quiet)
    }

    @Test func windCanAccompanyRainButNeverSurvivesStaleWeather() {
        #expect(!scene(wind: 3).isWindy)
        #expect(!scene(wind: nil).isWindy)
        #expect(scene(code: "305", wind: 4).isWindy)
        let stale = scene(code: "305", wind: 6, fetchedAt: Fixtures.now.addingTimeInterval(-6 * 3600))
        #expect(stale.weather == .quiet && !stale.isWindy)
        #expect(stale.flower == .chrysanthemum)
        #expect(scene(fetchedAt: Fixtures.now.addingTimeInterval(-6 * 3600 + 1)).weather == .clear)
    }

    @Test func missingWrongCityAndFutureWeatherFallBackToSeasonOnly() {
        #expect(scene(city: nil).weather == .quiet)
        #expect(scene(snapshotCityID: "another-city").weather == .quiet)
        #expect(scene(fetchedAt: Fixtures.now.addingTimeInterval(1)).weather == .quiet)
    }

    @Test func flowerAndNightRollOverInTheChosenCityTimeZone() {
        let newYork = WeatherCity(id: "ny", name: "纽约", adm1: "", adm2: "", country: "美国",
                                  latitude: 40.7, longitude: -74, timeZoneID: "America/New_York")
        let date = Fixtures.date(2026, 10, 1, 1) // Still September, at noon, in New York.
        let local = GardenScene.resolve(at: date, city: newYork, snapshot: nil, calendar: Fixtures.calendar)
        #expect(local.flower == .osmanthus && !local.isNight)
        let shanghai = GardenScene.resolve(at: date, city: nil, snapshot: nil, calendar: Fixtures.calendar)
        #expect(shanghai.flower == .chrysanthemum && shanghai.isNight)
        #expect(!scene(Fixtures.date(2026, 10, 25, 6)).isNight)
        #expect(scene(Fixtures.date(2026, 10, 25, 19)).isNight)
        #expect(scene(Fixtures.date(2026, 10, 25, 5, 59)).isNight)
    }

    @Test func southernCitiesShiftTheSeasonAndNonGregorianMacsStillUseSolarMonths() {
        let sydney = WeatherCity(id: "sydney", name: "悉尼", adm1: "", adm2: "", country: "澳大利亚",
                                 latitude: -33.9, longitude: 151.2, timeZoneID: "Australia/Sydney")
        let south = GardenScene.resolve(at: Fixtures.date(2026, 1, 15, 12), city: sydney, snapshot: nil,
                                        calendar: Fixtures.calendar)
        #expect(south.flower == .lotus)
        var lunar = Calendar(identifier: .chinese)
        lunar.timeZone = Fixtures.calendar.timeZone
        let garden = GardenScene.resolve(at: Fixtures.date(2026, 3, 1, 12), city: nil, snapshot: nil, calendar: lunar)
        #expect(garden.flower == .magnolia)
    }
}
