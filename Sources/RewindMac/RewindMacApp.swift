import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?
    private var terminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let iconFile = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String else { return }
        let resource = iconFile as NSString
        let extensionName = resource.pathExtension
        let name = extensionName.isEmpty ? iconFile : resource.deletingPathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: extensionName.isEmpty ? "icns" : extensionName),
              let icon = NSImage(contentsOf: url) else { return }
        // Read the bundled artwork directly so an in-place upgrade can refresh the running Dock tile.
        NSApp.applicationIconImage = icon
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating, let model else { return .terminateNow }
        terminating = true
        Task { await model.shutdown(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
@main
struct RewindMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ViewState<AppModel> private var model = AppModel()
    var body: some Scene {
        Window("RewindMac", id: "dashboard") {
            RootView(model: model)
                .preferredColorScheme(model.colorScheme)
                .onAppear { delegate.model = model }
        }
        .defaultSize(width: 1180, height: 820)
        .windowResizability(.contentMinSize)
        MenuBarExtra {
            MenuBarView(model: model).preferredColorScheme(model.colorScheme)
        } label: {
            Image(nsImage: RewindLogo.menuImage)
                .accessibilityLabel("RewindMac")
        }.menuBarExtraStyle(.window)
        Settings {
            SettingsView(model: model).frame(width: 680, height: 660).preferredColorScheme(model.colorScheme)
        }
    }
}

private enum Destination: String, CaseIterable {
    case overview = "Overview", wrapped = "Wrapped", settings = "Settings"
    var icon: String { switch self { case .overview: "square.grid.2x2"; case .wrapped: "sparkles"; case .settings: "slider.horizontal.3" } }
}
struct RootView: View {
    @Bindable var model: AppModel
    @ViewState<Destination> private var destination: Destination = .overview
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                if model.demo {
                    HStack {
                        Label("DEMO MODE", systemImage: "sparkles").font(.system(size: 10, weight: .bold)).tracking(1)
                        Text("Sample activity · never saved to your history").font(.system(size: 11))
                        Spacer()
                        Button("Return to my data") { model.setDemo(false) }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
                    }.padding(.horizontal, 28).padding(.vertical, 10).background(Palette.accent.opacity(0.12))
                }
                if !model.isReady {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(model.error ?? "Opening your local history…").foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch destination {
                    case .overview: DashboardView(model: model, openWrapped: { destination = .wrapped })
                    case .wrapped: WrappedView(model: model)
                    case .settings: SettingsView(model: model)
                    }
                }
                if let error = model.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(error).font(.caption).textSelection(.enabled)
                        Spacer()
                        Button("Dismiss") { model.error = nil }
                    }.padding(12).background(.orange.opacity(0.09))
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }.frame(minWidth: 940, minHeight: 680)
            .tint(Palette.accent)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RewindLogo(size: 39, badge: true)
                Text("RewindMac").font(.system(size: 18, weight: .bold, design: .rounded))
            }.padding(.bottom, 8)
            Text("YOUR MAC LIFE, REPLAYED.").font(.system(size: 8, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary)
                .padding(.bottom, 38)
            Text("YOUR SPACE").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(.tertiary).padding(.bottom, 12)
            ForEach(Destination.allCases, id: \.self) { page in
                Button { destination = page } label: {
                    HStack(spacing: 10) {
                        Image(systemName: page.icon).frame(width: 18)
                        Text(page.rawValue).font(.system(size: 12, weight: destination == page ? .semibold : .medium))
                        Spacer()
                    }.padding(12).contentShape(Rectangle())
                        .background(destination == page ? Palette.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(destination == page ? Palette.accent : .secondary)
                }.buttonStyle(.plain).padding(.bottom, 4)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "lock.shield").font(.system(size: 19)).foregroundStyle(Palette.mint)
                Text("Your time. Your business.").font(.system(size: 11, weight: .semibold))
                Text("Stored on this Mac.\nNo accounts. No uploads.").font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(3)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))

        }.padding(20).frame(width: 210).background(.background.opacity(0.55))
    }
}
