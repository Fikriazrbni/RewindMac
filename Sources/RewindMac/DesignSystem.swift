import SwiftUI
import AppKit
import RewindCore

// Explicit type alias selects the macOS 14 property wrapper, including on SDKs
// that also expose a same-named State macro unavailable in Command Line Tools.
typealias ViewState<Value> = SwiftUI.State<Value>

enum Palette {
    static let accent = Color(red: 0.51, green: 0.40, blue: 0.96)
    static let mint = Color(red: 0.32, green: 0.78, blue: 0.64)
    static func category(_ name: String) -> Color {
        switch name {
        case "Development": return Color(red: 0.56, green: 0.47, blue: 0.97)
        case "Communication": return Color(red: 0.95, green: 0.65, blue: 0.34)
        case "Browsing": return Color(red: 0.32, green: 0.68, blue: 0.91)
        case "Entertainment": return Color(red: 0.90, green: 0.44, blue: 0.66)
        case "Design": return Color(red: 0.34, green: 0.76, blue: 0.63)
        case "Productivity": return Color(red: 0.79, green: 0.72, blue: 0.36)
        default: return Color(red: 0.56, green: 0.61, blue: 0.69)
        }
    }
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.065)))
    }
}
struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 16, weight: .semibold))
            if let subtitle { Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary) }
        }
    }
}
@MainActor
struct AppIcon: View {
    let app: AppIdentity
    var size: CGFloat = 34
    private static var cache: [String: NSImage] = [:]
    private var icon: NSImage? {
        if let image = Self.cache[app.bundleID] { return image }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        Self.cache[app.bundleID] = image; return image
    }
    var body: some View {
        Group {
            if let icon { Image(nsImage: icon).resizable().interpolation(.high) }
            else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.23).fill(Palette.category(Categories.suggested(for: app.bundleID)).gradient)
                    Text(String(app.name.prefix(1))).font(.system(size: size * 0.48, weight: .bold)).foregroundStyle(.white)
                }
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}
struct EmptyActivity: View {
    let model: AppModel
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 42, weight: .light)).foregroundStyle(Palette.accent)
            Text("A little time makes a great story.").font(.title2.bold())
            Text("Import Screen Time or choose a date range with saved activity.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Explore demo data") { model.setDemo(true) }.buttonStyle(.borderedProminent).tint(Palette.accent)
        }.frame(maxWidth: .infinity).padding(.vertical, 65)
    }
}
