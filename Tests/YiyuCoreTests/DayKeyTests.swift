import Foundation
import Testing
@testable import YiyuCore

struct DayKeyTests {
    let calendar = Fixtures.calendar

    @Test func buildsFromDateInCalendarTimeZone() {
        let lateEvening = Fixtures.date(2026, 10, 25, 23, 59)
        #expect(DayKey(lateEvening, calendar: calendar) == Fixtures.day(2026, 10, 25))
    }

    @Test func comparesChronologically() {
        #expect(Fixtures.day(2026, 9, 30) < Fixtures.day(2026, 10, 1))
        #expect(Fixtures.day(2025, 12, 31) < Fixtures.day(2026, 1, 1))
        #expect(!(Fixtures.day(2026, 10, 25) < Fixtures.day(2026, 10, 25)))
    }

    @Test func addsDaysAcrossMonthAndYearBoundaries() {
        #expect(Fixtures.day(2026, 10, 31).adding(days: 1, calendar: calendar) == Fixtures.day(2026, 11, 1))
        #expect(Fixtures.day(2027, 1, 1).adding(days: -1, calendar: calendar) == Fixtures.day(2026, 12, 31))
    }

    @Test func countsDaysBetweenKeys() {
        #expect(Fixtures.day(2026, 10, 25).days(since: Fixtures.day(2026, 10, 22), calendar: calendar) == 3)
        #expect(Fixtures.day(2026, 10, 22).days(since: Fixtures.day(2026, 10, 25), calendar: calendar) == -3)
    }

    @Test func encodesAsPlainDateString() throws {
        let data = try JSONEncoder().encode([Fixtures.day(2026, 3, 7)])
        #expect(String(decoding: data, as: UTF8.self) == "[\"2026-03-07\"]")
        let decoded = try JSONDecoder().decode([DayKey].self, from: data)
        #expect(decoded == [Fixtures.day(2026, 3, 7)])
    }

    @Test func rejectsMalformedStrings() {
        #expect(DayKey(string: "2026-13-01") == nil)
        #expect(DayKey(string: "2026-10") == nil)
        #expect(DayKey(string: "hello") == nil)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([DayKey].self, from: Data("[\"bad\"]".utf8))
        }
    }
}
