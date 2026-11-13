import Foundation
import Testing
@testable import RewindCore

struct AnalyticsTests {
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }
    let app = AppIdentity("dev.editor", "Editor")
    func session(_ start: String, _ end: String, category: String = "Development") -> ActivitySession { ActivitySession(app: app, start: date(start), end: date(end), category: category) }
    @Test func testMidnightClippingAndMathematicalConsistency() {
        let s = session("2026-11-10T23:30:00Z", "2026-11-11T01:30:00Z")
        let interval = utc.dateInterval(of: .day, for: date("2026-11-11T12:00:00Z"))!
        let r = Analytics.report(sessions: [s], interval: interval, calendar: utc)
        #expect(r.total == 5400)
        #expect(r.apps.map(\.duration).reduce(0, +) == r.total)
        #expect(r.categories.map(\.duration).reduce(0, +) == r.total)
        #expect(r.hours.map(\.duration).reduce(0, +) == r.total)
        #expect(r.hours.count == 2)
    }
    @Test func testExclusiveEndAndEmptyData() {
        let s = session("2026-11-10T12:00:00Z", "2026-11-10T13:00:00Z")
        let r = Analytics.report(sessions: [s], interval: DateInterval(start: s.end, duration: 60), calendar: utc)
        #expect(r.total == 0); #expect(r.peakHour == nil); #expect(r.apps.isEmpty); #expect(r.switches == 0)
    }
    @Test func testTimezoneReportsAndDST() {
        var ny = utc; ny.timeZone = TimeZone(identifier: "America/New_York")!
        let s = session("2026-11-01T05:30:00Z", "2026-11-01T07:30:00Z")
        let interval = ny.dateInterval(of: .day, for: s.start)!
        #expect(interval.duration == 25 * 3600)
        let r = Analytics.report(sessions: [s], interval: interval, calendar: ny)
        #expect(r.total == 7200); #expect(r.hours.count == 3)
        #expect(r.hours.map(\.duration).reduce(0, +) == 7200)
        #expect(r.peakHour == 1)
        var jakarta = utc; jakarta.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        let midnight = session("2026-11-10T16:30:00Z", "2026-11-10T18:30:00Z")
        let day = jakarta.dateInterval(of: .day, for: date("2026-11-10T18:00:00Z"))!
        #expect(Analytics.report(sessions: [midnight], interval: day, calendar: jakarta).total == 5400)
    }
    @Test func testSpringForwardAndWeeklyTopApp() {
        var la = utc; la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let day = la.dateInterval(of: .day, for: date("2026-03-08T12:00:00Z"))!
        #expect(day.duration == 23 * 3600)
        let a = ActivitySession(app: app, start: day.start, end: day.end)
        let b = ActivitySession(app: AppIdentity("browser", "Browser"), start: day.end, end: day.end.addingTimeInterval(60))
        let r = Analytics.report(sessions: [a, b], interval: DateInterval(start: day.start, duration: 7 * 86400), calendar: la)
        #expect(r.apps.first?.app == app)
        #expect(r.hours.reduce(0) { $0 + $1.duration } == r.total)
    }
    @Test func testWeekStartsMondayAndSwitchesUseOriginalStart() {
        let d = date("2026-11-13T12:00:00Z")
        let week = Analytics.week(containing: d, calendar: utc)
        #expect(week.start == date("2026-11-09T00:00:00Z"))
        var s = session("2026-11-08T23:00:00Z", "2026-11-09T01:00:00Z")
        s.beganWithSwitch = true
        #expect(Analytics.report(sessions: [s], interval: week, calendar: utc).switches == 0)
    }
    @Test func testDeterministicPersonality() {
        let s = session("2026-11-10T10:00:00Z", "2026-11-10T14:00:00Z")
        let r = Analytics.report(sessions: [s], interval: Analytics.week(containing: s.start, calendar: utc), calendar: utc)
        #expect(r.personality == "The Code Architect")
    }
    @Test func testExportDurationEscapingAndJSONRoundTrip() throws {
        var s = session("2026-11-10T10:00:00Z", "2026-11-10T10:01:30Z")
        s.app.name = "=SUM(\"a,b\")"
        let csv = String(decoding: ActivityExport.csv([s]), as: UTF8.self)
        #expect(csv.contains("90.000")); #expect(csv.contains("\"'=SUM(\"\"a,b\"\")\""))
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode([ActivitySession].self, from: ActivityExport.json([s])) == [s])
    }
    @Test func testDemoHasNoOverlapsAndNoFutureSessions() {
        let now = date("2026-11-13T12:00:00Z"), sessions = DemoData.sessions(now: date("2026-11-13T12:00:00Z"), calendar: utc)
        #expect(!(sessions.isEmpty))
        for i in 1..<sessions.count { #expect(sessions[i].start >= sessions[i-1].end) }
        #expect(sessions.allSatisfy { $0.end <= now && $0.duration > 0 })
    }
}
