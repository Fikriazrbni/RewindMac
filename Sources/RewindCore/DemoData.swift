import Foundation

public enum DemoData {
    /// Deterministic, memory-only fixtures. Never sent to ActivityStore.
    public static func sessions(now: Date = Date(), calendar: Calendar = .current) -> [ActivitySession] {
        let apps = [AppIdentity("com.apple.dt.Xcode", "Xcode"), AppIdentity("com.apple.Safari", "Safari"), AppIdentity("com.tinyspeck.slackmacgap", "Slack"), AppIdentity("com.figma.Desktop", "Figma"), AppIdentity("com.apple.Notes", "Notes"), AppIdentity("com.apple.Terminal", "Terminal")]
        var result: [ActivitySession] = []
        let today = calendar.startOfDay(for: now)
        for day in 0..<366 {
            let date = calendar.date(byAdding: .day, value: -day, to: today)!
            let weekend = calendar.isDateInWeekend(date)
            var cursor = calendar.date(bySettingHour: weekend ? 11 : 9, minute: 12, second: 0, of: date)!
            for block in 0..<(weekend ? 6 : 17) {
                let app = apps[(block * 7 + day * 3) % apps.count]
                let end = cursor.addingTimeInterval(Double(12 + ((block * 13 + day * 7) % 35)) * 60)
                if cursor < now {
                    result.append(ActivitySession(app: app, start: cursor, end: min(end, now), beganWithSwitch: block > 0))
                }
                cursor = end.addingTimeInterval(block == 6 ? 3300 : 90)
            }
        }
        return result.sorted { $0.start < $1.start }
    }
}
