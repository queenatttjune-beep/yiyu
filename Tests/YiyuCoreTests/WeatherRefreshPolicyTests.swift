import Foundation
import Testing
@testable import YiyuCore

struct WeatherRefreshPolicyTests {
    private let now = Fixtures.now

    @Test func fetchesAtOnceWithoutAForecastThenEveryHalfHour() {
        let policy = WeatherRefreshPolicy.initial
        #expect(policy.isDue(now: now, lastFetch: nil))
        #expect(!policy.isDue(now: now, lastFetch: now.addingTimeInterval(-29 * 60)))
        #expect(policy.isDue(now: now, lastFetch: now.addingTimeInterval(-30 * 60)))
    }

    @Test func passingFailuresBackOffDoublingUpToAnHour() {
        var policy = WeatherRefreshPolicy.initial
        var waits: [TimeInterval] = []
        for _ in 0..<8 {
            policy = policy.failed(isRetryable: true, now: now)
            waits.append(policy.nextAttempt.timeIntervalSince(now))
        }
        #expect(waits == [60, 120, 240, 480, 960, 1920, 3600, 3600])
        #expect(!policy.isDue(now: now.addingTimeInterval(3599), lastFetch: nil))
        #expect(policy.isDue(now: now.addingTimeInterval(3600), lastFetch: nil))
    }

    @Test func aWrongKeyOrHostStopsRefreshingUntilReset() {
        let blocked = WeatherRefreshPolicy.initial.failed(isRetryable: false, now: now)
        #expect(blocked.isBlocked)
        #expect(!blocked.isDue(now: now.addingTimeInterval(24 * 3600), lastFetch: nil))
        #expect(WeatherRefreshPolicy.initial.isDue(now: now, lastFetch: nil))
    }

    @Test func successForgetsEarlierFailures() {
        let recovered = WeatherRefreshPolicy.initial
            .failed(isRetryable: true, now: now)
            .failed(isRetryable: true, now: now)
            .succeeded()
        #expect(recovered == .initial)
    }

    /// The timer can fire the moment the Mac wakes, before the network is back. Waking replaces
    /// that failure's back-off with a short settle, so the next try comes seconds later.
    @Test func wakingWaitsBrieflyForTheNetworkInsteadOfTheBackOff() {
        let failedAtWake = WeatherRefreshPolicy.initial.failed(isRetryable: true, now: now)
        let woke = failedAtWake.woke(now: now, settle: 5)
        #expect(!woke.isDue(now: now.addingTimeInterval(4), lastFetch: nil))
        #expect(woke.isDue(now: now.addingTimeInterval(5), lastFetch: nil))
        #expect(woke.retryDelay == WeatherRefreshPolicy.firstRetryDelay)
    }

    @Test func wakingDoesNotUnblockAWrongKey() {
        let blocked = WeatherRefreshPolicy.initial.failed(isRetryable: false, now: now)
        #expect(blocked.woke(now: now, settle: 5).isBlocked)
    }
}
