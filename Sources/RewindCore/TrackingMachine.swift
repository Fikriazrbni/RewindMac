import Foundation

/// Pure state machine. Every system event supplies its clock and idle sample.
public struct TrackingMachine: Sendable {
    public private(set) var active: ActivitySession?
    public private(set) var status: TrackingStatus = .off
    private var lastSample: ClockSample?
    private var previousForeground: AppIdentity?
    private var wasRecording = false
    private var clockFloor: Date?
    public init() {}

    public mutating func update(app: AppIdentity?, sample: ClockSample, idleSeconds: TimeInterval?, preferences: Preferences, sleeping: Bool = false, sessionActive: Bool = true) -> [SessionMutation] {
        var changes: [SessionMutation] = []
        let now = sample.date
        var discontinuity = false
        if let last = lastSample {
            let wall = now.timeIntervalSince(last.date)
            let monotonic = sample.uptime - last.uptime
            if abs(wall - monotonic) > 3 || wall < 0 || monotonic > 90 {
                close(at: last.date, into: &changes)
                clockFloor = max(clockFloor ?? last.date, last.date)
                discontinuity = true
            }
        }
        lastSample = sample
        if let floor = clockFloor, now < floor {
            status = .clockChanged; previousForeground = nil; wasRecording = false
            return changes
        }
        clockFloor = nil
        let idle = idleSeconds.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        let isIdle = idle.map { $0 >= Double(preferences.idleMinutes * 60) } ?? false
        if !preferences.consent { status = .off }
        else if !preferences.trackingEnabled { status = .paused }
        else if sleeping { status = .sleeping }
        else if !sessionActive { status = .inactive }
        else if isIdle { status = .idle }
        else if let app, preferences.excluded.contains(app.bundleID) { status = .excluded }
        else if app == nil { status = .unavailable }
        else { status = .recording }

        if status != .recording {
            let cutoff = isIdle ? now.addingTimeInterval(-(idle ?? 0)) : now
            close(at: cutoff, into: &changes)
            // Idle can span multiple checkpoints and programmatic app activations.
            if isIdle && wasRecording { changes.append(.trim(after: cutoff)) }
            previousForeground = nil; wasRecording = false
            return changes
        }
        guard let app else { return changes }
        let changedApp = previousForeground.map { $0.bundleID != app.bundleID } ?? false
        if active?.app.bundleID != app.bundleID {
            close(at: now, into: &changes)
            // On resume, start at the sampled event. Never backfill unobserved time.
            active = ActivitySession(app: app, start: now, end: now, category: preferences.category(for: app.bundleID), isOpen: true, beganWithSwitch: changedApp && wasRecording && !discontinuity)
        }
        if var current = active {
            current.end = max(current.start, now)
            current.category = preferences.category(for: app.bundleID)
            active = current
            changes.append(.save(current))
        }
        previousForeground = app; wasRecording = true
        return changes
    }

    public mutating func stop(at date: Date) -> [SessionMutation] {
        var result: [SessionMutation] = []
        close(at: date, into: &result)
        previousForeground = nil; wasRecording = false
        return result
    }
    public mutating func reset() { self = TrackingMachine() }
    private mutating func close(at date: Date, into changes: inout [SessionMutation]) {
        guard var current = active else { return }
        current.end = max(current.start, date); current.isOpen = false
        changes.append(.save(current)); active = nil
    }
}
