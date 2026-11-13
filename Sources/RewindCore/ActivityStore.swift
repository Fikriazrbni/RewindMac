import Foundation
import CSQLite

public struct StorageError: Error, LocalizedError, Sendable {
    public let message: String
    public init(message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// One actor owns the connection. No database work runs on the main actor.
public actor ActivityStore {
    // Immutable handle; all operations are actor-isolated except final destruction.
    nonisolated(unsafe) private let db: OpaquePointer
    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let handle else {
            if let handle { sqlite3_close(handle) }
            throw StorageError(message: "Could not open local activity database.")
        }
        db = handle
        do {
            try Self.execute(handle, "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=3000;")
            try Self.execute(handle, "BEGIN IMMEDIATE")
            try Self.execute(handle, """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY, bundle TEXT NOT NULL, name TEXT NOT NULL,
                start REAL NOT NULL, end REAL NOT NULL, category TEXT NOT NULL,
                open INTEGER NOT NULL DEFAULT 0, switched INTEGER NOT NULL DEFAULT 0,
                CHECK(end >= start));
            CREATE INDEX IF NOT EXISTS sessions_time ON sessions(start, end);
            CREATE INDEX IF NOT EXISTS sessions_end ON sessions(end);
            CREATE TABLE IF NOT EXISTS preferences (id INTEGER PRIMARY KEY CHECK(id=1), json BLOB NOT NULL);
            UPDATE sessions SET open=0 WHERE open=1;
            DELETE FROM sessions WHERE end<=start;
            """)
            if sqlite3_table_column_metadata(handle, nil, "sessions", "screen_time", nil, nil, nil, nil, nil) != SQLITE_OK {
                try Self.execute(handle, "ALTER TABLE sessions ADD COLUMN screen_time INTEGER NOT NULL DEFAULT 0")
            }
            try Self.execute(handle, "PRAGMA user_version=2; COMMIT")
        } catch { sqlite3_close(handle); throw error }
    }
    // SQLite owns no Swift values; closing after actor isolation ends is safe.
    deinit { sqlite3_close(db) }

    private static func execute(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw StorageError(message: String(cString: sqlite3_errmsg(db)))
        }
    }
    private func statement(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StorageError(message: String(cString: sqlite3_errmsg(db)))
        }
        return stmt
    }
    private func bind(_ text: String, to index: Int32, in stmt: OpaquePointer) {
        _ = text.withCString { sqlite3_bind_text(stmt, index, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    }
    private func done(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw StorageError(message: String(cString: sqlite3_errmsg(db))) }
    }
    private func transaction(_ work: () throws -> Void) throws {
        try Self.execute(db, "BEGIN IMMEDIATE")
        do { try work(); try Self.execute(db, "COMMIT") }
        catch { try? Self.execute(db, "ROLLBACK"); throw error }
    }
    public func apply(_ mutations: [SessionMutation]) throws {
        guard !mutations.isEmpty else { return }
        try transaction {
            for mutation in mutations {
                switch mutation {
                case .save(let session):
                    if session.duration <= 0 && !session.isOpen {
                        let stmt = try statement("DELETE FROM sessions WHERE id=?")
                        defer { sqlite3_finalize(stmt) }; bind(session.id.uuidString, to: 1, in: stmt); try done(stmt)
                        continue
                    }
                    let stmt = try statement("INSERT OR REPLACE INTO sessions (id,bundle,name,start,end,category,open,switched,screen_time) VALUES(?,?,?,?,?,?,?,?,?)")
                    defer { sqlite3_finalize(stmt) }
                    bind(session.id.uuidString, to: 1, in: stmt)
                    bind(session.app.bundleID, to: 2, in: stmt); bind(session.app.name, to: 3, in: stmt)
                    sqlite3_bind_double(stmt, 4, session.start.timeIntervalSince1970)
                    sqlite3_bind_double(stmt, 5, session.end.timeIntervalSince1970)
                    bind(session.category, to: 6, in: stmt)
                    sqlite3_bind_int(stmt, 7, session.isOpen ? 1 : 0)
                    sqlite3_bind_int(stmt, 8, session.beganWithSwitch ? 1 : 0)
                    sqlite3_bind_int(stmt, 9, session.source == .screenTime ? 1 : 0)
                    try done(stmt)
                case .trim(let cutoff):
                    let remove = try statement("DELETE FROM sessions WHERE start>=? AND screen_time=0")
                    defer { sqlite3_finalize(remove) }
                    sqlite3_bind_double(remove, 1, cutoff.timeIntervalSince1970); try done(remove)
                    let trim = try statement("UPDATE sessions SET end=?, open=0 WHERE end>? AND screen_time=0")
                    defer { sqlite3_finalize(trim) }
                    sqlite3_bind_double(trim, 1, cutoff.timeIntervalSince1970)
                    sqlite3_bind_double(trim, 2, cutoff.timeIntervalSince1970); try done(trim)
                }
            }
        }
    }
    public func sessions(in interval: DateInterval? = nil, preferences: Preferences? = nil, screenTimeOnly: Bool = false) throws -> [ActivitySession] {
        let stmt = try statement("SELECT id,bundle,name,start,end,category,open,switched,screen_time FROM sessions WHERE end>start"
            + (interval == nil ? "" : " AND end>? AND start<?")
            + (screenTimeOnly ? " AND screen_time=1" : "") + " ORDER BY start")
        defer { sqlite3_finalize(stmt) }
        if let interval {
            sqlite3_bind_double(stmt, 1, interval.start.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 2, interval.end.timeIntervalSince1970)
        }
        func string(_ i: Int32) -> String { String(cString: sqlite3_column_text(stmt, i)) }
        var result: [ActivitySession] = []
        while true {
            let code = sqlite3_step(stmt)
            if code == SQLITE_DONE { break }
            guard code == SQLITE_ROW else { throw StorageError(message: String(cString: sqlite3_errmsg(db))) }
            let bundle = string(1)
            guard let id = UUID(uuidString: string(0)) else { continue }
            let source: ActivitySource? = sqlite3_column_int(stmt, 8) == 1 ? .screenTime : nil
            result.append(ActivitySession(id: id, app: AppIdentity(bundle, string(2)), start: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)), end: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)), category: preferences?.category(for: bundle) ?? string(5), isOpen: sqlite3_column_int(stmt, 6) == 1, beganWithSwitch: sqlite3_column_int(stmt, 7) == 1, source: source))
        }
        return result
    }
    public func knownApps(screenTimeOnly: Bool = false) throws -> [AppIdentity] {
        let stmt = try statement("SELECT bundle,MAX(name) FROM sessions"
            + (screenTimeOnly ? " WHERE screen_time=1" : "") + " GROUP BY bundle ORDER BY MAX(name) COLLATE NOCASE")
        defer { sqlite3_finalize(stmt) }
        var apps: [AppIdentity] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            apps.append(AppIdentity(String(cString: sqlite3_column_text(stmt, 0)), String(cString: sqlite3_column_text(stmt, 1))))
        }
        return apps
    }
    public func loadPreferences() throws -> Preferences {
        let stmt = try statement("SELECT json FROM preferences WHERE id=1")
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) {
            return try JSONDecoder().decode(Preferences.self, from: Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0))))
        }
        return Preferences()
    }
    public func savePreferences(_ preferences: Preferences) throws {
        let data = try JSONEncoder().encode(preferences)
        let stmt = try statement("INSERT OR REPLACE INTO preferences VALUES(1,?)")
        defer { sqlite3_finalize(stmt) }
        _ = data.withUnsafeBytes { sqlite3_bind_blob(stmt, 1, $0.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        try done(stmt)
    }
    public func deleteAll() throws {
        try Self.execute(db, "PRAGMA secure_delete=ON; DELETE FROM sessions; PRAGMA wal_checkpoint(TRUNCATE); VACUUM;")
    }
    public func retain(since date: Date) throws {
        let stmt = try statement("DELETE FROM sessions WHERE end<=?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970); try done(stmt)
        let trim = try statement("UPDATE sessions SET start=?, switched=0 WHERE start<?")
        defer { sqlite3_finalize(trim) }
        sqlite3_bind_double(trim, 1, date.timeIntervalSince1970)
        sqlite3_bind_double(trim, 2, date.timeIntervalSince1970); try done(trim)
    }
    public func report(in interval: DateInterval, preferences: Preferences, calendar: Calendar, screenTimeOnly: Bool = false) throws -> ActivityReport {
        Analytics.report(sessions: try sessions(in: interval, preferences: preferences, screenTimeOnly: screenTimeOnly), interval: interval, calendar: calendar)
    }

    public func previewScreenTime(_ candidates: [ActivitySession], interval: DateInterval, preferences: Preferences) throws -> [ActivitySession] {
        let existing = try sessions(in: interval, screenTimeOnly: true)
        return ScreenTimeImport.backfill(candidates, into: interval, excluding: preferences.excluded, occupied: existing)
    }

    public func importScreenTime(_ candidates: [ActivitySession], interval: DateInterval, preferences: Preferences) throws -> [ActivitySession] {
        // Recheck saved intervals before writing so repeat imports are safe.
        let sessions = try previewScreenTime(candidates, interval: interval, preferences: preferences)
        try apply(sessions.map { .save($0) })
        return sessions
    }
}
