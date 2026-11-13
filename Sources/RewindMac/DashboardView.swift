import SwiftUI
import Charts
import RewindCore

struct DashboardView: View {
    @Bindable var model: AppModel
    var openWrapped: () -> Void
    @ViewState<Bool> private var showScreenTimeImport = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if model.filter == .custom {
                    HStack {
                        DatePicker("From", selection: $model.customStart, displayedComponents: .date)
                        DatePicker("Through", selection: $model.customEnd, displayedComponents: .date)
                    }.datePickerStyle(.field).onChange(of: model.customStart) { model.requestRefresh() }.onChange(of: model.customEnd) { model.requestRefresh() }
                }
                hero
                HStack(spacing: 14) {
                    metric("Today", value: DisplayFormat.duration(model.todayReport.total), icon: "sun.max", note: model.demo ? "Sample app usage" : "Saved Screen Time")
                    metric("This week", value: DisplayFormat.duration(model.weekReport.total), icon: "calendar", note: "Monday through Sunday")
                    metric("Top application", value: model.report.apps.first?.app.name ?? "—", icon: "app.badge", note: model.filter.rawValue)
                }
                HStack(spacing: 14) {
                    smallMetric("Apps used", value: "\(model.report.apps.count)", icon: "square.grid.2x2")
                    smallMetric("Longest session", value: DisplayFormat.duration(model.report.longest), icon: "timer")
                    smallMetric("Selected time", value: DisplayFormat.duration(model.report.total), icon: "chart.bar.xaxis")
                }
                if model.report.total == 0 { Card { EmptyActivity(model: model) } }
                else {
                    TimelineView(report: model.report, day: $model.timelineDay)
                    HStack(alignment: .top, spacing: 18) {
                        TopAppsView(report: model.report).frame(maxWidth: .infinity)
                        CategoryChartView(report: model.report).frame(maxWidth: .infinity)
                    }
                    HeatmapView(report: model.report)
                }
            }.padding(28)
        }
        .onChange(of: model.filter) { model.requestRefresh() }
        .sheet(isPresented: $showScreenTimeImport) { ScreenTimeImportView(model: model) }
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(.secondary)
                Text("A little perspective.").font(.system(size: 29, weight: .bold, design: .rounded))
                Text("See where your day takes you.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if model.refreshing { ProgressView().controlSize(.small) }
            Button("Import Screen Time…") { showScreenTimeImport = true }
            Picker("Time range", selection: $model.filter) { ForEach(TimeFilter.allCases) { Text($0.rawValue).tag($0) } }
                .labelsHidden().frame(width: 145).accessibilityLabel("Time range")
        }
    }
    private var hero: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR TIME, IN REVIEW.").font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(.white.opacity(0.7))
                Text("Every app has a story.\nHere’s yours.").font(.system(size: 27, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Button(action: openWrapped) { HStack(spacing: 8) { Text("Play your Wrapped"); Image(systemName: "arrow.up.right") }.font(.system(size: 11, weight: .semibold)).padding(.horizontal, 13).padding(.vertical, 8) }
                    .buttonStyle(.plain).foregroundStyle(.white).background(.white.opacity(0.17), in: Capsule()).padding(.top, 3)
            }
            Spacer()
            ZStack {
                Circle().stroke(.white.opacity(0.13), lineWidth: 1).frame(width: 154, height: 154)
                Circle().stroke(.white.opacity(0.18), lineWidth: 22).frame(width: 112, height: 112)
                RewindLogo(size: 52).foregroundStyle(.white.opacity(0.92))
                Circle().fill(Palette.mint).frame(width: 15, height: 15).offset(x: 58, y: -55)
                Image(systemName: "sparkle").font(.system(size: 21)).foregroundStyle(.white).offset(x: -75, y: 40)
            }.frame(width: 200).accessibilityHidden(true)
        }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.28, green: 0.21, blue: 0.54), Color(red: 0.46, green: 0.34, blue: 0.80)], startPoint: .leading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
    }
    private func metric(_ title: String, value: String, icon: String, note: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text(title).font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Image(systemName: icon).foregroundStyle(Palette.accent) }
                Text(value).font(.system(size: 26, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.65)
                Text(note).font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
    }
    private func smallMetric(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(value).font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 16).padding(.vertical, 8).frame(maxWidth: .infinity)
    }
}

struct TopAppsView: View {
    let report: ActivityReport
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeading(title: "Your most-used apps", subtitle: "The tools that shaped your time")
                ForEach(Array(report.apps.prefix(6).enumerated()), id: \.element.id) { index, usage in
                    HStack(spacing: 10) {
                        Text(String(format: "%02d", index + 1)).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
                        AppIcon(app: usage.app)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(usage.app.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                Spacer()
                                Text(DisplayFormat.duration(usage.duration)).font(.system(size: 10, weight: .medium)).monospacedDigit()
                            }
                            GeometryReader { proxy in
                                Capsule().fill(.primary.opacity(0.05))
                                Capsule().fill(Palette.category(usage.category)).frame(width: max(2, proxy.size.width * usage.duration / max(report.total, 1)))
                            }.frame(height: 4)
                        }
                        Text((usage.duration / max(report.total, 1)).formatted(.percent.precision(.fractionLength(0))))
                            .font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 30, alignment: .trailing)
                    }.accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct CategoryChartView: View {
    let report: ActivityReport
    @ViewState<Double?> private var selectedAngle: Double? = nil
    private var selected: CategoryUsage? {
        guard let selectedAngle else { return nil }
        var sum = 0.0
        return report.categories.first { category in sum += category.duration; return selectedAngle <= sum }
    }
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: "A mix that’s yours", subtitle: "Time by application category")
                Chart(report.categories) { item in
                    SectorMark(angle: .value("Duration", item.duration), innerRadius: .ratio(0.73), angularInset: 2)
                        .cornerRadius(4).foregroundStyle(Palette.category(item.category))
                        .opacity(selected == nil || selected?.id == item.id ? 1 : 0.35)
                        .accessibilityLabel(item.category).accessibilityValue(DisplayFormat.duration(item.duration))
                }.frame(height: 155).chartAngleSelection(value: $selectedAngle)
                    .chartBackground { _ in
                        VStack(spacing: 4) {
                            Text(DisplayFormat.duration(selected?.duration ?? report.total)).font(.system(size: 23, weight: .semibold, design: .rounded))
                            Text(selected?.category ?? "APP USAGE").font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(.secondary)
                        }
                    }
                ForEach(report.categories) { category in
                    HStack {
                        Circle().fill(Palette.category(category.category)).frame(width: 6, height: 6)
                        Text(category.category).font(.system(size: 10))
                        Spacer()
                        Text(DisplayFormat.duration(category.duration)).font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        }
    }
}

