import Foundation
import Testing
@testable import YiyuCore

struct QWeatherAPITests {
    private let city = WeatherSamples.hangzhou

    private static let hosts: [(String, String)] = [
        ("abcxyz.qweatherapi.com", "https://abcxyz.qweatherapi.com"),
        ("  abcxyz.qweatherapi.com/ \n", "https://abcxyz.qweatherapi.com"),
        ("https://abcxyz.qweatherapi.com/v7/weather/now?location=1", "https://abcxyz.qweatherapi.com"),
        ("HTTPS://ABCXYZ.qweatherapi.com", "https://abcxyz.qweatherapi.com"),
        ("http://127.0.0.1:8765", "http://127.0.0.1:8765"),
        ("http://localhost:9000/", "http://localhost:9000"),
        ("devapi.qweather.com", "https://devapi.qweather.com"),
    ]

    @Test(arguments: hosts)
    func hostsAreNormalised(input: String, expected: String) throws {
        let api = try #require(QWeatherAPI(host: input))
        #expect(api.baseURL.absoluteString == expected)
    }

    /// The API KEY goes to this host, so only 和风天气's own domains (and this Mac, for tests) are accepted.
    @Test(arguments: [
        "", "   ", "https://", "http://abcxyz.qweatherapi.com", "ab cd.com", "ftp://abcxyz.qweatherapi.com",
        "example.com", "qweatherapi.com.example.com", "https://abcxyz.qweatherapi.com@example.com",
        "https://user:pass@abcxyz.qweatherapi.com", "notqweatherapi.com",
    ])
    func unusableHostsAreRejected(input: String) {
        #expect(QWeatherAPI(host: input) == nil)
    }

    @Test func weatherURLsUseTwoDecimalCoordinatesAndChinese() throws {
        let api = try #require(QWeatherAPI(host: "h.qweatherapi.com"))
        #expect(api.currentURL(for: city)?.absoluteString == "https://h.qweatherapi.com/weather/v1/current/30.29/120.16?lang=zh")
        #expect(api.hourlyURL(for: city, hours: 36)?.absoluteString
            == "https://h.qweatherapi.com/weather/v1/hourly/30.29/120.16?hours=36&lang=zh")
        #expect(api.dailyURL(for: city, days: 3)?.absoluteString
            == "https://h.qweatherapi.com/weather/v1/daily/30.29/120.16?days=3&lang=zh")
    }

    @Test func southernAndWesternCoordinatesKeepTheirSign() throws {
        let api = try #require(QWeatherAPI(host: "h.qweatherapi.com"))
        let sydney = WeatherCity(
            id: "1", name: "悉尼", adm1: "新南威尔士州", adm2: "悉尼", country: "澳大利亚",
            latitude: -33.868, longitude: -151.209, timeZoneID: "Australia/Sydney"
        )
        #expect(api.currentURL(for: sydney)?.path == "/weather/v1/current/-33.87/-151.21")
    }

    @Test func cityLookupEncodesTheQuery() throws {
        let api = try #require(QWeatherAPI(host: "h.qweatherapi.com"))
        #expect(api.cityLookupURL("杭州")?.absoluteString
            == "https://h.qweatherapi.com/geo/v2/city/lookup?location=%E6%9D%AD%E5%B7%9E&number=10&lang=zh")
    }
}
