import AppKit
import SwiftUI
import ServiceManagement
import RewindCore

@MainActor @Observable
final class AppModel {
    var preferences = Preferences()
    var isReady = false
    var error: String?
    var demo = false
    var report = ActivityReport.empty()
    var todayReport = ActivityReport.empty()
    var weekReport = ActivityReport.empty()
    private var recapSnapshot: RecapSnapshot?
    var wrappedReport: ActivityReport? {
        guard let recapSnapshot, recapSnapshot.range == recapRange,
              recapSnapshot.demo == demo else { return nil }
        return recapSnapshot.report
    }
    var knownApps: [AppIdentity] = []
    var filter: TimeFilter = .today
    var customStart = Calendar.current.startOfDay(for: Date())
    var customEnd = Date()
    var recapRange: RecapRange = .preset(.sevenDays, periodsBack: 0)
    var timelineDay = Calendar.current.startOfDay(for: Date())
    var refreshing = false
    var loginStatus = SMAppService.mainApp.status
    var storagePath = ""
    @ObservationIgnored private var store: ActivityStore?
    @ObservationIgnored private var writeTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var revision = 0
    var colorScheme: ColorScheme? { preferences.appearance == "Dark" ? .dark : preferences.appearance == "Light" ? .light : nil }
    var categories: [String] { Categories.defaults + preferences.customCategories.filter { !Categories.defaults.contains($0) } }

