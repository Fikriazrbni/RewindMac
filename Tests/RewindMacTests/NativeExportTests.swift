import Foundation
import AppKit
import Testing
import RewindCore
@testable import RewindMac

struct NativeExportTests {
    @MainActor @Test func recapUsesPortablePNGForStoryAndFeed() throws {
        _ = NSApplication.shared
        let now = ISO8601DateFormatter().date(from: "2026-11-13T10:00:00Z")!
        let range = RecapRange.preset(.oneYear, periodsBack: 0)
        let report = Analytics.report(sessions: DemoData.sessions(now: now), interval: range.interval(endingNear: now))
        #expect(report.total > 0)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let variants: [(PosterFormat, PosterTheme, PosterTemplate, Bool, String)] = [
            (.story, .aurora, .classic, true, "story"),
            (.feed, .seaGlass, .classic, true, "feed"),
            (.feed, .dayglow, .classic, false, "categories"),
            (.story, .graphite, .rankings, true, "graphite-top-five-story"),
            (.feed, .graphite, .rankings, true, "graphite-top-five-feed"),
            (.story, .ultraviolet, .spotlight, true, "ultraviolet-spotlight-story"),
            (.feed, .ultraviolet, .spotlight, false, "ultraviolet-spotlight-feed"),
            (.story, .ember, .stats, true, "ember-stats-story"),
            (.feed, .ember, .stats, true, "ember-stats-feed")
        ]
        for (format, theme, template, showApps, variant) in variants {
            let poster = SharePoster(report: report, range: range, demo: true, format: format, theme: theme, showApps: showApps, template: template)
            let data = try RecapExporter.png(poster: poster)
            let image = try #require(NSBitmapImageRep(data: data))
            #expect(image.pixelsWide == 1080)
            #expect(image.pixelsHigh == (format == .story ? 1920 : 1350))
            #expect(image.bitsPerSample == 8)
            #expect(image.colorSpace == .sRGB)
            try data.write(to: root.appendingPathComponent(".build/QA-recap-\(variant).png"))
        }
        for format in PosterFormat.allCases {
            let poster = SharePoster(report: report, range: range, demo: true, format: format, theme: .graphite, showApps: true, showAppleGlass: true)
            let data = try RecapExporter.png(poster: poster)
            let image = try #require(NSBitmapImageRep(data: data))
            #expect(image.pixelsHigh == (format == .story ? 1920 : 1350))
            try data.write(to: root.appendingPathComponent(".build/QA-apple-glass-\(format.fileLabel).png"))
        }
        for format in PosterFormat.allCases {
            for footer in PosterFooter.allCases {
                let poster = SharePoster(report: report, range: range, demo: true, format: format, theme: .aurora, showApps: false, template: .classic, footer: footer, footerText: "Made on my Mac", macModel: "MacBook Air · M4")
                let data = try RecapExporter.png(poster: poster)
                let image = try #require(NSBitmapImageRep(data: data))
                #expect(image.pixelsWide == 1080)
                #expect(image.pixelsHigh == (format == .story ? 1920 : 1350))
                try data.write(to: root.appendingPathComponent(".build/QA-footer-\(footer.rawValue.replacingOccurrences(of: " ", with: "-").lowercased())-\(format.fileLabel).png"))
            }
        }
    }
}
