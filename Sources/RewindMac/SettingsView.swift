import SwiftUI
import AppKit
import ServiceManagement
import RewindCore

struct SettingsView: View {
    @Bindable var model: AppModel
    @ViewState<Bool> private var confirmDelete = false
    @ViewState<Bool> private var showScreenTimeImport = false
    @ViewState<String> private var customCategory = ""
    @ViewState<String> private var excludedBundle = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Make it yours.").font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("A few preferences. Complete control.").foregroundStyle(.secondary)
                }
                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeading(title: "Appearance & startup")
                        Picker("Appearance", selection: $model.preferences.appearance) {
                            ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
                        }.onChange(of: model.preferences.appearance) { model.savePreferences() }
                        Toggle("Launch RewindMac at login", isOn: Binding(get: { model.loginStatus == .enabled || model.loginStatus == .requiresApproval }, set: { model.setLogin($0) }))
                        if model.loginStatus == .requiresApproval {
                            Button("Approve in System Settings…") { SMAppService.openSystemSettingsLoginItems() }
                        }
                        Text("Launch at login works from an installed app bundle.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "Applications & categories", subtitle: "Category changes apply to your entire history. Exclusions apply to future imports.")
                        if model.knownApps.isEmpty { Text("Your apps appear here after you import Screen Time.").font(.caption).foregroundStyle(.secondary) }
                        ForEach(model.knownApps) { app in
                            HStack {
                                AppIcon(app: app, size: 26)
                                VStack(alignment: .leading, spacing: 2) { Text(app.name).font(.system(size: 12)); Text(app.bundleID).font(.system(size: 9)).foregroundStyle(.tertiary).lineLimit(1) }
                                Spacer()
                                Picker("Category for \(app.name)", selection: Binding(get: { model.preferences.category(for: app.bundleID) }, set: { model.changeCategory($0, for: app) })) {
                                    ForEach(model.categories, id: \.self) { Text($0).tag($0) }
                                }.labelsHidden().frame(width: 145)
                                Toggle("Exclude", isOn: Binding(get: { model.preferences.excluded.contains(app.bundleID) }, set: { model.setExcluded($0, for: app.bundleID) })).font(.caption).toggleStyle(.checkbox)
                            }
                        }
                        Divider()
                        HStack {
                            TextField("New category name", text: $customCategory)
                            Button("Add category") {
                                let name = customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !name.isEmpty && !model.categories.contains(name) { model.preferences.customCategories.append(name); model.savePreferences() }
                                customCategory = ""
                            }.disabled(customCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        HStack {
                            TextField("Exclude by bundle ID (com.example.app)", text: $excludedBundle)
                            Button("Exclude") { model.setExcluded(true, for: excludedBundle.trimmingCharacters(in: .whitespacesAndNewlines)); excludedBundle = "" }.disabled(!excludedBundle.contains("."))
                            Button("Choose app…") { model.chooseExcludedApp() }
                        }
                        ForEach(model.preferences.excluded.sorted(), id: \.self) { bundle in
                            HStack { Label(bundle, systemImage: "eye.slash").font(.caption); Spacer(); Button("Remove exclusion") { model.setExcluded(false, for: bundle) }.font(.caption) }
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "Your data stays yours")
                        Text("Imported app usage is kept on this Mac until you delete it.").font(.caption).foregroundStyle(.secondary)
                        Button("Import Screen Time…", systemImage: "clock.arrow.circlepath") {
                            showScreenTimeImport = true
                        }.disabled(!model.isReady)
                        HStack {
                            Button("Export \(model.demo ? "demo " : "")CSV…") { model.exportData(json: false) }
                            Button("Export \(model.demo ? "demo " : "")JSON…") { model.exportData(json: true) }
                            Spacer()
                            Button("Delete saved activity…", role: .destructive) { confirmDelete = true }
                        }
                        Toggle("Explore demo mode", isOn: Binding(get: { model.demo }, set: { model.setDemo($0) }))
                        Text("Demo data is generated in memory and never added to your history.").font(.caption).foregroundStyle(.secondary)
                        Divider()
                        Label("No screenshots, keystrokes, clipboard, URLs, titles, or document contents.", systemImage: "lock.shield").font(.caption)
                        Text("RewindMac stores application names, bundle identifiers, start/end timestamps and categories in SQLite on this Mac. Screen Time imports run when you request them. CSV and JSON exports include any activity saved by older versions.").font(.caption).foregroundStyle(.secondary)
                        Text(model.storagePath).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary).textSelection(.enabled)
                    }
                }
            }.padding(28)
        }
        .sheet(isPresented: $showScreenTimeImport) { ScreenTimeImportView(model: model) }
        .confirmationDialog("Delete all saved activity?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete all activity", role: .destructive) { model.deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This permanently removes all saved activity from RewindMac, including older records. Your macOS Screen Time history stays available to import.") }
    }
}
