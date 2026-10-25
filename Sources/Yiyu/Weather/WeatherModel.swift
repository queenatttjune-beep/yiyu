import AppKit
import Foundation
import Observation
import YiyuCore

/// Owns the weather: settings, the last forecast and the API KEY. Refreshes every half hour
/// (see `WeatherRefreshPolicy`) and sends the morning outfit notification when it is due.
@MainActor
@Observable
final class WeatherModel {
    private static let checkInterval: TimeInterval = 60
    /// The network is often not back the instant the Mac wakes.
    private static let wakeSettle: TimeInterval = 5
    /// The morning notification needs a forecast at most this old.
    private static let briefingFreshness: TimeInterval = 60 * 60
    private static let keyAccount = "qweather"
    private static let keyLabel = "一隅和风天气密钥"

    private(set) var state: WeatherState
    private(set) var hasKey: Bool
    private(set) var isRefreshing = false
    /// Why the last refresh failed; cleared by the next success.
    private(set) var problem: String?
    private(set) var storageProblem: String?
    /// Advances every minute, so advice and staleness follow the clock.
    private(set) var now = Date()

    @ObservationIgnored private let store: WeatherStore?
    @ObservationIgnored private let keychainService: String
    @ObservationIgnored private let baseCalendar: Calendar
    @ObservationIgnored private var cachedKey: String?
    @ObservationIgnored private var policy = WeatherRefreshPolicy.initial
    /// Bumped by every save, so a request started under the old settings cannot report back.
    @ObservationIgnored private var settingsGeneration = 0
    /// A refresh asked for while another was running, to run once it ends.
    @ObservationIgnored private var isRefreshPending = false
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    /// Called with the advice when the morning notification is due.
    @ObservationIgnored var onBriefing: ((OutfitAdvice) -> Void)?

    init(state: WeatherState, store: WeatherStore?, calendar: Calendar = .autoupdatingCurrent,
         bundleID: String = Bundle.main.bundleIdentifier ?? "yiyu") {
        let service = "\(bundleID).weather"
        self.state = state
        self.store = store
        self.baseCalendar = calendar
        self.keychainService = service
        self.hasKey = KeychainStore.exists(service: service, account: Self.keyAccount)
        #if DEBUG
        applyTourOverride()
        #endif
    }

    var settings: WeatherSettings { state.settings }
    var city: WeatherCity? { settings.city }
    var snapshot: WeatherSnapshot? { state.currentSnapshot }
    var isConfigured: Bool { QWeatherAPI(host: settings.apiHost) != nil && hasKey && city != nil }

    var garden: GardenScene {
        GardenScene.resolve(at: now, city: city, snapshot: snapshot, calendar: baseCalendar)
    }

    var advice: OutfitAdvice? {
        snapshot.flatMap { OutfitAdvisor.advice(for: $0, now: now, calendar: cityCalendar) }
    }

    /// The advice, unless the user closed its card.
    var visibleAdvice: OutfitAdvice? {
        guard let advice, !state.isHidden(advice) else { return nil }
        return advice
    }

    private var cityCalendar: Calendar { city?.calendar(basedOn: baseCalendar) ?? baseCalendar }

    func hideAdvice() {
        guard let advice else { return }
        update(state.with(hiddenAdvice: AdviceDismissal(day: advice.dayKey, wasToday: advice.isToday)))
    }

    // MARK: - Clock

