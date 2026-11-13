import SwiftUI
import RewindCore

// One point is two pixels in the final PNG.
enum PosterFormat: String, CaseIterable, Identifiable {
    case story = "Story · 9:16"
    case feed = "Feed · 4:5"
    var id: Self { self }
    var size: CGSize { CGSize(width: 540, height: self == .story ? 960 : 675) }
    var fileLabel: String { self == .story ? "story" : "feed" }
}

enum PosterTemplate: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case rankings = "Top Five"
    case spotlight = "Spotlight"
    case stats = "By the Numbers"

    var id: Self { self }
    var fileLabel: String { rawValue.lowercased().replacingOccurrences(of: " ", with: "-") }
}

enum PosterFooter: String, CaseIterable, Identifiable {
    case none = "None"
    case icons = "App icons"
    case persona = "Mac vibe"
    case macModel = "Mac model"
    case custom = "Custom text"

    var id: Self { self }
}

enum PosterTheme: String, CaseIterable, Identifiable {
    case aurora = "Aurora"
    case graphite = "Graphite"
    case ultraviolet = "Ultraviolet"
    case ember = "Ember"
    case seaGlass = "Sea Glass"
    case afterHours = "After Hours"
    case dayglow = "Dayglow"

    var id: Self { self }

    var palette: (ink: Color, accent: Color, base: Color, glow: Color, reflection: Color) {
        switch self {
        case .aurora:
            (Color(red: 0.94, green: 0.97, blue: 1), Color(red: 0.54, green: 1, blue: 0.84),
             Color(red: 0.04, green: 0.08, blue: 0.18), Color(red: 0.13, green: 0.43, blue: 0.48),
             Color(red: 0.37, green: 0.28, blue: 0.75))
        case .graphite:
            (Color(white: 0.97), Color(white: 0.82), Color(white: 0.055), Color(white: 0.39), Color(white: 0.22))
        case .ultraviolet:
            (Color(red: 0.98, green: 0.94, blue: 1), Color(red: 1, green: 0.65, blue: 0.89),
             Color(red: 0.13, green: 0.04, blue: 0.24), Color(red: 0.45, green: 0.19, blue: 0.64),
             Color(red: 0.24, green: 0.28, blue: 0.78))
        case .ember:
            (Color(red: 1, green: 0.95, blue: 0.87), Color(red: 1, green: 0.76, blue: 0.49),
             Color(red: 0.16, green: 0.055, blue: 0.075), Color(red: 0.49, green: 0.20, blue: 0.16),
             Color(red: 0.53, green: 0.13, blue: 0.26))
        case .seaGlass:
            (Color(red: 0.05, green: 0.17, blue: 0.25), Color(red: 0.04, green: 0.31, blue: 0.48),
             Color(red: 0.91, green: 0.98, blue: 0.96), Color(red: 0.57, green: 0.82, blue: 0.91),
             Color(red: 0.53, green: 0.81, blue: 0.73))
        case .afterHours:
            (Color(red: 0.97, green: 0.94, blue: 1), Color(red: 0.83, green: 1, blue: 0.36),
             Color(red: 0.11, green: 0.07, blue: 0.22), Color(red: 0.26, green: 0.14, blue: 0.50),
             Color(red: 0.41, green: 0.20, blue: 0.57))
        case .dayglow:
            (Color(red: 0.13, green: 0.09, blue: 0.14), Color(red: 0.70, green: 0.12, blue: 0.26),
             Color(red: 1, green: 0.91, blue: 0.69), Color(red: 1, green: 0.72, blue: 0.62),
             Color(red: 1, green: 0.64, blue: 0.53))
        }
    }
}

struct SharePoster: View {
    let report: ActivityReport
    let range: RecapRange
    let demo: Bool
    let format: PosterFormat
    let theme: PosterTheme
    let showApps: Bool
    var template: PosterTemplate = .classic
    var showAppleGlass = false
    var footer: PosterFooter = .none
    var footerText = ""
    var macModel: String? = nil

