import Foundation

/// The weather outside as the panel paints it: light in the sky (the sun, or the moon at night),
/// and whatever is falling or drifting through it. The badge and the menu bar icon show it too.
public struct WeatherScene: Equatable, Sendable {
    public enum Strength: Int, Comparable, Sendable {
        case faint, medium, strong

        public static func < (lhs: Strength, rhs: Strength) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public enum Sky: Equatable, Sendable {
        case plain
        case sun(Strength)
        case moon(Strength)
    }

    /// The one sign the 18-point menu bar icon has room for; the blossom when nothing is going on.
    public enum Motif: Equatable, Sendable {
        case blossom, sun, moon, rain, snow, mist
    }

    public static let calm = WeatherScene()

    /// Current conditions are trusted this long; after that the hourly forecast says what the sky is doing.
    private static let currentFreshness: TimeInterval = 3600

    public let sky: Sky
    public let rain: Strength?
    public let snow: Strength?
    public let mist: Strength?

    public init(sky: Sky = .plain, rain: Strength? = nil, snow: Strength? = nil, mist: Strength? = nil) {
        self.sky = sky
        self.rain = rain
        self.snow = snow
        self.mist = mist
    }

    /// The scene for a 和风天气 weather code (https://dev.qweather.com/docs/resource/icons/).
    /// Cloudy and overcast skies, heat and cold leave the panel as it is. The v1 weather API sends
    /// daytime codes around the clock, so `atNight` turns its clear skies to moonlight.
    public init(code: String, atNight: Bool = false) {
        guard let number = Int(atNight ? WeatherCondition.nightCode(for: code) : code) else {
            self = .calm
            return
        }
        switch number {
        case 100: self.init(sky: .sun(.strong))
        case 102, 103: self.init(sky: .sun(.faint))
        case 150: self.init(sky: .moon(.strong))
        case 152, 153: self.init(sky: .moon(.faint))
        case 305, 309: self.init(rain: .faint, mist: .faint)
        case 300, 302, 306, 313, 314, 350, 399: self.init(rain: .medium)
        case 301, 303, 304, 307, 308, 310...312, 315...318, 351: self.init(rain: .strong)
        case 404...406, 456: self.init(rain: .faint, snow: .faint)
        case 400, 407, 457: self.init(snow: .faint)
        case 401, 408, 499: self.init(snow: .medium)
        case 402, 403, 409, 410: self.init(snow: .strong)
        case 500, 503, 504: self.init(mist: .faint)
        case 501, 502, 507, 508, 511: self.init(mist: .medium)
        case 509, 510, 512...515: self.init(mist: .strong)
        default: self = .calm
        }
    }

    /// The scene for the weather now: the current conditions while they are fresh, then the hourly
    /// forecast for this hour, by moonlight between sunset and sunrise. Calm when neither is known,
    /// or when the forecast is so old that the header greys it out.
    public static func now(in snapshot: WeatherSnapshot?, at date: Date, atNight: Bool? = nil) -> WeatherScene {
        guard let conditions = conditions(in: snapshot, at: date) else { return .calm }
        return WeatherScene(code: conditions.condition.code, atNight: atNight ?? snapshot?.isNight(at: date) ?? false)
    }

    /// Shared by the animated sky and seasonal garden so neither paints an older observation
    /// over the other one's current hourly forecast. Reject clock-skewed future snapshots too.
    public static func conditions(
        in snapshot: WeatherSnapshot?, at date: Date
    ) -> (condition: WeatherCondition, windScale: Int?)? {
        guard let snapshot, snapshot.fetchedAt <= date, !snapshot.isStale(now: date) else { return nil }
        if date.timeIntervalSince(snapshot.fetchedAt) < currentFreshness {
            return (snapshot.current.condition, snapshot.current.windScale)
        }
        let hour = snapshot.hours.first { $0.time <= date && date < $0.time.addingTimeInterval(3600) }
        return hour.map { ($0.condition, $0.windScale) }
    }

    public var isCalm: Bool { self == .calm }

    public var motif: Motif {
        if rain != nil { return .rain }
        if snow != nil { return .snow }
        if mist != nil { return .mist }
        switch sky {
        case .sun: return .sun
        case .moon: return .moon
        case .plain: return .blossom
        }
    }
}
