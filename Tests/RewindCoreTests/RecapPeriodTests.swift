import Foundation
import Testing
@testable import RewindCore

struct RecapPeriodTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func threeMonthsIncludesTodayAndUsesCalendarMonths() {
        let now = date(2026, 11, 13, hour: 16)
        let range = RecapPeriod.threeMonths.interval(endingNear: now, calendar: calendar)
        #expect(range.start == date(2026, 8, 14))
        #expect(range.end == date(2026, 11, 14))
        let report = Analytics.report(sessions: DemoData.sessions(now: now, calendar: calendar), interval: range, calendar: calendar)
        #expect(report.sessions.first.map { calendar.isDate($0.start, inSameDayAs: range.start) } == true)
    }

    @Test func previousWindowsAbutEvenAtMonthEnd() {
        let now = date(2024, 3, 30)
        let current = RecapPeriod.oneMonth.interval(endingNear: now, calendar: calendar)
        let previous = RecapPeriod.oneMonth.interval(endingNear: now, periodsBack: 1, calendar: calendar)
        #expect(current.start == date(2024, 2, 29))
        #expect(previous.end == current.start)
        #expect(previous.start == date(2024, 1, 31))
    }

    @Test func sevenDaysSpansSevenLocalDatesAcrossDST() {
        let range = RecapPeriod.sevenDays.interval(endingNear: date(2026, 3, 10), calendar: calendar)
        #expect(range.start == date(2026, 3, 4))
        #expect(range.end == date(2026, 3, 11))
        #expect(range.duration == 167 * 3600)
    }

    @Test func yearWindowsUseCalendarYearsAndAbut() {
        let now = date(2024, 2, 28, hour: 12)
        let current = RecapRange.preset(.oneYear, periodsBack: 0).interval(endingNear: now, calendar: calendar)
        let previous = RecapRange.preset(.oneYear, periodsBack: 1).interval(endingNear: now, calendar: calendar)
        #expect(current.start == date(2023, 2, 28))
        #expect(current.end == date(2024, 2, 29))
        #expect(previous.end == current.start)
    }

    @Test func customRangeCanSpanMultipleYearsAndIncludesTheFinalLocalDay() {
        let now = date(2026, 11, 13)
        let range = RecapRange.custom(from: date(2023, 6, 8, hour: 16), through: date(2026, 3, 8, hour: 15))
        let interval = range.interval(endingNear: now, calendar: calendar)
        #expect(interval.start == date(2023, 6, 8))
        #expect(interval.end == date(2026, 3, 9))
        #expect(interval.end.timeIntervalSince(date(2026, 3, 8)) == 23 * 3600)
    }
}
