import AppKit
import SwiftUI
import UniformTypeIdentifiers
import RewindCore

struct ScreenTimeImportView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ViewState<Preview?> private var preview: Preview?
    @ViewState<Bool> private var busy = false
    @ViewState<String?> private var status: String?
    @ViewState<Bool> private var needsFullDiskAccess = false
    @ViewState<DateInterval?> private var availableHistory: DateInterval?
    @ViewState<Bool> private var showFilePicker = false

    private struct Preview {
        let candidates: [ActivitySession]
        let interval: DateInterval
        let sessions: [ActivitySession]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Import Screen Time", systemImage: "clock.arrow.circlepath")
                .font(.title2.bold())
            Text("Read the app usage still available on this Mac and add it to your local history.")
                .fixedSize(horizontal: false, vertical: true)
            Text("For live history, give RewindMac Full Disk Access in System Settings, then quit and reopen the app. You can also choose a KnowledgeC backup.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Read This Mac") { load(file: nil) }.buttonStyle(.borderedProminent)
                Button("Choose KnowledgeC Backup…") { showFilePicker = true }
            }.disabled(busy)

            if busy {
                ProgressView(preview == nil ? "Reading Screen Time…" : "Saving Screen Time…")
                    .controlSize(.small)
            }

            if let availableHistory {
                Label("Source history spans \(DisplayFormat.recapDates(availableHistory))", systemImage: "calendar")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            if let preview {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(DisplayFormat.duration(preview.sessions.reduce(0) { $0 + $1.duration })) ready to import")
                        .font(.headline)
                    if let dates = historySpan(preview.sessions) {
                        Text(DisplayFormat.recapDates(dates))
                            .font(.callout)
                    }
                    Text("\(Set(preview.sessions.map(\.app.bundleID)).count) apps · \(preview.sessions.count) intervals")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if needsFullDiskAccess {
                VStack(alignment: .leading, spacing: 9) {
                    Label("Screen Time access blocked", systemImage: "lock.shield")
                        .font(.headline)
                    Text("In Full Disk Access, add or re-add the current RewindMac app, then quit with ⌘Q and reopen it.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Open Full Disk Access") {
                            let settings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                            if !NSWorkspace.shared.open(settings) {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
                            }
                        }
                        Button("Show RewindMac in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            } else if let status {
                Text(status).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction).disabled(busy)
                if let preview {
                    Button("Import", action: { save(preview) })
                        .buttonStyle(.borderedProminent).disabled(busy)
                }
            }
        }
        .padding(24)
        .frame(width: 520)
        .interactiveDismissDisabled(busy)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.database, .data]) { result in
            switch result {
            case .success(let url): load(file: url)
            case .failure(let error):
                needsFullDiskAccess = false
                status = error.localizedDescription
            }
        }
    }

    private func load(file: URL?) {
        busy = true
        preview = nil
        status = nil
        needsFullDiskAccess = false
        availableHistory = nil
        let interval = DateInterval(start: .distantPast, end: Date())
        Task {
            defer { busy = false }
            do {
                var candidates = try await Task.detached(priority: .userInitiated) {
                    guard let file else { return try ScreenTimeImport.readLocal(in: interval) }
                    let scoped = file.startAccessingSecurityScopedResource()
                    defer { if scoped { file.stopAccessingSecurityScopedResource() } }
                    return try ScreenTimeImport.read(from: file, in: interval)
                }.value
                var names: [String: String] = [:]
                for index in candidates.indices {
                    let id = candidates[index].app.bundleID
                    if names[id] == nil {
                        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map {
                            FileManager.default.displayName(atPath: $0.path)
                        }
                        names[id] = name.map { $0.hasSuffix(".app") ? String($0.dropLast(4)) : $0 } ?? id
                    }
                    candidates[index].app.name = names[id] ?? id
                }
                availableHistory = historySpan(candidates)
                guard availableHistory != nil else {
                    status = "No local app usage was found in this source."
                    return
                }
                let sessions = try await model.previewScreenTime(candidates, interval: interval)
                guard !sessions.isEmpty else {
                    status = "No new usage to import. The available usage is already saved or excluded by your settings."
                    return
                }
                preview = Preview(candidates: candidates, interval: interval, sessions: sessions)
            } catch ScreenTimeReadError.accessDenied where file == nil {
                needsFullDiskAccess = true
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func historySpan(_ sessions: [ActivitySession]) -> DateInterval? {
        guard let start = sessions.map(\.start).min(), let end = sessions.map(\.end).max() else { return nil }
        return DateInterval(start: start, end: end)
    }

    private func save(_ preview: Preview) {
        busy = true
        status = nil
        Task {
            defer { busy = false }
            do {
                let saved = try await model.importScreenTime(preview.candidates, interval: preview.interval)
                self.preview = nil
                status = saved.isEmpty
                    ? "No new usage to import."
                    : "Imported \(DisplayFormat.duration(saved.reduce(0) { $0 + $1.duration })) from Screen Time. Open Wrapped and select a period that includes those dates."
            } catch {
                status = error.localizedDescription
            }
        }
    }
}
