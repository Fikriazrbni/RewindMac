import SwiftUI
import AppKit
import UniformTypeIdentifiers
import RewindCore

struct ShareRecap: Identifiable {
    let id = UUID()
    let report: ActivityReport
    let range: RecapRange
    let demo: Bool
}

struct SharePosterPreview: View {
    let poster: SharePoster
    let width: CGFloat
    var body: some View {
        let scale = width / poster.format.size.width
        poster.scaleEffect(scale)
            .frame(width: width, height: poster.format.size.height * scale)
            .clipped()
    }
}

struct ShareRecapView: View {
    let recap: ShareRecap
    @Environment(\.dismiss) private var dismiss
    @ViewState<PosterFormat> private var format = .story
    @ViewState<PosterTemplate> private var template = .classic
    @ViewState<PosterTheme> private var theme = .aurora
    @ViewState<PosterFooter> private var footer = .none
    @ViewState<String> private var footerText = ""
    @ViewState<String?> private var macModel: String?
    @ViewState<Bool> private var didReadMacModel = false
    @ViewState<Bool> private var showApps = true
    @ViewState<Bool> private var showAppleGlass = false
    @ViewState<String?> private var exportError: String? = nil
    private var poster: SharePoster {
        SharePoster(report: recap.report, range: recap.range, demo: recap.demo, format: format, theme: theme, showApps: showApps, template: template, showAppleGlass: showAppleGlass, footer: footer, footerText: footerText, macModel: macModel)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            SharePosterPreview(poster: poster, width: 252)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .frame(height: 448)
            VStack(alignment: .leading, spacing: 16) {
                Label("Share recap", systemImage: "square.and.arrow.up").font(.title.bold())
                Text(DisplayFormat.recapDates(recap.report.interval)).foregroundStyle(.secondary)
                Picker("Format", selection: $format) {
                    ForEach(PosterFormat.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Template", selection: $template) {
                    ForEach(PosterTemplate.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Theme", selection: $theme) {
                    ForEach(PosterTheme.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Footer", selection: $footer) {
                    ForEach(PosterFooter.allCases) { Text($0.rawValue).tag($0) }
                }
                if footer == .custom {
                    TextField("Your note", text: $footerText, axis: .vertical)
                        .lineLimit(1...2)
                }
                if footer == .macModel && macModel == nil {
                    Text(didReadMacModel ? "Mac model unavailable" : "Reading Mac model…")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Show Apple logo", isOn: $showAppleGlass)
                if template != .stats || footer == .icons {
                    Toggle(template == .stats ? "Show app icons" : "Show apps", isOn: $showApps)
                }
                Text("\(Int(format.size.width * 2)) × \(Int(format.size.height * 2)) PNG").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if let exportError { Text(exportError).font(.caption).foregroundStyle(.red) }
                HStack {
                    Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Save PNG…", action: save).keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                        .disabled(footer == .macModel && macModel == nil)
                }
            }.frame(width: 240, alignment: .leading)
        }.padding(28)
        .task(id: footer) {
            guard footer == .macModel, !didReadMacModel else { return }
            let label = await Task.detached(priority: .userInitiated) { MacHardware.posterLabel }.value
            macModel = label
            didReadMacModel = true
        }
    }

    private func save() {
        exportError = nil
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.string(from: recap.report.interval.start)
        let export = poster
        let themeLabel = theme.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
        panel.nameFieldStringValue = "RewindMac-\(recap.demo ? "DEMO-" : "")\(format.fileLabel)-\(template.fileLabel)-\(themeLabel)-\(start).png"
        // Keep the composer available to export more than one variation.
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do { try RecapExporter.png(poster: export).write(to: url, options: .atomic) }
            catch { exportError = "Could not save PNG: \(error.localizedDescription)" }
        }
    }
}
