import Foundation
import Testing
@testable import YiyuCore

struct MorningBriefingTests {
    private let schedule = BriefingSchedule(isEnabled: true, hour: 7, minute: 30)

    private func isDue(
        _ schedule: BriefingSchedule, at hour: Int, _ minute: Int, lastSent: DayKey? = nil
    ) -> Bool {
        MorningBriefing.isDue(
            schedule, now: Fixtures.date(2026, 10, 25, hour, minute), lastSentDay: lastSent, calendar: Fixtures.calendar
        )
    }

    @Test func isDueFromTheSetTimeUntilNoon() {
        #expect(!isDue(schedule, at: 7, 29))
        #expect(isDue(schedule, at: 7, 30))
        #expect(isDue(schedule, at: 11, 59))
        #expect(!isDue(schedule, at: 12, 0))
    }

    @Test func isSentOnlyOnceADay() {
        #expect(!isDue(schedule, at: 8, 0, lastSent: Fixtures.today))
        #expect(isDue(schedule, at: 8, 0, lastSent: Fixtures.day(2026, 10, 24)))
    }

    @Test func aTurnedOffBriefingIsNeverDue() {
        #expect(!isDue(BriefingSchedule(isEnabled: false, hour: 7, minute: 30), at: 8, 0))
    }

    @Test func aLateBriefingKeepsAnHourOfGrace() {
        let late = BriefingSchedule(isEnabled: true, hour: 11, minute: 30)
        #expect(isDue(late, at: 12, 15))
        #expect(!isDue(late, at: 12, 31))
    }

    @Test func outOfRangeTimesAreClamped() {
        let odd = BriefingSchedule(isEnabled: true, hour: 25, minute: -3)
        #expect(odd.hour == 23)
        #expect(odd.minute == 0)
        #expect(BriefingSchedule.default.timeLabel == "7:30")
    }
}
