import Foundation
import Testing
@testable import YiyuCore

struct QWeatherResponseTests {
    private func data(_ text: String) -> Data { Data(text.utf8) }

    private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    @Test func readsCurrentWeather() throws {
        let current = try QWeatherResponse.current(from: data(#"""
        {"metadata": {"tag": "x", "attributions": ["https://developer.qweather.com/attribution.html"]},
         "condition": {"text": "少云", "code": "102"},
         "temperature": {"value": 31.71, "unit": "°C"}, "feelsLike": {"value": 34.2, "unit": "°C"},
         "humidity": 0.62,
         "wind": {"direction": {"degree": 215, "compass": "sw"}, "speed": {"value": 3.4, "unit": "m/s"}, "scale": 3},
         "precipitation": {"amount": {"value": 0, "unit": "mm"}, "intensity": {"value": 0, "unit": "mm/h"}, "type": "none"},
         "cloudCover": 0.3, "uvIndex": 6}
        """#))

        #expect(current == CurrentWeather(
            temperature: 31.71, feelsLike: 34.2, humidity: 0.62, windScale: 3,
            condition: WeatherCondition(code: "102", text: "少云")
        ))
    }

    @Test func readsHourlyForecasts() throws {
        let hours = try QWeatherResponse.hours(from: data(#"""
        {"metadata": {"tag": "x", "attributions": []},
         "hours": [
          {"forecastTime": "2024-05-31T03:00Z", "condition": {"text": "阴", "code": "104"},
           "temperature": {"value": 31.12, "unit": "°C"}, "feelsLike": {"value": 34.31, "unit": "°C"},
           "humidity": 0.76, "wind": {"direction": {"degree": 215, "compass": "sw"}, "speed": {"value": 3.42, "unit": "m/s"}, "scale": 3},
           "precipitation": {"amount": {"value": 0.09, "unit": "mm"}, "intensity": {"value": 0.09, "unit": "mm/h"},
                             "probability": 0.31, "type": "rain"},
           "uvIndex": 6},
          {"forecastTime": "2024-05-31T12:00+08:00", "condition": {"text": "多云", "code": "101"},
           "temperature": {"value": 31.01, "unit": "°C"}, "feelsLike": {"value": 33, "unit": "°C"},
           "precipitation": {"type": "hail"}}
         ]}
        """#))

        #expect(hours.count == 2)
        #expect(hours[0] == HourlyWeather(
            time: utc(2024, 5, 31, 3), temperature: 31.12, feelsLike: 34.31,
            condition: WeatherCondition(code: "104", text: "阴"),
            precipitationProbability: 0.31, precipitationType: .rain, windScale: 3, uvIndex: 6
        ))
        #expect(hours[1].time == utc(2024, 5, 31, 4))
        #expect(hours[1].precipitationProbability == nil)
        #expect(hours[1].precipitationType == .unknown)
        #expect(hours[1].windScale == nil)
        #expect(hours[1].uvIndex == nil)
    }

    @Test func readsDailyForecasts() throws {
        let days = try QWeatherResponse.days(from: data(#"""
        {"metadata": {"tag": "x", "attributions": []},
         "days": [{
          "forecastStartTime": "2024-08-10T16:00Z", "forecastEndTime": "2024-08-11T16:00Z",
          "astro": {"sunrise": "2024-08-10T21:30Z", "moonPhase": "waning-gibbous"},
          "temperatureMax": {"value": 29.94, "unit": "°C"}, "temperatureMin": {"value": 20.93, "unit": "°C"},
          "temperatureAvg": {"value": 25.57, "unit": "°C"}, "uvIndexMax": 6,
          "daytime": {"forecastStartTime": "2024-08-10T23:00Z", "forecastEndTime": "2024-08-11T11:00Z",
                      "condition": {"text": "小雨", "code": "305"},
                      "precipitation": {"amount": {"value": 0.75, "unit": "mm"}, "probability": 0.64, "type": "rain"}},
          "nighttime": {"condition": {"text": "多云", "code": "151"}}
         }]}
        """#))

        #expect(days == [DailyWeather(
            start: utc(2024, 8, 10, 16), end: utc(2024, 8, 11, 16), temperatureMax: 29.94, temperatureMin: 20.93,
            uvIndexMax: 6, daytime: WeatherCondition(code: "305", text: "小雨"), precipitationProbability: 0.64
        )])
    }

    @Test func readsCityLookups() throws {
        let cities = try QWeatherResponse.cities(from: data(#"""
        {"code": "200", "location": [
          {"name": "杭州", "id": "101210101", "lat": "30.28746", "lon": "120.15358", "adm2": "杭州",
           "adm1": "浙江省", "country": "中国", "tz": "Asia/Shanghai", "utcOffset": "+08:00", "isDst": "0",
           "type": "city", "rank": "11", "fxLink": "https://www.qweather.com/weather/hangzhou-101210101.html"}
         ], "refer": {"sources": ["QWeather"], "license": ["QWeather Developers License"]}}
        """#))

        #expect(cities == [WeatherCity(
            id: "101210101", name: "杭州", adm1: "浙江省", adm2: "杭州", country: "中国",
            latitude: 30.28746, longitude: 120.15358, timeZoneID: "Asia/Shanghai"
        )])
    }

    @Test func aLookupWithNoMatchIsEmpty() throws {
        #expect(try QWeatherResponse.cities(from: data(#"{"code": "204"}"#)).isEmpty)
        #expect(try QWeatherResponse.cities(from: data(#"{"code": "404", "location": []}"#)).isEmpty)
    }

    @Test func aLookupCodeOtherThanSuccessIsAnError() {
        #expect(throws: QWeatherError.unauthorized) {
            try QWeatherResponse.cities(from: data(#"{"code": "401"}"#))
        }
        #expect(throws: QWeatherError.noCredit) {
            try QWeatherResponse.cities(from: data(#"{"code": "402"}"#))
        }
    }

    @Test func unreadableBodiesAreReportedAsSuch() {
        #expect(throws: QWeatherError.unreadable) {
            try QWeatherResponse.current(from: data("<html>oops</html>"))
        }
        #expect(throws: QWeatherError.unreadable) {
            try QWeatherResponse.hours(from: data(#"{"hours": [{"forecastTime": "soon"}]}"#))
        }
    }

    private func problem(_ status: Int, _ title: String) -> Data {
        data(#"{"error": {"status": \#(status), "type": "https://dev.qweather.com/docs/resource/error-code/", "title": "\#(title)", "detail": "details"}}"#)
    }

    @Test func errorResponsesAreClassified() {
        #expect(QWeatherResponse.error(status: 401, body: problem(401, "Unauthorized")) == .unauthorized)
        #expect(QWeatherResponse.error(status: 403, body: problem(403, "No Credit")) == .noCredit)
        #expect(QWeatherResponse.error(status: 403, body: problem(403, "Overdue")) == .noCredit)
        #expect(QWeatherResponse.error(status: 403, body: problem(403, "Invalid Host")) == .badHost)
        #expect(QWeatherResponse.error(status: 403, body: problem(403, "Security Restriction")) == .rejected("Security Restriction"))
        #expect(QWeatherResponse.error(status: 400, body: problem(400, "No Such Location")) == .noSuchLocation)
        #expect(QWeatherResponse.error(status: 404, body: problem(404, "Not Found")) == .badHost)
        #expect(QWeatherResponse.error(status: 429, body: problem(429, "Too Many Requests")) == .tooManyRequests)
        #expect(QWeatherResponse.error(status: 429, body: problem(429, "Over Monthly Limit")) == .overMonthlyLimit)
        #expect(QWeatherResponse.error(status: 502, body: data("<html>bad gateway</html>")) == .server(502))
        #expect(QWeatherResponse.error(status: 400, body: data(#"{"code": "401"}"#)) == .unauthorized)
    }

    /// A proxy or captive portal can answer 401/403 too; only 和风天气's own error body is trusted
    /// to mean the key or host is wrong.
    @Test func errorsWithoutAServiceBodyAreTreatedAsPassing() {
        #expect(QWeatherResponse.error(status: 401, body: data("<html>login</html>")) == .unexpected(401))
        #expect(QWeatherResponse.error(status: 404, body: Data()) == .unexpected(404))
        #expect(QWeatherResponse.error(status: 302, body: Data()) == .unexpected(302))
        #expect(QWeatherResponse.error(status: 429, body: Data()) == .tooManyRequests)
        #expect(QWeatherError.unexpected(401).isRetryable)
    }

    @Test func onlyPassingTroubleIsRetried() {
        #expect(QWeatherError.tooManyRequests.isRetryable)
        #expect(QWeatherError.server(500).isRetryable)
        #expect(QWeatherError.unreadable.isRetryable)
        #expect(!QWeatherError.unauthorized.isRetryable)
        #expect(!QWeatherError.badHost.isRetryable)
        #expect(!QWeatherError.noCredit.isRetryable)
        #expect(!QWeatherError.overMonthlyLimit.isRetryable)
    }

    @Test func messagesExplainWhatToCheck() {
        #expect(QWeatherError.unauthorized.userMessage.contains("API KEY"))
        #expect(QWeatherError.badHost.userMessage.contains("API Host"))
        #expect(QWeatherError.rejected("").userMessage == "和风天气拒绝了请求")
        #expect(QWeatherError.server(503).userMessage.contains("503"))
    }

    @Test(arguments: [
        "2024-05-31T03:00Z", "2024-05-31T03:00:00Z", "2024-05-31T11:00+08:00", "2024-05-31T11:00+0800",
        "2024-05-30T22:30-04:30",
    ])
    func readsMinuteAndSecondTimestampsWithAnyOffset(text: String) {
        #expect(QWeatherDate.parse(text) == utc(2024, 5, 31, 3))
    }

    @Test(arguments: ["2024-13-01T00:00Z", "2024-05-31", "yesterday", "2024-05-31T25:00Z", "2024-05-31T03:00"])
    func rejectsMalformedTimestamps(text: String) {
        #expect(QWeatherDate.parse(text) == nil)
    }
}
