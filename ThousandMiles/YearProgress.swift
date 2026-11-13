import Foundation

/// All the numbers the progress screen shows, worked out from daily miles and the goal.
struct YearProgress {
    struct WeekTotal: Identifiable {
        let weekStart: Date
        let miles: Double
        var id: Date { weekStart }
    }

    let goal: Double
    let total: Double
    let today: Double
    let thisWeek: Double
    let thisMonth: Double
    let daysLeft: Int
    let expectedByNow: Double
    let weeks: [WeekTotal]
    let year: Int

    init(dailyMiles: [Date: Double], goal: Double, now: Date = Date(), calendar: Calendar = .current) {
        self.goal = max(goal, 1)
        year = calendar.component(.year, from: now)

        let yearInterval = calendar.dateInterval(of: .year, for: now)
        let startOfYear = yearInterval?.start ?? now
        let endOfYear = yearInterval?.end ?? now
        let startOfToday = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday

        total = dailyMiles.values.reduce(0, +)
        today = dailyMiles[startOfToday] ?? 0
        thisWeek = dailyMiles.filter { $0.key >= weekStart }.values.reduce(0, +)
        thisMonth = dailyMiles.filter { $0.key >= monthStart }.values.reduce(0, +)

        let daysInYear = calendar.dateComponents([.day], from: startOfYear, to: endOfYear).day ?? 365
        let daysElapsed = calendar.dateComponents([.day], from: startOfYear, to: startOfToday).day ?? 0
        // Count today as a day still left to walk.
        daysLeft = max(daysInYear - daysElapsed, 1)
        // Where you "should" be at the start of today to finish exactly on time.
        expectedByNow = self.goal * Double(daysElapsed) / Double(max(daysInYear, 1))

        var byWeek: [Date: Double] = [:]
        for (day, miles) in dailyMiles {
            let start = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
            byWeek[start, default: 0] += miles
        }
        weeks = byWeek
            .map { WeekTotal(weekStart: $0.key, miles: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    var fraction: Double { min(total / goal, 1) }
    var percent: Int { Int((total / goal * 100).rounded(.down)) }
    var milesLeft: Double { max(goal - total, 0) }
    var isComplete: Bool { total >= goal }
    /// Miles per day needed from today on to hit the goal by December 31.
    var dailyPaceNeeded: Double { milesLeft / Double(daysLeft) }
    /// Positive means ahead of pace, negative means behind.
    var aheadBy: Double { total - expectedByNow }
    /// The steady weekly amount that reaches the goal in a year.
    var weeklyTarget: Double { goal / 52.0 }

    static let milestoneFractions: [Double] = [0.10, 0.25, 0.50, 0.75, 1.00]
    var milestones: [Double] { Self.milestoneFractions.map { $0 * goal } }
}
