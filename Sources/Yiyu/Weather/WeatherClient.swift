import Foundation
import YiyuCore

/// Why the weather could not be fetched, in words the panel and the settings window can show.
enum WeatherFailure: Error, Equatable {
    case service(QWeatherError)
    case offline(String)
    case notSetUp(String)

    init(_ error: Error) {
        switch error {
        case let failure as WeatherFailure: self = failure
        case let service as QWeatherError: self = .service(service)
        default: self = .offline(error.localizedDescription)
        }
    }

    var userMessage: String {
        switch self {
        case .service(let error): error.userMessage
        case .offline(let reason): "连不上和风天气（\(reason)），稍后会自动再试"
        case .notSetUp(let what): what
        }
    }

    /// Whether trying again later can help without the settings changing.
    var isRetryable: Bool {
        switch self {
        case .service(let error): error.isRetryable
        case .offline: true
        case .notSetUp: false
        }
    }
}

/// One-shot GETs to 和风天气 with the API KEY in a header.
struct WeatherClient: Sendable {
    /// Enough to reach 20:00 tomorrow when asked at 20:00 today.
    private static let forecastHours = 36
    private static let forecastDays = 3
    private static let timeout: TimeInterval = 15
    /// Redirects are refused: the API KEY header would travel along to wherever they point.
    private static let session = URLSession(configuration: .ephemeral, delegate: RefuseRedirects(), delegateQueue: nil)

    let api: QWeatherAPI
    let key: String

    func searchCities(_ query: String) async throws -> [WeatherCity] {
        guard let url = api.cityLookupURL(query) else { throw WeatherFailure.notSetUp("API Host 不对") }
        return try QWeatherResponse.cities(from: try await get(url))
    }

    /// Current weather, the hourly and the daily forecast, fetched side by side.
    func snapshot(for city: WeatherCity, now: Date = Date()) async throws -> WeatherSnapshot {
        guard let currentURL = api.currentURL(for: city),
              let hourlyURL = api.hourlyURL(for: city, hours: Self.forecastHours),
              let dailyURL = api.dailyURL(for: city, days: Self.forecastDays)
        else { throw WeatherFailure.notSetUp("API Host 不对") }
        async let current = get(currentURL)
        async let hourly = get(hourlyURL)
        async let daily = get(dailyURL)
        let (currentData, hourlyData, dailyData) = try await (current, hourly, daily)
        return WeatherSnapshot(
            cityID: city.id, fetchedAt: now,
            current: try QWeatherResponse.current(from: currentData),
            hours: try QWeatherResponse.hours(from: hourlyData),
            days: try QWeatherResponse.days(from: dailyData)
        )
    }

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue(key, forHTTPHeaderField: QWeatherAPI.keyHeader)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch {
            throw WeatherFailure.offline(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw QWeatherError.unreadable }
        guard (200..<300).contains(http.statusCode) else {
            throw QWeatherResponse.error(status: http.statusCode, body: data)
        }
        return data
    }
}

private final class RefuseRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
