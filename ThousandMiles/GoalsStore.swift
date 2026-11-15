import Foundation
import Observation

/// Keeps your hand-logged goals on this iPhone.
@MainActor
@Observable
final class GoalsStore {
    private(set) var goals: [CustomGoal] = []

    private let key = "customGoals"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    func goal(id: CustomGoal.ID) -> CustomGoal? {
        goals.first { $0.id == id }
    }

    func add(name: String, unit: String, target: Int) {
        goals.append(CustomGoal(name: name, unit: unit, target: max(target, 1)))
        save()
    }

    func update(_ goal: CustomGoal) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[index] = goal
        save()
    }

    func delete(id: CustomGoal.ID) {
        goals.removeAll { $0.id == id }
        save()
    }

    func log(_ amount: Int, to id: CustomGoal.ID, on date: Date = Date()) {
        guard amount > 0, let index = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[index].entries.append(GoalEntry(date: date, amount: amount))
        save()
    }

    /// Removes one logged entry, for fixing mistakes.
    func removeEntry(_ entryID: GoalEntry.ID, from id: CustomGoal.ID) {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[index].entries.removeAll { $0.id == entryID }
        save()
    }

    /// Removes the most recent entry.
    func undoLast(on id: CustomGoal.ID) {
        guard let index = goals.firstIndex(where: { $0.id == id }),
              let last = goals[index].entries.max(by: { $0.date < $1.date }) else { return }
        goals[index].entries.removeAll { $0.id == last.id }
        save()
    }

    // MARK: - Saving

    private func load() {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode([CustomGoal].self, from: data) else { return }
        goals = saved
    }

    private func save() {
        if let data = try? JSONEncoder().encode(goals) {
            defaults.set(data, forKey: key)
        }
    }
}