    private var tall: Bool { format == .story }
    private var ink: Color { theme.palette.ink }
    private var accent: Color { theme.palette.accent }
    private struct RankedItem {
        let name: String
        let duration: Double
        let app: AppIdentity?
    }

    private func shareOfUsage(_ item: RankedItem) -> Double {
        report.total > 0 ? item.duration / report.total : 0
    }

    private var ranking: [RankedItem] {
        let limit = template == .rankings ? 5 : 3
        if showApps { return report.apps.prefix(limit).map { RankedItem(name: $0.app.name, duration: $0.duration, app: $0.app) } }
        return report.categories.prefix(limit).map { RankedItem(name: $0.category, duration: $0.duration, app: nil) }
    }
    private var dates: String { DisplayFormat.recapDates(report.interval) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            Spacer(minLength: 16)
            switch template {
            case .classic:
                headline
                Spacer(minLength: 16)
                rankedList
            case .rankings:
                rankingsContent
            case .spotlight:
                if let first = ranking.first { spotlight(first) }
            case .stats:
                statsContent
            }
            if hasFooter {
                Spacer(minLength: 16)
                signoff
            }
        }
        .padding(.horizontal, 42)
        .padding(.top, tall ? 128 : 39)
        .padding(.bottom, tall ? 145 : 39)
        .frame(width: format.size.width, height: format.size.height)
        .foregroundStyle(ink)
        .background { backdrop }
        .clipped()
        .environment(\.colorScheme, .dark)
        .allowedDynamicRange(.standard)
    }

    private var masthead: some View {
        HStack(spacing: 8) {
            RewindLogo(size: 16)
            Text("REWINDMAC").font(.system(size: 12, weight: .black, design: .monospaced)).tracking(3)
            if showAppleGlass {
                Image(systemName: "apple.logo")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(ink.opacity(0.75))
                    .accessibilityLabel("Apple logo")
            }
            Spacer()
            if demo {
                Text("DEMO DATA")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background { Capsule().strokeBorder(ink.opacity(0.45), lineWidth: 1) }
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            dateCaption
            VStack(alignment: .leading, spacing: -7) {
                Text("YOUR MAC.")
                Text("ON REPEAT.").foregroundStyle(accent)
            }
            .font(.system(size: tall ? 70 : 62, weight: .black, design: .default)).tracking(-4)
            .lineLimit(1).minimumScaleFactor(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(DisplayFormat.duration(report.total))
                    .font(.system(size: tall ? 68 : 59, weight: .black, design: .monospaced)).tracking(-5)
                    .lineLimit(1).minimumScaleFactor(0.52)
                Text(report.includesScreenTime ? "RECORDED\nAPP USAGE" : "ESTIMATED\nACTIVE TIME")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced)).tracking(1)
                    .fixedSize(horizontal: true, vertical: false)
            }.padding(.top, 3)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateCaption: some View {
        Text("\(range.title.uppercased())  /  \(dates.uppercased())")
            .font(.system(size: 12, weight: .semibold, design: .monospaced)).tracking(1)
            .lineLimit(1).minimumScaleFactor(0.75)
    }

    private var rankingsContent: some View {
        VStack(alignment: .leading, spacing: tall ? 17 : 12) {
            dateCaption
            Text(showApps ? "Top apps." : "Top categories.")
                .font(.system(size: 62, weight: .black)).tracking(-3)
                .lineLimit(1).minimumScaleFactor(0.60)
            ForEach(Array(ranking.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 13) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                    itemIcon(item, size: tall ? 41 : 35)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(item.name).font(.system(size: 21, weight: .heavy)).lineLimit(1)
                            Spacer(minLength: 0)
                            Text(DisplayFormat.duration(item.duration))
                                .font(.system(size: 14, weight: .semibold, design: .monospaced)).fixedSize()
                        }
                        GeometryReader { geometry in
                            Capsule().fill(ink.opacity(0.14))
                            Capsule().fill(accent)
                                .frame(width: geometry.size.width * shareOfUsage(item))
                        }.frame(height: 4)
                    }
                }.padding(.vertical, tall ? 7 : 4)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func spotlight(_ item: RankedItem) -> some View {
        VStack(spacing: tall ? 21 : 13) {
            dateCaption
            Text(showApps ? "MOST-USED APP" : "TOP CATEGORY")
                .font(.system(size: 12, weight: .heavy, design: .monospaced)).tracking(2)
                .foregroundStyle(accent)
            itemIcon(item, size: tall ? 144 : 112)
                .padding(tall ? 21 : 16)
                .background {
                    RoundedRectangle(cornerRadius: 40)
                        .fill(.linearGradient(colors: [ink.opacity(0.18), ink.opacity(0.045)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay { RoundedRectangle(cornerRadius: 40).strokeBorder(ink.opacity(0.25)) }
            Text(item.name)
                .font(.system(size: tall ? 56 : 48, weight: .black)).tracking(-2)
                .lineLimit(2).minimumScaleFactor(0.58).multilineTextAlignment(.center)
            Text(DisplayFormat.duration(item.duration))
                .font(.system(size: tall ? 45 : 36, weight: .heavy, design: .monospaced))
                .foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.55)
            Text("\(shareOfUsage(item).formatted(.percent.precision(.fractionLength(0)))) of your app usage")
                .font(.system(size: 15, weight: .medium))
        }.frame(maxWidth: .infinity)
    }

    private var statsContent: some View {
        VStack(alignment: .leading, spacing: tall ? 24 : 17) {
            dateCaption
            Text("Your time\nin numbers.")
                .font(.system(size: tall ? 70 : 62, weight: .black)).tracking(-4)
                .lineSpacing(-6)
            HStack {
                stat("Total app usage", value: DisplayFormat.duration(report.total), symbol: "clock", large: true)
                Spacer(minLength: 0)
            }.padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accent, in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(theme.palette.base)
            HStack(spacing: 12) {
                stat("Apps used", value: report.apps.count.formatted(), symbol: "square.grid.2x2")
                stat("Busiest hour", value: DisplayFormat.hour(report.peakHour), symbol: "sun.max")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ label: String, value: String, symbol: String, large: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(label.uppercased(), systemImage: symbol)
                .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1)
                .lineLimit(1).minimumScaleFactor(0.75)
            Text(value)
                .font(.system(size: large ? 54 : 31, weight: .black, design: .monospaced))
                .tracking(-2).lineLimit(1).minimumScaleFactor(0.45)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(large ? 0 : 16)
        .background(ink.opacity(large ? 0 : 0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var rankedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(showApps ? "THE MOST-PLAYED APPS" : "THE TOP CATEGORIES")
                .font(.system(size: 11, weight: .heavy, design: .monospaced)).tracking(2.2)
                .foregroundStyle(accent).padding(.bottom, 7)
            ForEach(Array(ranking.enumerated()), id: \.offset) { index, item in
                Rectangle().fill(ink.opacity(0.23)).frame(height: 1)
                HStack(spacing: 11) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                    itemIcon(item, size: tall ? 34 : 30)
                    Text(item.name).font(.system(size: 22, weight: .heavy)).lineLimit(1)
                    Spacer(minLength: 5)
                    Text(DisplayFormat.duration(item.duration)).font(.system(size: 14, weight: .semibold, design: .monospaced)).fixedSize()
                }.frame(height: tall ? 46 : 41)
            }
            Rectangle().fill(ink.opacity(0.23)).frame(height: 1)
        }
    }

    @ViewBuilder private func itemIcon(_ item: RankedItem, size: CGFloat) -> some View {
        if let app = item.app {
            AppIcon(app: app, size: size)
        } else {
            categoryIcon(item.name, size: size)
        }
    }

    private func categoryIcon(_ category: String, size: CGFloat) -> some View {
        let symbol: String = switch category {
        case "Development": "chevron.left.forwardslash.chevron.right"
        case "Communication": "bubble.left.and.bubble.right.fill"
        case "Browsing": "globe"
        case "Entertainment": "play.fill"
        case "Design": "paintbrush.pointed.fill"
        case "Productivity": "checkmark"
        default: "square.grid.2x2.fill"
        }
        return Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(ink)
            .frame(width: size, height: size)
            .background(ink.opacity(0.10), in: RoundedRectangle(cornerRadius: size * 0.23))
            .accessibilityHidden(true)
    }

    @ViewBuilder private var signoff: some View {
        switch footer {
        case .none:
            EmptyView()
        case .icons:
            HStack(spacing: 10) {
                ForEach(Array(ranking.enumerated()), id: \.offset) { _, item in
                    itemIcon(item, size: 32)
                }
                Spacer(minLength: 0)
                Text(showApps ? "YOUR TOP APPS" : "YOUR TOP CATEGORIES")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4).foregroundStyle(ink.opacity(0.7))
            }
            .padding(.vertical, 10)
            .overlay(alignment: .top) { Rectangle().fill(ink.opacity(0.25)).frame(height: 1) }
        case .persona:
            footerBanner(label: "YOUR MAC VIBE", text: report.personality)
        case .macModel:
            if let macModel {
                Label(macModel, systemImage: macModel.hasPrefix("MacBook") ? "laptopcomputer" : "desktopcomputer")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(ink.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                    .overlay(alignment: .top) { Rectangle().fill(ink.opacity(0.25)).frame(height: 1) }
            }
        case .custom:
            let message = footerText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty { footerBanner(label: "YOUR NOTE", text: message) }
        }
    }

    private var hasFooter: Bool {
        switch footer {
        case .none: false
        case .custom: !footerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .macModel: macModel != nil
        case .icons, .persona: true
        }
    }

    private func footerBanner(label: String, text: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "sparkles").font(.system(size: 24, weight: .semibold)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 9, weight: .heavy, design: .monospaced)).tracking(1.7)
                Text(text).font(.system(size: 20, weight: .black)).lineLimit(1).minimumScaleFactor(0.55)
            }
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(theme.palette.base)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(accent)
    }

    private var backdrop: some View {
        let palette = theme.palette
        return ZStack {
            palette.base
            RadialGradient(colors: [palette.reflection.opacity(0.62), palette.reflection.opacity(0)],
                           center: UnitPoint(x: 0.04, y: 0.89), startRadius: 10, endRadius: 480)
            RadialGradient(colors: [palette.glow, palette.glow.opacity(0)],
                           center: UnitPoint(x: 1.05, y: 0.10), startRadius: 10, endRadius: 470)
            GlassSweep()
                .fill(.linearGradient(colors: [.white.opacity(0.21), .white.opacity(0.055), .clear],
                                      startPoint: .topTrailing, endPoint: .bottomLeading))
            GlassSweep()
                .stroke(.linearGradient(colors: [.white.opacity(0.45), .white.opacity(0.08), .clear],
                                        startPoint: .topTrailing, endPoint: .bottomLeading), lineWidth: 1)
            Canvas { context, size in
                var flecks = Path()
                for index in 0..<3900 {
                    let x = CGFloat((index * 173 + index * index * 11) % 1741) / 1741 * size.width
                    let y = CGFloat((index * 307 + index * index * 7) % 3251) / 3251 * size.height
                    flecks.addEllipse(in: CGRect(x: x, y: y, width: index.isMultiple(of: 9) ? 1.25 : 0.65, height: 0.7))
                }
                context.fill(flecks, with: .color(ink.opacity(0.11)))
            }
        }.accessibilityHidden(true)
    }

}

private struct GlassSweep: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        return Path { path in
            path.move(to: point(0.70, -0.08))
            path.addCurve(to: point(1.16, 0.57), control1: point(0.54, 0.25), control2: point(0.88, 0.24))
            path.addLine(to: point(1.19, 0.30))
            path.addCurve(to: point(0.94, -0.08), control1: point(0.98, 0.20), control2: point(0.87, 0.08))
            path.closeSubpath()
        }
    }
}
