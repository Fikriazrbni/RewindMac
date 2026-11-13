import Foundation
import Testing
@testable import RewindCore

struct StorageTests {
    @Test func testPersistenceRecoveryReassignmentAndPreferences() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("test.sqlite").path
        let s = ActivitySession(app: AppIdentity("dev.editor", "Editor"), start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 160), isOpen: true)
        var p = Preferences(); p.consent = true; p.assignments[s.app.bundleID] = "My category"; p.excluded.insert("hidden.app")
        let first = try ActivityStore(path: path)
        try await first.apply([.save(s)])
        try await first.savePreferences(p)
        let reopened = try ActivityStore(path: path)
        let recovered = try await reopened.sessions(preferences: p)
        #expect(recovered.count == 1); #expect(!(recovered[0].isOpen))
        #expect(recovered[0].end == s.end); #expect(recovered[0].category == "My category")
        let loaded = try await reopened.loadPreferences()
        #expect(loaded == p)
    }
    @Test func testCheckpointUpsertAndRetroactiveIdleAcrossApps() async throws {
        let db = try ActivityStore(path: ":memory:")
        var s = ActivitySession(app: AppIdentity("one", "One"), start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 30), isOpen: true)
        try await db.apply([.save(s)])
        s.end = Date(timeIntervalSince1970: 60)
        try await db.apply([.save(s)])
        let second = ActivitySession(app: AppIdentity("two", "Two"), start: s.end, end: s.end.addingTimeInterval(30))
        try await db.apply([.save(second), .trim(after: Date(timeIntervalSince1970: 10))])
        let values = try await db.sessions()
        #expect(values.count == 1); #expect(values[0].duration == 10)
    }
    @Test func testRangeRetentionAndDelete() async throws {
        let db = try ActivityStore(path: ":memory:")
        let s = ActivitySession(app: AppIdentity("one", "One"), start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 200))
        try await db.apply([.save(s)])
        let none = try await db.sessions(in: DateInterval(start: Date(timeIntervalSince1970: 200), duration: 100))
        #expect(none.isEmpty)
        try await db.retain(since: Date(timeIntervalSince1970: 150))
        let retained = try await db.sessions()
        #expect(retained.first?.duration == 50)
        try await db.deleteAll()
        let empty = try await db.sessions()
        #expect(empty.isEmpty)
    }
}
