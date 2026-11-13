import SwiftUI
import AppKit
import RewindCore

struct MenuBarView: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RewindLogo(size: 18)
                Text("RewindMac").font(.headline)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(DisplayFormat.duration(model.todayReport.total)).font(.system(size: 35, weight: .semibold, design: .rounded))
                Text(model.demo ? "Demo app usage today" : "Saved Screen Time today").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            ForEach(model.todayReport.apps.prefix(3)) { usage in
                HStack { AppIcon(app: usage.app, size: 25); Text(usage.app.name).font(.caption); Spacer(); Text(DisplayFormat.duration(usage.duration)).font(.caption).foregroundStyle(.secondary) }
            }
            if model.todayReport.apps.isEmpty {
                Text("Import Screen Time from the dashboard.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Open Dashboard") { openWindow(id: "dashboard"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button { openSettings(); NSApp.activate(ignoringOtherApps: true) } label: { Image(systemName: "gearshape") }.help("Settings")
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.help("Quit RewindMac")
            }.buttonStyle(.plain).font(.caption)
        }.padding(20).frame(width: 320)
    }
}
