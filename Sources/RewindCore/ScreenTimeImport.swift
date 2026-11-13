import Foundation
import CSQLite

public enum ScreenTimeReadError: LocalizedError, Equatable {
    case accessDenied

    public var errorDescription: String? { "macOS blocked access to Screen Time history." }
}

/// Reads the local Mac's app usage from Apple's KnowledgeC store. This on-disk
/// format is private and can change across macOS versions.
public enum ScreenTimeImport {
    private static var localDatabase: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Knowledge/knowledgeC.db")
    }

    public static func readLocal(in interval: DateInterval) throws -> [ActivitySession] {
        let knowledge = Result { try read(from: localDatabase, in: interval) }
        let sessions = (try? knowledge.get()) ?? []
        var focusWindows = [interval]
        if let first = sessions.first, let lastEnd = sessions.map(\.end).max() {
            // Prefer KnowledgeC for its entire observed span. The two Apple
            // sources measure usage differently, so don't mix them within it.
            focusWindows = []
            if first.start > interval.start {
                focusWindows.append(DateInterval(start: interval.start, end: first.start))
            }
            if lastEnd < interval.end {
                focusWindows.append(DateInterval(start: lastEnd, end: interval.end))
            }
        }
        guard !focusWindows.isEmpty else { return sessions }
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Biome/streams/restricted/App.InFocus/local")
        let focus: [ActivitySession]
        do {
            focus = try BiomeFocusHistory.read(directory: directory, interval: interval)
        } catch {
            if !sessions.isEmpty { return sessions }
            let fileError = error as NSError
            if fileError.domain == NSCocoaErrorDomain, fileError.code == NSFileReadNoPermissionError {
                throw ScreenTimeReadError.accessDenied
            }
            if fileError.domain == NSCocoaErrorDomain,
               [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(fileError.code) {
                return try knowledge.get()
            }
            if case .failure(let databaseError) = knowledge,
               databaseError as? ScreenTimeReadError == .accessDenied {
                throw ScreenTimeReadError.accessDenied
            }
            throw error
        }
        if sessions.isEmpty, focus.isEmpty { return try knowledge.get() }
        return sessions + focusWindows.flatMap { backfill(focus, into: $0, excluding: [], occupied: []) }
    }

    public static func read(from url: URL, in interval: DateInterval) throws -> [ActivitySession] {
        var handle: OpaquePointer?
        let status = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil)
        defer { if let handle { sqlite3_close(handle) } }
        guard status == SQLITE_OK, let handle else {
            if let handle, isAccessDenied(handle) { throw ScreenTimeReadError.accessDenied }
            throw StorageError(message: "Could not open the Screen Time database.")
        }
        sqlite3_busy_timeout(handle, 3000)
        sqlite3_exec(handle, "PRAGMA trusted_schema=OFF; PRAGMA query_only=ON", nil, nil, nil)

        // Remote devices carry a device identifier in ZSOURCE.
        let query = """
            SELECT o.ZVALUESTRING, o.ZSTARTDATE, o.ZENDDATE
            FROM ZOBJECT o LEFT JOIN ZSOURCE s ON o.ZSOURCE = s.Z_PK
            WHERE o.ZSTREAMNAME = '/app/usage' AND COALESCE(s.ZDEVICEID, '') = ''
              AND (o.ZSOURCE IS NULL OR o.ZSOURCE = 0 OR s.Z_PK IS NOT NULL)
              AND o.ZENDDATE > ? AND o.ZSTARTDATE < ?
              AND o.ZENDDATE > o.ZSTARTDATE
            ORDER BY o.ZSTARTDATE
            """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(handle, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            if isAccessDenied(handle) { throw ScreenTimeReadError.accessDenied }
            throw StorageError(message: "This file is not a supported KnowledgeC Screen Time database.")
        }
        sqlite3_bind_double(statement, 1, interval.start.timeIntervalSinceReferenceDate)
        sqlite3_bind_double(statement, 2, interval.end.timeIntervalSinceReferenceDate)

        var result: [ActivitySession] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_DONE { return result }
            guard code == SQLITE_ROW else {
                if isAccessDenied(handle) { throw ScreenTimeReadError.accessDenied }
                throw StorageError(message: "Could not finish reading Screen Time. Try again or choose a readable backup.")
            }
            guard let text = sqlite3_column_text(statement, 0) else { continue }
            let bundle = String(cString: text)
            let start = sqlite3_column_double(statement, 1)
            let end = sqlite3_column_double(statement, 2)
            guard isBundleIdentifier(bundle), start.isFinite, end.isFinite,
                  end > start, end - start <= 86_400 else { continue }
            result.append(ActivitySession(
                app: AppIdentity(bundle, bundle),
                start: Date(timeIntervalSinceReferenceDate: start),
                end: Date(timeIntervalSinceReferenceDate: end),
                source: .screenTime
            ))
        }
    }

    private static func isAccessDenied(_ database: OpaquePointer) -> Bool {
        let code = sqlite3_errcode(database)
        let fileError = sqlite3_system_errno(database)
        return code == SQLITE_AUTH || code == SQLITE_PERM || fileError == EACCES || fileError == EPERM
    }

    static func isBundleIdentifier(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count > 1 && value.utf8.count <= 255 && parts.allSatisfy { part in
            !part.isEmpty && part.utf8.allSatisfy { byte in
                (65...90).contains(byte) || (97...122).contains(byte) ||
                (48...57).contains(byte) || byte == 45 || byte == 95
            }
        }
    }

    /// Keep the earliest source session in an overlap and preserve all previously saved time.
    static func backfill(
        _ candidates: [ActivitySession], into interval: DateInterval,
        excluding excluded: Set<String>, occupied existing: [ActivitySession]
    ) -> [ActivitySession] {
        let ordered = candidates.sorted { left, right in
            if left.start != right.start { return left.start < right.start }
            if left.end != right.end { return left.end > right.end }
            return left.app.bundleID < right.app.bundleID
        }
        let occupied = existing.sorted { $0.start < $1.start }
        var result: [ActivitySession] = []
        var occupiedIndex = 0

        for candidate in ordered where !excluded.contains(candidate.app.bundleID) {
            var cursor = max(candidate.start, interval.start, result.last?.end ?? interval.start)
            let end = min(candidate.end, interval.end)
            guard cursor < end else { continue }
            while occupiedIndex < occupied.count, occupied[occupiedIndex].end <= cursor {
                occupiedIndex += 1
            }
            var index = occupiedIndex
            while index < occupied.count, occupied[index].start < end, cursor < end {
                let saved = occupied[index]
                if saved.start > cursor {
                    result.append(fragment(candidate, start: cursor, end: saved.start))
                }
                cursor = max(cursor, saved.end)
                index += 1
            }
            if cursor < end {
                result.append(fragment(candidate, start: cursor, end: end))
            }
        }
        return result
    }

    private static func fragment(_ session: ActivitySession, start: Date, end: Date) -> ActivitySession {
        ActivitySession(app: session.app, start: start, end: end, category: session.category, source: .screenTime)
    }
}