    func start() {
        tick()
        let timer = Timer(timeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.didWake() }
        }
    }

    func tick(at date: Date = Date()) {
        now = date
        if isConfigured && !isRefreshing && policy.isDue(now: date, lastFetch: snapshot?.fetchedAt) {
            Task { await refresh() }
        }
        sendBriefingIfDue(at: date)
    }

    private func didWake() {
        policy = policy.woke(now: Date(), settle: Self.wakeSettle)
        Task {
            try? await Task.sleep(for: .seconds(Self.wakeSettle))
            tick()
        }
    }

    /// Fetches a new forecast now, whatever the half-hour rhythm. Asked for while one is running,
    /// it runs again afterwards, so a save during a refresh still gets its own.
    func refresh() async {
        guard !isRefreshing else {
            isRefreshPending = true
            return
        }
        guard let api = QWeatherAPI(host: settings.apiHost), let city else { return }
        isRefreshing = true
        let generation = settingsGeneration
        let outcome = await fetch(api: api, city: city)
        isRefreshing = false
        if generation == settingsGeneration {
            apply(outcome)
        }
        if isRefreshPending {
            isRefreshPending = false
            await refresh()
        }
    }

    private func fetch(api: QWeatherAPI, city: WeatherCity) async -> Result<WeatherSnapshot, WeatherFailure> {
        do {
            let key = try await readKey()
            return .success(try await WeatherClient(api: api, key: key).snapshot(for: city))
        } catch {
            return .failure(WeatherFailure(error))
        }
    }

    private func apply(_ outcome: Result<WeatherSnapshot, WeatherFailure>) {
        switch outcome {
        case .success(let fresh):
            update(state.with(snapshot: fresh))
            problem = nil
            policy = policy.succeeded()
            now = Date()
            sendBriefingIfDue(at: now)
        case .failure(let failure):
            NSLog("Yiyu: weather refresh failed: %@", failure.userMessage)
            problem = failure.userMessage
            policy = policy.failed(isRetryable: failure.isRetryable, now: Date())
        }
    }

    private func sendBriefingIfDue(at date: Date) {
        guard isConfigured,
              MorningBriefing.isDue(settings.briefing, now: date, lastSentDay: state.lastBriefingDay, calendar: baseCalendar)
        else { return }
        // An old forecast waits for the refresh that `tick` starts for it.
        guard let snapshot, date.timeIntervalSince(snapshot.fetchedAt) < Self.briefingFreshness,
              let advice = OutfitAdvisor.advice(for: snapshot, now: date, calendar: cityCalendar)
        else { return }
        update(state.with(lastBriefingDay: DayKey(date, calendar: baseCalendar)))
        onBriefing?(advice)
    }

    // MARK: - Settings

    /// Saves the settings (a non-blank `newKey` replaces the stored one) and fetches right away.
    /// Saving also clears an earlier error, so it doubles as "try again" after topping up.
    func save(host: String, newKey: String, city: WeatherCity?, briefing: BriefingSchedule) throws {
        let trimmedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            try KeychainStore.save(trimmedKey, service: keychainService, account: Self.keyAccount, label: Self.keyLabel)
            cachedKey = trimmedKey
            hasKey = true
        }
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        update(state.with(settings: WeatherSettings(apiHost: trimmedHost, city: city, briefing: briefing)))
        settingsGeneration += 1
        policy = .initial
        problem = nil
        Task { await refresh() }
    }

    /// Searches with what is typed in the settings window, before it is saved;
    /// a blank `newKey` means the stored key.
    func searchCities(_ query: String, host: String, newKey: String) async throws -> [WeatherCity] {
        guard let api = QWeatherAPI(host: host) else {
            throw WeatherFailure.notSetUp("API Host 应该是和风天气控制台里的地址，形如 abcxyz.qweatherapi.com")
        }
        let typedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = typedKey.isEmpty ? try await readKey() : typedKey
        return try await WeatherClient(api: api, key: key).searchCities(query)
    }

    /// Kept in memory after the first read, so macOS asks about the keychain at most once a launch.
    /// Read off the main thread: the keychain prompt must not freeze the panel.
    private func readKey() async throws -> String {
        if let cachedKey { return cachedKey }
        let service = keychainService
        let account = Self.keyAccount
        let stored: String?
        do {
            stored = try await Task.detached { try KeychainStore.read(service: service, account: account) }.value
        } catch {
            throw WeatherFailure.notSetUp("没能读取钥匙串里的 API KEY（\(error.localizedDescription)），请在天气设置里重新保存一次")
        }
        // A save while the keychain was being read already set the newer key.
        if let cachedKey { return cachedKey }
        guard let stored, !stored.isEmpty else {
            hasKey = false
            throw WeatherFailure.notSetUp("还没填和风天气的 API KEY")
        }
        cachedKey = stored
        return stored
    }

    // MARK: - Storage

    func reportStorageProblem(_ message: String) {
        storageProblem = message
    }

    private func update(_ next: WeatherState) {
        guard next != state else { return }
        state = next
        guard let store else { return }
        do {
            try store.save(next)
        } catch {
            NSLog("Yiyu: saving %@ failed: %@", store.fileURL.path, String(describing: error))
            storageProblem = "没能保存天气设置：\(error.localizedDescription)"
        }
    }

    #if DEBUG
    static let tourKey = "mock-key"

    /// In-memory clock/weather fixtures for screenshots; never saved or used in release builds.
    func setGardenForTour(at date: Date, snapshot: WeatherSnapshot?) {
        now = date
        state = state.with(snapshot: snapshot)
    }

    /// The UI tour points the app at scripts/mock-qweather-server.py instead of 和风天气.
    private func applyTourOverride() {
        guard let url = ProcessInfo.processInfo.environment["YIYU_TOUR_WEATHER_URL"] else { return }
        let hangzhou = WeatherCity(
            id: "101210101", name: "杭州", adm1: "浙江省", adm2: "杭州", country: "中国",
            latitude: 30.29, longitude: 120.16, timeZoneID: "Asia/Shanghai"
        )
        state = state.with(settings: WeatherSettings(apiHost: url, city: hangzhou, briefing: .default))
        cachedKey = Self.tourKey
        hasKey = true
    }
    #endif
}

extension WeatherModel {
    /// Weather is a preference: if `weather.json` cannot be read, the panel still opens without it.
    static func load(in directory: URL, calendar: Calendar) -> WeatherModel {
        let store = WeatherStore(directory: directory)
        do {
            let loaded = try store.load()
            let model = WeatherModel(state: loaded.state, store: store, calendar: calendar)
            if case .recovered(let backupURL) = loaded.outcome {
                model.reportStorageProblem("天气设置读不出来，已另存为 \(backupURL.lastPathComponent)，需要重新设置。")
            }
            return model
        } catch {
            NSLog("Yiyu: reading %@ failed: %@", store.fileURL.path, String(describing: error))
            let model = WeatherModel(state: .empty, store: nil, calendar: calendar)
            model.reportStorageProblem("没能读取天气设置（\(error.localizedDescription)），这次的改动不会保存。")
            return model
        }
    }
}
