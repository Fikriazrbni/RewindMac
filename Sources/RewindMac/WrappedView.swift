import SwiftUI
import RewindCore

struct WrappedView: View {
    @Bindable var model: AppModel
    @ViewState<Int> private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState<ShareRecap?> private var shareRecap: ShareRecap? = nil
    @ViewState<Bool> private var showScreenTimeImport = false
    @ViewState<Date> private var customStart = RecapPeriod.threeMonths.interval(endingNear: Date()).start
    @ViewState<Date> private var customEnd = Date()

    private var selectedPeriod: RecapPeriod? {
        if case .preset(let period, _) = model.recapRange { return period }
        return nil
    }

    private let titles = ["Your Time, Replayed", "Your Most-Used App", "Your Digital Personality", "Your Peak Hours", "Where Your Time Went", "Your Summary"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wrapped").font(.system(size: 29, weight: .bold, design: .rounded))
                        Text("Your time, one very you story.").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Recap period", selection: Binding(get: { selectedPeriod }, set: { period in
                        if let period {
                            selectRange(.preset(period, periodsBack: 0))
                        } else {
                            selectRange(.custom(from: customStart, through: customEnd))
                        }
                    })) {
                        ForEach(RecapPeriod.allCases) { Text($0.rawValue).tag(Optional($0)) }
                        Text("Custom").tag(nil as RecapPeriod?)
                    }.pickerStyle(.segmented).labelsHidden()
                }
                if case .custom = model.recapRange {
                    HStack(spacing: 14) {
                        DatePicker("From", selection: $customStart, displayedComponents: .date)
                        DatePicker("Through", selection: $customEnd, displayedComponents: .date)
                    }
                    .datePickerStyle(.field)
                    .onChange(of: customStart) { _, start in
                        customEnd = max(start, customEnd)
                        selectRange(.custom(from: start, through: customEnd))
                    }
                    .onChange(of: customEnd) { _, end in
                        customStart = min(customStart, end)
                        selectRange(.custom(from: customStart, through: end))
                    }
                }
                HStack(spacing: 12) {
                    if case .preset(let period, let back) = model.recapRange {
                        Button { selectRange(.preset(period, periodsBack: back + 1)) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous period")
                        Text(DisplayFormat.recapDates(model.recapRange.interval(endingNear: Date())))
                            .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                        Button { selectRange(.preset(period, periodsBack: max(0, back - 1))) } label: { Image(systemName: "chevron.right") }
                            .disabled(back == 0).accessibilityLabel("Next period")
                        if back > 0 {
                            Button("Latest") { selectRange(.preset(period, periodsBack: 0)) }
                                .buttonStyle(.plain).foregroundStyle(Palette.accent)
                        }
                    }
                    Spacer()
                    Button("Import Screen Time…") { showScreenTimeImport = true }
                    if let report = model.wrappedReport, report.total > 0 {
                        Button { prepareShare(report) } label: { Label("Share recap", systemImage: "square.and.arrow.up") }
                            .buttonStyle(.borderedProminent).tint(Palette.accent)
                    }
                }
                if let report = model.wrappedReport {
                    if report.includesScreenTime, let first = report.sessions.first, let last = report.sessions.last {
                        let coverage = DateInterval(start: first.start, end: last.end)
                        Label("Imported usage spans \(DisplayFormat.recapDates(coverage))", systemImage: "clock.arrow.circlepath")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if report.total == 0 {
                        Card {
                            VStack(spacing: 18) {
                                Image(systemName: "sparkles").font(.system(size: 42)).foregroundStyle(Palette.accent)
                                Text("This period is still a blank canvas.").font(.title2.bold())
                                Text("Import Screen Time or choose a period with saved activity.").foregroundStyle(.secondary)
                                Button("Explore demo recap") { selectRange(.preset(.sevenDays, periodsBack: 0)); model.setDemo(true) }.buttonStyle(.borderedProminent)
                            }.frame(maxWidth: .infinity).padding(.vertical, 100)
                        }
                    } else {
                        VStack(spacing: 0) {
                            HStack(spacing: 6) {
                                ForEach(0..<6) { i in
                                    Button { navigate(i) } label: { Capsule().fill(.white.opacity(i <= page ? 0.9 : 0.2)).frame(height: 3).frame(maxWidth: .infinity).padding(.vertical, 8) }.buttonStyle(.plain).accessibilityLabel(titles[i])
                                }
                            }.padding(.horizontal, 30).padding(.top, 20)
                            HStack {
                                Text("REWIND / \(String(format: "%02d", page + 1))").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(2)
                                Spacer()
                                Text(model.demo ? "DEMO RECAP" : "YOUR WRAPPED").font(.system(size: 9, weight: .semibold)).tracking(1.4)
                            }.foregroundStyle(.white.opacity(0.6)).padding(.horizontal, 32).padding(.top, 15)
                            story(report).id(page).transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 12)))
                                .frame(maxWidth: .infinity, minHeight: 430).padding(30)
                            HStack {
                                Button { navigate(max(0, page - 1)) } label: { Label("Back", systemImage: "arrow.left") }.disabled(page == 0).keyboardShortcut(.leftArrow, modifiers: [])
                                Spacer()
                                Text("\(page + 1) / 6").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                                Spacer()
                                if page < 5 {
                                    Button { navigate(page + 1) } label: { HStack { Text("Keep going"); Image(systemName: "arrow.right") } }.keyboardShortcut(.rightArrow, modifiers: [])
                                } else { Button { prepareShare(report) } label: { Label("Share recap", systemImage: "square.and.arrow.up") } }
                            }.font(.system(size: 12, weight: .medium)).buttonStyle(.plain).foregroundStyle(.white).padding(30)
                        }
                        .background(LinearGradient(colors: [Color(red: 0.13, green: 0.10, blue: 0.25), page == 2 ? Color(red: 0.27, green: 0.20, blue: 0.48) : Color(red: 0.23, green: 0.17, blue: 0.40)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 23))
                        .clipped()
                        Text(model.demo ? "Illustrative sample data." : "Based on saved Screen Time app usage within the selected dates.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView("Loading recap…").frame(maxWidth: .infinity, minHeight: 240)
                }
            }.padding(28)
        }.sheet(item: $shareRecap) { recap in
            ShareRecapView(recap: recap)
        }
        .sheet(isPresented: $showScreenTimeImport) { ScreenTimeImportView(model: model) }
        .onAppear {
            if case .custom(let start, let end) = model.recapRange {
                customStart = start
                customEnd = end
            }
        }
    }
    @ViewBuilder private func story(_ report: ActivityReport) -> some View {
        switch page {
        case 0:
            VStack(spacing: 24) {
                Image(systemName: "sparkles").font(.system(size: 43)).foregroundStyle(Palette.mint)
                Text(model.recapRange.headline).font(.system(size: 55, weight: .bold, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(.white)
                Text(DisplayFormat.duration(report.total)).font(.system(size: 50, weight: .medium, design: .rounded)).foregroundStyle(Palette.mint)
                Text("of doing your thing.").font(.title3).foregroundStyle(.white.opacity(0.6))
            }
        case 1:
            if let app = report.apps.first {
                VStack(spacing: 22) {
                    Text("THE ONE YOU KEPT COMING BACK TO").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.55))
                    AppIcon(app: app.app, size: 105).shadow(color: .black.opacity(0.3), radius: 20, y: 12)
                    Text(app.app.name).font(.system(size: 48, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(DisplayFormat.duration(app.duration)).font(.system(size: 31, weight: .medium, design: .rounded)).foregroundStyle(Palette.mint)
                    Text("\((app.duration / report.total).formatted(.percent.precision(.fractionLength(0)))) of your recorded time. A familiar place.").foregroundStyle(.white.opacity(0.6))
                }
            }
        case 2:
            VStack(spacing: 26) {
                Image(systemName: "wand.and.stars").font(.system(size: 60)).foregroundStyle(Color(red: 0.98, green: 0.76, blue: 0.48))
                Text("YOUR MAC VIBE").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.55))
                Text(report.personality).font(.system(size: 48, weight: .bold, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(.white)
                Text(report.personalityReason).font(.system(size: 14)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.65)).frame(maxWidth: 420)
                Text("Just for fun. Always explainable.").font(.caption).foregroundStyle(Palette.mint)
            }
        case 3:
            VStack(spacing: 24) {
                Image(systemName: "sun.max").font(.system(size: 57, weight: .light)).foregroundStyle(Color(red: 0.98, green: 0.76, blue: 0.48))
                Text("Your golden hour.").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(DisplayFormat.hour(report.peakHour)).font(.system(size: 48, weight: .medium, design: .rounded)).foregroundStyle(Palette.mint)
                Text("Your busiest hour across this period,\nin your current time zone.").multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.6))
            }
        case 4:
            VStack(alignment: .leading, spacing: 24) {
                Text("A palette of your time.").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(.white)
                ForEach(report.categories) { category in
                    HStack(spacing: 16) {
                        Text(category.category).font(.system(size: 12, weight: .medium)).foregroundStyle(.white).frame(width: 115, alignment: .leading)
                        let apps = report.apps.lazy.filter { $0.category == category.category }.prefix(3)
                        HStack(spacing: 4) {
                            ForEach(Array(apps)) { usage in
                                AppIcon(app: usage.app, size: 24)
                                    .accessibilityHidden(false)
                                    .accessibilityLabel(usage.app.name)
                                    .help(usage.app.name)
                            }
                        }.frame(width: 80, alignment: .leading)
                        GeometryReader { proxy in
                            Capsule().fill(.white.opacity(0.06))
                            Capsule().fill(Palette.category(category.category).gradient).frame(width: max(3, proxy.size.width * category.duration / report.total))
                        }.frame(height: 13)
                        Text(DisplayFormat.duration(category.duration)).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7)).frame(width: 70, alignment: .trailing)
                    }
                }
            }.frame(maxWidth: 600)
        default:
            SharePosterPreview(poster: SharePoster(report: report, range: model.recapRange, demo: model.demo, format: .feed, theme: .aurora, showApps: true), width: 336)
        }
    }
    private func navigate(_ index: Int) { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { page = index } }
    private func selectRange(_ range: RecapRange) {
        guard model.recapRange != range else { return }
        model.recapRange = range
        page = 0
        model.requestRefresh()
    }
    private func prepareShare(_ report: ActivityReport) {
        shareRecap = ShareRecap(report: report, range: model.recapRange, demo: model.demo)
    }
}
