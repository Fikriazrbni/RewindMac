import Foundation

public enum RecapPeriod: String, CaseIterable, Identifiable, Sendable {
    case sevenDays = "7 days"
    case oneMonth = "1 month"
    case threeMonths = "3 months"
    case oneYear = "1 year"

    public var id: Self { self }
    public var headline: String {
        switch self {
        case .sevenDays: "Your week, replayed."
        case .oneMonth: "Your month, replayed."
        case .threeMonths: "Three months, replayed."
        case .oneYear: "Your year, replayed."
        }
    }

    /// Current window includes today. Older windows abut it, even when a month clamps its day.
    public func interval(endingNear now: Date, periodsBack: Int = 0, calendar: Calendar = .current) -> DateInterval {
        let anchor = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let back = max(0, periodsBack)
        func boundary(_ offset: Int) -> Date {
            switch self {
            case .sevenDays: calendar.date(byAdding: .day, value: -7 * offset, to: anchor)!
            case .oneMonth: calendar.date(byAdding: .month, value: -offset, to: anchor)!
            case .threeMonths: calendar.date(byAdding: .month, value: -3 * offset, to: anchor)!
            case .oneYear: calendar.date(byAdding: .year, value: -offset, to: anchor)!
            }
        }
        return DateInterval(start: boundary(back + 1), end: boundary(back))
    }
}

public enum RecapRange: Equatable, Sendable {
    case preset(RecapPeriod, periodsBack: Int)
    case custom(from: Date, through: Date)

    public var title: String {
        switch self {
        case .preset(let period, _): period.rawValue
        case .custom: "Custom range"
        }
    }

    public var headline: String {
        switch self {
        case .preset(let period, _): period.headline
        case .custom: "Your time, replayed."
        }
    }

    public func interval(endingNear now: Date, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .preset(let period, let periodsBack):
            period.interval(endingNear: now, periodsBack: periodsBack, calendar: calendar)
        case .custom(let from, let through):
            DateInterval(start: calendar.startOfDay(for: min(from, through)),
                         end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(from, through)))!)
        }
    }
}
