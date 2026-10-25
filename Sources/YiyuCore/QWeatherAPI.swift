import Foundation

/// Where to send 和风天气 requests: each account has its own API Host, shown in the console's 设置.
public struct QWeatherAPI: Equatable, Sendable {
    /// The request header that carries the API KEY.
    public static let keyHeader = "X-QW-Api-Key"
    private static let localHosts: Set<String> = ["localhost", "127.0.0.1", "::1"]
    /// The API KEY travels with every request, so it only goes to 和风天气's own domains.
    private static let serviceDomains = ["qweatherapi.com", "qweather.com"]
    private static let language = URLQueryItem(name: "lang", value: "zh")

    public let baseURL: URL

    /// Accepts the host as copied from the console, with or without `https://` or a trailing path.
    /// 和风天气 only serves HTTPS; this Mac is also accepted, over HTTP too, for test servers.
    public init?(host: String) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let parsed = URLComponents(string: withScheme), parsed.user == nil, parsed.password == nil,
              let scheme = parsed.scheme?.lowercased(),
              let name = parsed.host?.lowercased(), !name.isEmpty
        else { return nil }
        let isLocal = Self.localHosts.contains(name)
        let isService = Self.serviceDomains.contains { name == $0 || name.hasSuffix(".\($0)") }
        guard isLocal || isService, scheme == "https" || (scheme == "http" && isLocal) else { return nil }

        var base = URLComponents()
        base.scheme = scheme
        base.host = name
        base.port = parsed.port
        guard let url = base.url else { return nil }
        baseURL = url
    }

    public func cityLookupURL(_ query: String, limit: Int = 10) -> URL? {
        url(path: "/geo/v2/city/lookup", query: [
            URLQueryItem(name: "location", value: query),
            URLQueryItem(name: "number", value: String(limit)),
        ])
    }

    public func currentURL(for city: WeatherCity) -> URL? {
        url(path: "/weather/v1/current/\(coordinates(of: city))", query: [])
    }

    public func hourlyURL(for city: WeatherCity, hours: Int) -> URL? {
        url(path: "/weather/v1/hourly/\(coordinates(of: city))", query: [URLQueryItem(name: "hours", value: String(hours))])
    }

    public func dailyURL(for city: WeatherCity, days: Int) -> URL? {
        url(path: "/weather/v1/daily/\(coordinates(of: city))", query: [URLQueryItem(name: "days", value: String(days))])
    }

    /// The API takes at most two decimal places.
    private func coordinates(of city: WeatherCity) -> String {
        String(format: "%.2f/%.2f", city.latitude, city.longitude)
    }

    private func url(path: String, query: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        components.path = path
        components.queryItems = query + [Self.language]
        return components.url
    }
}
