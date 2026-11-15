import Foundation
import HealthKit

/// Works out miles per day for the current year from Apple Health.
/// Used by both the app and the widgets.
///
/// Miles come from "Walking + Running Distance". Devices like WHOOP only send steps,
/// so on days when steps add up to clearly more than the recorded distance,
/// the steps are converted to miles instead. Health merges overlapping devices,
/// so steps from the iPhone and WHOOP aren't counted twice.
struct MileageReader {
    static let distanceType = HKQuantityType(.distanceWalkingRunning)
    static let stepType = HKQuantityType(.stepCount)
    static var readTypes: Set<HKObjectType> { [distanceType, stepType] }

    /// About 2,250 steps per mile, used until we can learn your own stride.
    static let defaultMilesPerStep = 1.0 / 2250.0

    let store: HKHealthStore
    var calendar: Calendar = .current

    func dailyMiles(now: Date = Date()) async throws -> [Date: Double] {
        let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
        let distance = try await dailyTotals(of: Self.distanceType, unit: .mile(), from: startOfYear, to: now)
        // Steps are a bonus: if they can't be read, carry on with distance alone.
        let steps = (try? await dailyTotals(of: Self.stepType, unit: .count(), from: startOfYear, to: now)) ?? [:]
        return Self.combine(distance: distance, steps: steps)
    }

    static func combine(distance: [Date: Double], steps: [Date: Double]) -> [Date: Double] {
        let milesPerStep = learnedMilesPerStep(distance: distance, steps: steps)
        var result = distance
        for (day, count) in steps {
            let fromSteps = count * milesPerStep
            let recorded = result[day] ?? 0
            // Only switch to steps when they add meaningfully more (15%+),
            // so normal iPhone days aren't nudged upward by rounding.
            if fromSteps > recorded * 1.15 {
                result[day] = fromSteps
            }
        }
        return result
    }

    /// Learns your stride from days when the iPhone recorded both distance and steps.
    static func learnedMilesPerStep(distance: [Date: Double], steps: [Date: Double]) -> Double {
        var miles = 0.0
        var stepCount = 0.0
        var days = 0
        for (day, d) in distance where d > 0.5 {
            if let s = steps[day], s > 1000 {
                miles += d
                stepCount += s
                days += 1
            }
        }
        guard days >= 5, stepCount > 0 else { return defaultMilesPerStep }
        return min(max(miles / stepCount, 1.0 / 3000.0), 1.0 / 1500.0)
    }

    private func dailyTotals(of type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await query.result(for: store)
        var result: [Date: Double] = [:]
        for stats in collection.statistics() {
            if let sum = stats.sumQuantity() {
                result[stats.startDate] = sum.doubleValue(for: unit)
            }
        }
        return result
    }

    /// Made-up miles so the Simulator (which has no real steps) shows something realistic.
    static func sampleData(now: Date = Date(), calendar: Calendar = .current) -> [Date: Double] {
        let start = calendar.dateInterval(of: .year, for: now)?.start ?? now
        var data: [Date: Double] = [:]
        var day = start
        var index = 0.0
        while day <= now {
            data[day] = max(0.4, 2.6 + 1.4 * sin(index * 0.9) + 0.8 * cos(index * 0.31))
            index += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return data
    }
}
