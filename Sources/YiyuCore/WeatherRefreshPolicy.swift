import Foundation

/// When to fetch the next forecast: every half hour, backing off after failures that waiting can
/// fix, and not at all after ones it cannot (a wrong key or host) until the settings change.
public struct WeatherRefreshPolicy: Equatable, Sendable {
    public static let refreshInterval: TimeInterval = 30 * 60
    public static let firstRetryDelay: TimeInterval = 60
    public static let maxRetryDelay: TimeInterval = 60 * 60
    public static let initial = WeatherRefreshPolicy(nextAttempt: .distantPast, retryDelay: firstRetryDelay, isBlocked: false)

    public let nextAttempt: Date
    /// How long the next failure waits before trying again.
    public let retryDelay: TimeInterval
    public let isBlocked: Bool

    private init(nextAttempt: Date, retryDelay: TimeInterval, isBlocked: Bool) {
        self.nextAttempt = nextAttempt
        self.retryDelay = retryDelay
        self.isBlocked = isBlocked
    }

    public func isDue(now: Date, lastFetch: Date?) -> Bool {
        guard !isBlocked, now >= nextAttempt else { return false }
        guard let lastFetch else { return true }
        return now.timeIntervalSince(lastFetch) >= Self.refreshInterval
    }

    public func succeeded() -> WeatherRefreshPolicy { .initial }

    public func failed(isRetryable: Bool, now: Date) -> WeatherRefreshPolicy {
        guard isRetryable else {
            return WeatherRefreshPolicy(nextAttempt: nextAttempt, retryDelay: retryDelay, isBlocked: true)
        }
        return WeatherRefreshPolicy(
            nextAttempt: now.addingTimeInterval(retryDelay),
            retryDelay: min(retryDelay * 2, Self.maxRetryDelay),
            isBlocked: false
        )
    }

    /// After a wake the network needs a moment; that short wait replaces an earlier back-off,
    /// which may come from a request the timer fired before the network was back.
    public func woke(now: Date, settle: TimeInterval) -> WeatherRefreshPolicy {
        guard !isBlocked else { return self }
        return WeatherRefreshPolicy(nextAttempt: now.addingTimeInterval(settle), retryDelay: Self.firstRetryDelay, isBlocked: false)
    }
}