struct TimelineView: View {
    let report: ActivityReport
    @Binding var day: Date
    @ViewState<Date?> private var selectedDate: Date? = nil
    private var interval: DateInterval { Calendar.current.dateInterval(of: .day, for: day)! }
    private var sessions: [ActivitySession] { report.sessions.filter { $0.end > interval.start && $0.start < interval.end } }
    private var inspected: ActivitySession? { guard let selectedDate else { return nil }; return sessions.first { $0.start <= selectedDate && $0.end > selectedDate } }
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SectionHeading(title: "The rhythm of your day", subtitle: "Select an interval to explore it")
                    Spacer()
                    DatePicker("Timeline day", selection: $day, in: report.interval.start...max(report.interval.start, report.interval.end.addingTimeInterval(-1)), displayedComponents: .date).labelsHidden().frame(width: 125)
                }
                Chart(sessions) { session in
                    BarMark(xStart: .value("Start", max(session.start, interval.start)), xEnd: .value("End", min(session.end, interval.end)), y: .value("Activity", "Activity"), height: 32)
                        .foregroundStyle(Palette.category(session.category)).cornerRadius(3)
                        .accessibilityLabel(session.app.name).accessibilityValue("\(session.start.formatted(date: .omitted, time: .shortened)), \(DisplayFormat.duration(session.duration))")
                }.chartXScale(domain: interval.start...interval.end).chartYAxis(.hidden)
                    .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 4)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated))) } }
                    .chartXSelection(value: $selectedDate).frame(height: 72)
                if let inspected {
                    HStack(spacing: 8) {
                        AppIcon(app: inspected.app, size: 20)
                        Text("\(inspected.app.name) · \(max(inspected.start, interval.start).formatted(date: .omitted, time: .shortened)) – \(min(inspected.end, interval.end).formatted(date: .omitted, time: .shortened)) · \(DisplayFormat.duration(min(inspected.end, interval.end).timeIntervalSince(max(inspected.start, interval.start))))")
                    }.font(.system(size: 10))
                } else {
                    Text(sessions.isEmpty ? "No saved usage on this day." : "Gaps are untracked time, breaks, or excluded apps.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    ForEach(Array(Set(sessions.map(\.category))).sorted(), id: \.self) { category in
                        HStack(spacing: 4) { Circle().fill(Palette.category(category)).frame(width: 5, height: 5); Text(category).font(.system(size: 9)).foregroundStyle(.secondary) }
                    }
                }
            }
        }
    }
}

struct HeatmapView: View {
    let report: ActivityReport
    private var days: [Date] {
        let cal = Calendar.current
        let last = cal.startOfDay(for: min(Date(), report.interval.end.addingTimeInterval(-1)))
        return (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: last) }
    }
    private func duration(day: Date, hour: Int) -> Double {
        report.hours.filter { Calendar.current.isDate($0.start, inSameDayAs: day) && Calendar.current.component(.hour, from: $0.start) == hour }.reduce(0) { $0 + $1.duration }
    }
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionHeading(title: "Your activity, at a glance", subtitle: "Seven days ending \(days.last!.formatted(date: .abbreviated, time: .omitted)) · only time inside your selected range")
                    Spacer()
                    Text("LESS").font(.system(size: 8)).foregroundStyle(.secondary)
                    ForEach(0..<4) { i in RoundedRectangle(cornerRadius: 2).fill(Palette.accent.opacity(0.08 + Double(i) * 0.28)).frame(width: 9, height: 9) }
                    Text("MORE").font(.system(size: 8)).foregroundStyle(.secondary)
                }
                VStack(spacing: 5) {
                    HStack(spacing: 4) {
                        Color.clear.frame(width: 33, height: 10)
                        ForEach(0..<24) { hour in Text(hour % 4 == 0 ? String(format: "%02d", hour) : "").font(.system(size: 8, design: .monospaced)).foregroundStyle(.tertiary).frame(maxWidth: .infinity) }
                    }
                    ForEach(days, id: \.self) { day in
                        HStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 33, alignment: .leading)
                            ForEach(0..<24) { hour in
                                let seconds = duration(day: day, hour: hour)
                                RoundedRectangle(cornerRadius: 3).fill(Palette.accent.opacity(seconds == 0 ? 0.06 : 0.18 + min(seconds / 3600, 1) * 0.82)).frame(maxWidth: .infinity).frame(height: 17)
                                    .help("\(day.formatted(date: .abbreviated, time: .omitted)), \(DisplayFormat.hour(hour)): \(DisplayFormat.duration(seconds))")
                                    .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(DisplayFormat.hour(hour)), \(DisplayFormat.duration(seconds))")
                            }
                        }
                    }
                }
            }
        }
    }
}