    init() { Task { await initialize() } }
    private func initialize() async {
        do {
            var directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("RewindMac", isDirectory: true)
            #if DEBUG
            if let index = CommandLine.arguments.firstIndex(of: "--validation-directory"), CommandLine.arguments.indices.contains(index + 1) {
                directory = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
            }
            #endif
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            storagePath = directory.appendingPathComponent("activity.sqlite").path
            let databasePath = storagePath
            let database = try await Task.detached { try ActivityStore(path: databasePath) }.value
            store = database
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: databasePath)
            preferences = try await database.loadPreferences()
            isReady = true
            await refresh()
        } catch { self.error = "Could not load RewindMac: \(error.localizedDescription)" }
    }

    func setDemo(_ enabled: Bool) {
        demo = enabled
        if enabled {
            filter = .sevenDays
            timelineDay = Calendar.current.startOfDay(for: DemoData.sessions().last?.start ?? Date())
        }
        requestRefresh()
    }
    func savePreferences() {
        let value = preferences
        enqueue { store in try await store.savePreferences(value) }
        requestRefresh()
    }
    func changeCategory(_ category: String, for app: AppIdentity) {
        preferences.assignments[app.bundleID] = category; savePreferences()
    }
    func setExcluded(_ excluded: Bool, for bundle: String) {
        if excluded { preferences.excluded.insert(bundle) } else { preferences.excluded.remove(bundle) }
        savePreferences()
    }
    func chooseExcludedApp() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.prompt = "Exclude app"
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url)?.bundleIdentifier else { return }
        setExcluded(true, for: bundle)
    }

    func previewScreenTime(_ candidates: [ActivitySession], interval: DateInterval) async throws -> [ActivitySession] {
        guard let store, isReady else { throw StorageError(message: "RewindMac’s history is still loading.") }
        await writeTask?.value
        return try await store.previewScreenTime(candidates, interval: interval, preferences: preferences)
    }

    func importScreenTime(_ candidates: [ActivitySession], interval: DateInterval) async throws -> [ActivitySession] {
        guard let store, isReady else { throw StorageError(message: "RewindMac’s history is still loading.") }
        await writeTask?.value
        let sessions = try await store.importScreenTime(candidates, interval: interval, preferences: preferences)
        if !sessions.isEmpty { setDemo(false) }
        return sessions
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginStatus = SMAppService.mainApp.status
        } catch { self.error = "Launch at login: \(error.localizedDescription)"; loginStatus = SMAppService.mainApp.status }
    }
    func deleteAll() {
        enqueue { store in try await store.deleteAll() }
        requestRefresh()
    }
    func exportData(json: Bool) {
        let panel = NSSavePanel(); panel.allowedContentTypes = json ? [.json] : [.commaSeparatedText]
        panel.nameFieldStringValue = "RewindMac-\(demo ? "DEMO-" : "")activity.\(json ? "json" : "csv")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let useDemo = demo, settings = preferences
        Task {
            await writeTask?.value
            do {
                guard let store else { return }
                let sessions: [ActivitySession]
                if useDemo { sessions = DemoData.sessions() } else { sessions = try await store.sessions(preferences: settings) }
                try await Task.detached {
                    let data = json ? try ActivityExport.json(sessions) : ActivityExport.csv(sessions)
                    try data.write(to: url, options: .atomic)
                }.value
            } catch { self.error = "Export failed: \(error.localizedDescription)" }
        }
    }
    func requestRefresh() {
        revision += 1
        refreshTask?.cancel()
        refreshTask = Task { await refresh() }
    }
    func refresh() async {
        guard let store else { return }
        let generation = revision
        refreshing = true
        await writeTask?.value
        let now = Date(), calendar = Calendar.current, settings = preferences
        let selected = filter.interval(now: now, start: customStart, end: customEnd, calendar: calendar)
        let today = calendar.dateInterval(of: .day, for: now)!
        let week = Analytics.week(containing: now, calendar: calendar)
        let range = recapRange, useDemo = demo
        let wrapped = range.interval(endingNear: now, calendar: calendar)
        do {
            let reports: [ActivityReport]
            if useDemo {
                reports = await Task.detached {
                    var sessions = DemoData.sessions(now: now, calendar: calendar)
                    for i in sessions.indices { sessions[i].category = settings.category(for: sessions[i].app.bundleID) }
                    return [selected, today, week, wrapped].map { Analytics.report(sessions: sessions, interval: $0, calendar: calendar) }
                }.value
            } else {
                // Sequential calls stay on the storage actor; indexed range scans avoid loading all history.
                var values: [ActivityReport] = []
                for interval in [selected, today, week, wrapped] { values.append(try await store.report(in: interval, preferences: settings, calendar: calendar, screenTimeOnly: true)) }
                reports = values
            }
            let apps = try await store.knownApps(screenTimeOnly: true)
            guard !Task.isCancelled, generation == revision else { return }
            report = reports[0]; todayReport = reports[1]; weekReport = reports[2]
            recapSnapshot = RecapSnapshot(range: range, demo: useDemo, report: reports[3])
            knownApps = apps
            if demo { knownApps = Array(Set(apps + DemoData.sessions().map(\.app))).sorted { $0.name < $1.name } }
            if timelineDay < selected.start || timelineDay >= selected.end { timelineDay = calendar.startOfDay(for: selected.start) }
            refreshing = false
        } catch { if !Task.isCancelled { self.error = "Could not read activity: \(error.localizedDescription)"; refreshing = false } }
    }
    private func enqueue(_ operation: @escaping @Sendable (ActivityStore) async throws -> Void) {
        guard let store else { return }
        let previous = writeTask
        writeTask = Task { [weak self] in
            await previous?.value
            do { try await operation(store) }
            catch { self?.error = "Could not save changes: \(error.localizedDescription)" }
        }
    }

    func shutdown() async {
        await writeTask?.value
    }
}

enum TimeFilter: String, CaseIterable, Identifiable {
    case today = "Today", yesterday = "Yesterday", sevenDays = "Last 7 days", month = "This month", custom = "Custom range"
    var id: String { rawValue }
    func interval(now: Date, start: Date, end: Date, calendar: Calendar) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .today: return calendar.dateInterval(of: .day, for: now)!
        case .yesterday: return DateInterval(start: calendar.date(byAdding: .day, value: -1, to: today)!, end: today)
        case .sevenDays: return DateInterval(start: calendar.date(byAdding: .day, value: -6, to: today)!, end: calendar.date(byAdding: .day, value: 1, to: today)!)
        case .month: return calendar.dateInterval(of: .month, for: now)!
        case .custom:
            return RecapRange.custom(from: start, through: end).interval(endingNear: now, calendar: calendar)
        }
    }
}

private struct RecapSnapshot {
    let range: RecapRange
    let demo: Bool
    let report: ActivityReport
}
