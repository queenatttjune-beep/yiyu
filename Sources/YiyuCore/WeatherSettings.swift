import Foundation

/// What the user chose in 天气设置. The API KEY is not here: it lives only in the keychain.
public struct WeatherSettings: Codable, Equatable, Sendable {
    public static let `default` = WeatherSettings(apiHost: "", city: nil, briefing: .default)

    public let apiHost: String
    public let city: WeatherCity?
    public let briefing: BriefingSchedule

    public init(apiHost: String, city: WeatherCity?, briefing: BriefingSchedule) {
        self.apiHost = apiHost
        self.city = city
        self.briefing = briefing
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            apiHost: try container.decodeIfPresent(String.self, forKey: .apiHost) ?? "",
            city: try container.decodeIfPresent(WeatherCity.self, forKey: .city),
            briefing: try container.decodeIfPresent(BriefingSchedule.self, forKey: .briefing) ?? .default
        )
    }
}

/// An outfit card the user closed. Whether it was today's or tomorrow's matters: tomorrow's card
/// put away in the evening must still show the next morning, as today's.
public struct AdviceDismissal: Codable, Equatable, Sendable {
    public let day: DayKey
    public let wasToday: Bool

    public init(day: DayKey, wasToday: Bool) {
        self.day = day
        self.wasToday = wasToday
    }
}

/// Everything kept in `weather.json`: the settings, the last forecast (so the panel has weather
/// to show offline), the day the briefing last went out and the card the user closed.
public struct WeatherState: Codable, Equatable, Sendable {
    public static let empty = WeatherState(settings: .default, snapshot: nil, lastBriefingDay: nil, hiddenAdvice: nil)

    public let settings: WeatherSettings
    public let snapshot: WeatherSnapshot?
    public let lastBriefingDay: DayKey?
    public let hiddenAdvice: AdviceDismissal?

    private init(settings: WeatherSettings, snapshot: WeatherSnapshot?, lastBriefingDay: DayKey?, hiddenAdvice: AdviceDismissal?) {
        self.settings = settings
        self.snapshot = snapshot
        self.lastBriefingDay = lastBriefingDay
        self.hiddenAdvice = hiddenAdvice
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            settings: try container.decodeIfPresent(WeatherSettings.self, forKey: .settings) ?? .default,
            snapshot: try container.decodeIfPresent(WeatherSnapshot.self, forKey: .snapshot),
            lastBriefingDay: try container.decodeIfPresent(DayKey.self, forKey: .lastBriefingDay),
            hiddenAdvice: try container.decodeIfPresent(AdviceDismissal.self, forKey: .hiddenAdvice)
        )
    }

    /// The saved forecast, if it is for the city chosen now.
    public var currentSnapshot: WeatherSnapshot? {
        guard let snapshot, snapshot.cityID == settings.city?.id else { return nil }
        return snapshot
    }

    public func isHidden(_ advice: OutfitAdvice) -> Bool {
        hiddenAdvice == AdviceDismissal(day: advice.dayKey, wasToday: advice.isToday)
    }

    public func with(settings: WeatherSettings) -> WeatherState {
        WeatherState(settings: settings, snapshot: snapshot, lastBriefingDay: lastBriefingDay, hiddenAdvice: hiddenAdvice)
    }

    public func with(snapshot: WeatherSnapshot?) -> WeatherState {
        WeatherState(settings: settings, snapshot: snapshot, lastBriefingDay: lastBriefingDay, hiddenAdvice: hiddenAdvice)
    }

    public func with(lastBriefingDay: DayKey?) -> WeatherState {
        WeatherState(settings: settings, snapshot: snapshot, lastBriefingDay: lastBriefingDay, hiddenAdvice: hiddenAdvice)
    }

    public func with(hiddenAdvice: AdviceDismissal?) -> WeatherState {
        WeatherState(settings: settings, snapshot: snapshot, lastBriefingDay: lastBriefingDay, hiddenAdvice: hiddenAdvice)
    }
}

/// Reads and writes `WeatherState` as `weather.json` next to the data file.
public struct WeatherStore: Sendable {
    public struct LoadResult: Equatable, Sendable {
        public let state: WeatherState
        public let outcome: DataStore.LoadOutcome
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public var fileURL: URL { directory.appendingPathComponent("weather.json") }

    /// An unreadable file is moved aside rather than overwritten.
    public func load() throws -> LoadResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return LoadResult(state: .empty, outcome: .fresh)
        }
        do {
            let state = try JSONDecoder().decode(WeatherState.self, from: Data(contentsOf: fileURL))
            return LoadResult(state: state, outcome: .loaded)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let aside = directory.appendingPathComponent("weather.unreadable-\(stamp).json")
            try fileManager.moveItem(at: fileURL, to: aside)
            return LoadResult(state: .empty, outcome: .recovered(backupURL: aside))
        }
    }

    public func save(_ state: WeatherState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }
}
