import Foundation

public struct AppUsage: Identifiable, Sendable {
    public var id: String { app.bundleID }
    public var app: AppIdentity
    public var duration: Double
    public var category: String
}
public struct CategoryUsage: Identifiable, Sendable {
    public var id: String { category }
    public var category: String
    public var duration: Double
}
public struct HourUsage: Identifiable, Sendable {
    public var id: Date { start }
    public var start: Date
    public var duration: Double
}
public struct ActivityReport: Sendable {
    public var interval: DateInterval
    public var sessions: [ActivitySession]
    public var apps: [AppUsage]
    public var categories: [CategoryUsage]
    public var hours: [HourUsage]
    public var total: Double
    public var switches: Int
    public var longest: Double
    public var peakHour: Int?
    public var personality: String
    public var personalityReason: String
    public var screenTimeDuration: Double {
        sessions.reduce(0) { $0 + ($1.source == .screenTime ? $1.duration : 0) }
    }
    public var includesScreenTime: Bool { sessions.contains { $0.source == .screenTime } }
    public static func empty(_ interval: DateInterval = DateInterval(start: Date(), duration: 86400)) -> Self {
        Analytics.report(sessions: [], interval: interval)
    }
}

public enum Analytics {
    public static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        var cal = calendar; cal.firstWeekday = 2; cal.minimumDaysInFirstWeek = 4
        return cal.dateInterval(of: .weekOfYear, for: date)!
    }
    public static func report(sessions source: [ActivitySession], interval: DateInterval, calendar: Calendar = .current) -> ActivityReport {
        var sessions: [ActivitySession] = []
        var apps: [String: AppUsage] = [:]
        var categories: [String: Double] = [:]
        var hours: [Date: Double] = [:]
        var hourOfDay: [Int: Double] = [:]
        var switches = 0
        for original in source where original.end > interval.start && original.start < interval.end {
            var s = original
            s.start = max(s.start, interval.start); s.end = min(s.end, interval.end)
            guard s.duration > 0 else { continue }
            sessions.append(s)
            if original.beganWithSwitch && original.start >= interval.start { switches += 1 }
            var usage = apps[s.app.bundleID] ?? AppUsage(app: s.app, duration: 0, category: s.category)
            if s.source == nil { usage.app = s.app }
            usage.duration += s.duration; apps[s.app.bundleID] = usage
            categories[s.category, default: 0] += s.duration
            var cursor = s.start
            while cursor < s.end {
                guard let hour = calendar.dateInterval(of: .hour, for: cursor), hour.end > cursor else { break }
                let stop = min(hour.end, s.end)
                let duration = stop.timeIntervalSince(cursor)
                hours[hour.start, default: 0] += duration
                hourOfDay[calendar.component(.hour, from: cursor), default: 0] += duration
                cursor = stop
            }
        }
        let sortedApps = apps.values.sorted { $0.duration == $1.duration ? $0.id < $1.id : $0.duration > $1.duration }
        let categoryValues: [CategoryUsage] = categories.map { CategoryUsage(category: $0.key, duration: $0.value) }
        let sortedCategories = categoryValues.sorted { left, right in
            if left.duration == right.duration { return left.category < right.category }
            return left.duration > right.duration
        }
        let total = sessions.reduce(0) { $0 + $1.duration }
        let night = hourOfDay.filter { $0.key >= 22 || $0.key < 5 }.values.reduce(0, +)
        let peak = hourOfDay.keys.sorted { hourOfDay[$0]! == hourOfDay[$1]! ? $0 < $1 : hourOfDay[$0]! > hourOfDay[$1]! }.first
        var personality = "The All-Rounder"
        var reason = "No single category dominates this period."
        if total == 0 { personality = "Your story is just beginning"; reason = "Import app usage to discover your recap theme." }
        else if night / total >= 0.3 { personality = "The After-Hours Mind"; reason = "At least 30% of your time fell between 10 PM and 5 AM." }
        else if Double(switches) / max(total / 3600, 1) >= 12 { personality = "The Fast Switcher"; reason = "You averaged at least 12 app switches per tracked hour (minimum one-hour denominator)." }
        else if (categories["Development"] ?? 0) / total >= 0.4 { personality = "The Code Architect"; reason = "Development accounted for at least 40% of your app usage." }
        else if (categories["Design"] ?? 0) / total >= 0.3 { personality = "The Creative Mind"; reason = "Design accounted for at least 30% of your app usage." }
        else if (categories["Browsing"] ?? 0) / total >= 0.4 { personality = "The Web Explorer"; reason = "Browsing accounted for at least 40% of your app usage." }
        return ActivityReport(interval: interval, sessions: sessions.sorted { $0.start < $1.start }, apps: sortedApps, categories: sortedCategories, hours: hours.map { HourUsage(start: $0.key, duration: $0.value) }.sorted { $0.start < $1.start }, total: total, switches: switches, longest: sessions.map(\.duration).max() ?? 0, peakHour: peak, personality: personality, personalityReason: reason)
    }
}

public enum DisplayFormat {
    public static func recapDates(_ interval: DateInterval, calendar: Calendar = .current) -> String {
        let end = max(interval.start, interval.end.addingTimeInterval(-1))
        let sameYear = calendar.isDate(interval.start, equalTo: end, toGranularity: .year)
        var day = Date.FormatStyle.dateTime.month(.abbreviated).day()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        return (sameYear ? interval.start.formatted(day) : interval.start.formatted(day.year())) + " – " + end.formatted(day.year())
    }

    public static func duration(_ seconds: Double) -> String {
        let minutes = max(0, Int(seconds / 60))
        if seconds > 0 && minutes == 0 { return "<1m" }
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
    public static func hour(_ hour: Int?) -> String {
        guard let hour else { return "—" }
        return String(format: "%02d:00–%02d:00", hour, (hour + 1) % 24)
    }
}

public enum ActivityExport {
    public static func json(_ sessions: [ActivitySession]) throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(sessions)
    }
    public static func csv(_ sessions: [ActivitySession]) -> Data {
        let iso = ISO8601DateFormatter()
        func escape(_ value: String) -> String {
            // Avoid spreadsheet formula execution when opening arbitrary application names.
            let safe = ["=", "+", "-", "@", "\t", "\r"].contains(where: value.hasPrefix) ? "'" + value : value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let rows = sessions.map { s in
            [s.id.uuidString, s.app.bundleID, s.app.name, iso.string(from: s.start), iso.string(from: s.end), String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), s.duration), s.category, s.source?.rawValue ?? "rewindMac"].map(escape).joined(separator: ",")
        }
        return Data((["session_id,bundle_identifier,application,start_utc,end_utc,duration_seconds,category,source"] + rows).joined(separator: "\r\n").utf8)
    }
}
