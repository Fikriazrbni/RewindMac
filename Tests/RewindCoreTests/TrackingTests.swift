import Foundation
import Testing
@testable import RewindCore

struct TrackingTests {
    let epoch = Date(timeIntervalSince1970: 1_700_000_000)
    let a = AppIdentity("com.apple.dt.Xcode", "Xcode")
    let b = AppIdentity("com.apple.Safari", "Safari")
    func sample(_ seconds: Double) -> ClockSample { ClockSample(epoch.addingTimeInterval(seconds), uptime: seconds + 1000) }
    var enabled: Preferences { var p = Preferences(); p.consent = true; p.trackingEnabled = true; return p }
    func saved(_ changes: [SessionMutation]) -> [ActivitySession] { changes.compactMap { if case .save(let session) = $0 { return session }; return nil } }

    @Test func testConsentRequired() {
        var machine = TrackingMachine()
        #expect(machine.update(app: a, sample: sample(0), idleSeconds: 0, preferences: Preferences()).isEmpty)
        #expect(machine.active == nil)
    }
    @Test func testStartSwitchAndNoOverlap() {
        var m = TrackingMachine()
        _ = m.update(app: a, sample: sample(0), idleSeconds: 0, preferences: enabled)
        let events = saved(m.update(app: b, sample: sample(40), idleSeconds: 0, preferences: enabled))
        #expect(events.count == 2)
        #expect(events[0].duration == 40)
        #expect(!(events[0].isOpen))
        #expect(events[0].end == events[1].start)
        #expect(events[1].beganWithSwitch)
    }
    @Test func testDuplicateActivationKeepsSessionIdentity() {
        var m = TrackingMachine()
        _ = m.update(app: a, sample: sample(0), idleSeconds: 0, preferences: enabled)
        let id = m.active?.id
        _ = m.update(app: a, sample: sample(30), idleSeconds: 1, preferences: enabled)
        #expect(m.active?.id == id)
        #expect(!(m.active!.beganWithSwitch))
    }
    @Test func testPauseResumeDoesNotBackfill() {
        var m = TrackingMachine(), p = enabled
        _ = m.update(app: a, sample: sample(0), idleSeconds: 0, preferences: p)
        p.trackingEnabled = false
        let end = saved(m.update(app: a, sample: sample(30), idleSeconds: 0, preferences: p)).first!
        #expect(end.duration == 30); #expect(m.active == nil)
        p.trackingEnabled = true
        _ = m.update(app: b, sample: sample(60), idleSeconds: 0, preferences: p)
        #expect(m.active?.start == epoch.addingTimeInterval(60)); #expect(!(m.active!.beganWithSwitch))
    }
    @Test func testIdleTrimsBackToLastInput() {
        var m = TrackingMachine()
        _ = m.update(app: a, sample: sample(0), idleSeconds: 0, preferences: enabled)
        for time in stride(from: 30.0, through: 300.0, by: 30) {
            _ = m.update(app: a, sample: sample(time), idleSeconds: max(0, time - 10), preferences: enabled)
        }
        let changes = m.update(app: a, sample: sample(315), idleSeconds: 305, preferences: enabled)
        #expect(saved(changes).first?.duration == 10)
        guard case .trim(let cutoff) = changes.last else { Issue.record("Missing retroactive trim"); return }
        #expect(cutoff == epoch.addingTimeInterval(10)); #expect(m.status == .idle)
        _ = m.update(app: a, sample: sample(330), idleSeconds: 1, preferences: enabled)
        #expect(m.active?.start == epoch.addingTimeInterval(330))
    }
    @Test func testExcludedAppsAndUnknownApps() {
        var m = TrackingMachine(), p = enabled
        p.excluded.insert(b.bundleID)
        _ = m.update(app: a, sample: sample(0), idleSeconds: 0, preferences: p)
        _ = m.update(app: b, sample: sample(15), idleSeconds: 0, preferences: p)
        #expect(m.status == .excluded); #expect(m.active == nil)
        _ = m.update(app: nil, sample: sample(30), idleSeconds: 0, preferences: p)
        #expect(m.status == .unavailable)
    }
    @Test func testSleepWakeAndSessionSwitch() {
        var m = TrackingMachine()
        _ = m.update(app: a, sample: sample(0), idleSeconds: 0, preferences: enabled)
        let close = saved(m.update(app: a, sample: sample(30), idleSeconds: 0, preferences: enabled, sleeping: true))
        #expect(close.first?.duration == 30); #expect(m.active == nil)
        _ = m.update(app: a, sample: sample(70), idleSeconds: 0, preferences: enabled)
        #expect(m.active?.start == epoch.addingTimeInterval(70))
        _ = m.update(app: a, sample: sample(80), idleSeconds: 0, preferences: enabled, sessionActive: false)
        #expect(m.status == .inactive); #expect(m.active == nil)
    }
    @Test func testBackwardClockWaitsAndForwardClockDoesNotInventTime() {
        var m = TrackingMachine()
        _ = m.update(app: a, sample: sample(0), idleSeconds: 0, preferences: enabled)
        _ = m.update(app: a, sample: sample(30), idleSeconds: 0, preferences: enabled)
        let result = saved(m.update(app: a, sample: ClockSample(epoch.addingTimeInterval(-100), uptime: 1060), idleSeconds: 0, preferences: enabled))
        #expect(result.first?.duration == 30); #expect(m.status == .clockChanged)
        _ = m.update(app: a, sample: ClockSample(epoch.addingTimeInterval(5000), uptime: 1090), idleSeconds: 0, preferences: enabled)
        #expect(m.active?.duration == 0)
    }
    @Test func testUnavailableIdleUsesForegroundFallback() {
        var m = TrackingMachine()
        _ = m.update(app: a, sample: sample(0), idleSeconds: nil, preferences: enabled)
        _ = m.update(app: a, sample: sample(15), idleSeconds: .nan, preferences: enabled)
        #expect(m.status == .recording); #expect(m.active?.duration == 15)
    }
    @Test func testLongUnobservedGapClosesAtLastSample() {
        var m = TrackingMachine()
        _ = m.update(app: a, sample: sample(0), idleSeconds: 0, preferences: enabled)
        _ = m.update(app: a, sample: sample(30), idleSeconds: 0, preferences: enabled)
        let saved = saved(m.update(app: a, sample: sample(600), idleSeconds: 0, preferences: enabled))
        #expect(saved.first?.end == epoch.addingTimeInterval(30))
        #expect(m.active?.start == epoch.addingTimeInterval(600))
    }
}
