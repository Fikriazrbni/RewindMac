import Foundation
import Testing
import CSQLite
import zlib
@testable import RewindCore

struct ScreenTimeImportTests {
    private let app = AppIdentity("com.example.Editor", "Editor")

    @Test func readsLocalKnowledgeCUsageAndSkipsSyncedDevicesAndWebsites() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try makeDatabase(file, sql: """
            CREATE TABLE ZSOURCE (Z_PK INTEGER PRIMARY KEY, ZDEVICEID TEXT);
            CREATE TABLE ZOBJECT (ZSTREAMNAME TEXT, ZVALUESTRING TEXT, ZSTARTDATE REAL, ZENDDATE REAL, ZSOURCE INTEGER);
            INSERT INTO ZSOURCE VALUES (1, NULL), (2, 'phone');
            INSERT INTO ZOBJECT VALUES
                ('/app/usage', 'com.example.Editor', 100, 180, 1),
                ('/app/usage', 'com.example.Phone', 100, 190, 2),
                ('/app/usage', 'com.example.Unknown', 100, 190, 42),
                ('/app/webUsage', 'example.org', 100, 190, 1),
                ('/app/usage', 'https://example.org', 100, 190, 1),
                ('/app/usage', 'com.example.Old', 0, 50, 1);
            """)
        let rows = try ScreenTimeImport.read(from: file, in: DateInterval(start: date(110), end: date(200)))
        #expect(rows.map(\.app.bundleID) == [app.bundleID])
        #expect(rows.first?.start == date(100))
        #expect(rows.first?.end == date(180))
        #expect(rows.first?.source == .screenTime)
    }

    @Test func importIgnoresLegacyCutoffsAndIsSafeToRepeat() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let originalID = UUID()
        let nativeStart = date(200).timeIntervalSince1970
        try makeDatabase(file, sql: """
            PRAGMA user_version=1;
            CREATE TABLE sessions (id TEXT PRIMARY KEY,bundle TEXT,name TEXT,start REAL,end REAL,category TEXT,open INTEGER,switched INTEGER);
            INSERT INTO sessions VALUES ('\(originalID.uuidString)', 'com.example.Editor', 'Editor', \(nativeStart), \(nativeStart + 100), 'Development', 0, 1);
            """)
        let store = try ActivityStore(path: file.path)
        let interval = DateInterval(start: date(50), end: date(400))
        var settings = Preferences()
        settings.excluded.insert("com.example.Excluded")
        let candidates = [
            session(60, 150), session(90, 240), session(200, 350),
            ActivitySession(app: AppIdentity("com.example.Excluded", "Excluded"), start: date(50), end: date(60))
        ]
        let preview = try await store.previewScreenTime(candidates, interval: interval, preferences: settings)
        #expect(preview.map(\.duration) == [90, 90, 110])
        #expect(try await store.sessions().count == 1)
        let imported = try await store.importScreenTime(candidates, interval: interval, preferences: settings)
        #expect(imported.map(\.duration) == [90, 90, 110])
        #expect(try await store.importScreenTime(candidates, interval: interval, preferences: settings).isEmpty)
        let archive = try await store.sessions()
        #expect(archive.contains { $0.id == originalID && $0.duration == 100 })
        let report = try await store.report(in: interval, preferences: settings, calendar: .current, screenTimeOnly: true)
        #expect(report.total == 290)
        #expect(report.screenTimeDuration == 290)
        #expect(report.switches == 0)
        #expect(report.apps.first?.duration == 290)
    }

    @Test func decodesPairedLocalBiomeFocusEvents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var segment = Data("SEGB".utf8)
        append(UInt32(2), to: &segment)
        segment.append(Data(repeating: 0, count: 24))
        var table: [Data] = []
        for (time, start) in [(100.0, true), (180.0, false)] {
            var payload = Data([0x10, 0x01])
            if start { payload.append(contentsOf: [0x18, 0x01]) }
            payload.append(0x21)
            append(time.bitPattern, to: &payload)
            payload.append(contentsOf: [0x32, UInt8(app.bundleID.utf8.count)])
            payload.append(contentsOf: app.bundleID.utf8)
            let crc = payload.withUnsafeBytes {
                UInt32(crc32(0, $0.bindMemory(to: UInt8.self).baseAddress, UInt32($0.count)))
            }
            append(crc, to: &segment)
            append(UInt32(0), to: &segment)
            segment.append(payload)
            var entry = Data()
            append(UInt32(segment.count - 32), to: &entry)
            append(UInt32(1), to: &entry)
            append(time.bitPattern, to: &entry)
            table.append(entry)
            while !segment.count.isMultiple(of: 4) { segment.append(0) }
        }
        for entry in table.reversed() { segment.append(entry) }
        try segment.write(to: directory.appendingPathComponent("100000000"))

        let result = try BiomeFocusHistory.read(directory: directory, interval: DateInterval(start: date(90), end: date(200)))
        #expect(result.map(\.duration) == [80])
        #expect(result.first?.app.bundleID == app.bundleID)
    }

    private func date(_ seconds: Double) -> Date { Date(timeIntervalSinceReferenceDate: seconds) }

    private func session(_ start: Double, _ end: Double) -> ActivitySession {
        ActivitySession(app: app, start: date(start), end: date(end), source: .screenTime)
    }

    private func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private func makeDatabase(_ file: URL, sql: String) throws {
        var db: OpaquePointer?
        let result = sqlite3_open(file.path, &db)
        defer { sqlite3_close(db) }
        try #require(result == SQLITE_OK)
        let created = sqlite3_exec(db, sql, nil, nil, nil)
        try #require(created == SQLITE_OK)
    }
}
