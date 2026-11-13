import Foundation

public enum Categories {
    public static let defaults = ["Development", "Communication", "Browsing", "Entertainment", "Design", "Productivity", "Other"]
    public static func suggested(for bundle: String) -> String {
        let b = bundle.lowercased()
        if ["xcode", "vscode", "terminal", "iterm", "jetbrains", "sublime", "zed"].contains(where: b.contains) { return "Development" }
        if ["slack", "mail", "messages", "discord", "zoom", "teams", "facetime"].contains(where: b.contains) { return "Communication" }
        if ["safari", "chrome", "firefox", "arc", "brave", "edge"].contains(where: b.contains) { return "Browsing" }
        if ["figma", "sketch", "photoshop", "illustrator", "affinity"].contains(where: b.contains) { return "Design" }
        if ["spotify", "music", "tv", "vlc", "steam"].contains(where: b.contains) { return "Entertainment" }
        if ["notes", "notion", "pages", "numbers", "keynote", "calendar", "obsidian", "finder"].contains(where: b.contains) { return "Productivity" }
        return "Other"
    }
}

public struct AppIdentity: Codable, Hashable, Sendable, Identifiable {
    public var id: String { bundleID }
    public var bundleID: String
    public var name: String
    public init(_ bundleID: String, _ name: String) { self.bundleID = bundleID; self.name = name }
}

public enum ActivitySource: String, Codable, Sendable {
    case screenTime
}

public struct ActivitySession: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var app: AppIdentity
    public var start: Date
    public var end: Date
    public var category: String
    public var isOpen: Bool
    /// True only for an observed foreground app change, never for polling/checkpoints.
    public var beganWithSwitch: Bool
    /// Missing in older exports and in sessions recorded by RewindMac.
    public var source: ActivitySource?
    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    public init(id: UUID = UUID(), app: AppIdentity, start: Date, end: Date, category: String? = nil, isOpen: Bool = false, beganWithSwitch: Bool = false, source: ActivitySource? = nil) {
        self.id = id; self.app = app; self.start = start; self.end = end
        self.category = category ?? Categories.suggested(for: app.bundleID)
        self.isOpen = isOpen; self.beganWithSwitch = beganWithSwitch
        self.source = source
    }
}

public struct Preferences: Codable, Equatable, Sendable {
    public var consent = false
    public var trackingEnabled = false
    public var idleMinutes = 5
    public var retentionDays = 90 // 0 means forever
    public var appearance = "System"
    public var excluded: Set<String> = []
    public var assignments: [String: String] = [:]
    public var customCategories: [String] = []
    public init() {}
    public func category(for bundle: String) -> String { assignments[bundle] ?? Categories.suggested(for: bundle) }
}

public enum SessionMutation: Sendable {
    case save(ActivitySession)
    case trim(after: Date)
}

public struct ClockSample: Sendable {
    public let date: Date
    public let uptime: TimeInterval
    public init(_ date: Date, uptime: TimeInterval) { self.date = date; self.uptime = uptime }
}

public enum TrackingStatus: String, Sendable {
    case off = "Tracking is off", recording = "Tracking", paused = "Paused", idle = "Idle", sleeping = "Mac asleep", inactive = "Session inactive", excluded = "App excluded", unavailable = "No foreground app", clockChanged = "Waiting for clock"
}
