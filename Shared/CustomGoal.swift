import Foundation

/// One time you logged progress on a goal, like "+10 pull-ups on Nov 15".
struct GoalEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var amount: Int
}

/// A hand-logged yearly goal ("side trail"), like 500 pull-ups.
/// It runs January 1 to December 31, like the miles goal.
struct CustomGoal: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// What's being counted, like "pull-ups" or "workouts".
    var unit: String
    var target: Int
    var entries: [GoalEntry] = []

    func entries(in year: Int, calendar: Calendar = .current) -> [GoalEntry] {
        entries
            .filter { calendar.component(.year, from: $0.date) == year }
            .sorted { $0.date > $1.date }
    }

    func total(in year: Int, calendar: Calendar = .current) -> Int {
        entries(in: year, calendar: calendar).reduce(0) { $0 + $1.amount }
    }

    func fraction(in year: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(Double(total(in: year)) / Double(target), 1)
    }

    func percent(in year: Int) -> Int {
        guard target > 0 else { return 0 }
        return Int((Double(total(in: year)) / Double(target) * 100).rounded(.down))
    }
}

/// One-tap starting points when adding a goal.
struct GoalPreset: Identifiable {
    let name: String
    let unit: String
    let target: Int
    var id: String { name }

    static let all: [GoalPreset] = [
        GoalPreset(name: "Pull-ups", unit: "pull-ups", target: 500),
        GoalPreset(name: "Push-ups", unit: "push-ups", target: 5000),
        GoalPreset(name: "Squats", unit: "squats", target: 5000),
        GoalPreset(name: "Workouts", unit: "workouts", target: 150),
    ]
}
