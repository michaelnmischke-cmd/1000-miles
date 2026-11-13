import Foundation
import HealthKit
import Observation

/// Reads "Walking + Running Distance" from Apple Health for the current year.
/// Nothing is written to Health and nothing leaves the phone.
@MainActor
@Observable
final class HealthStore {
    enum Status {
        case idle
        case loading
        case ready
        case unavailable
        case failed(String)
    }

    private(set) var status: Status = .idle
    /// Miles per day for the current calendar year, keyed by the start of each day.
    private(set) var dailyMiles: [Date: Double] = [:]
    private(set) var lastUpdated: Date?
    /// True when running in the Simulator with sample data (the Simulator has no real steps).
    private(set) var isShowingSampleData = false

    private let store = HKHealthStore()
    private let distanceType = HKQuantityType(.distanceWalkingRunning)
    private let calendar = Calendar.current

    var isHealthAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async {
        guard isHealthAvailable else {
            status = .unavailable
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: [distanceType])
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        guard isHealthAvailable else {
            status = .unavailable
            return
        }
        if case .ready = status {} else { status = .loading }

        let now = Date()
        let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
        let predicate = HKQuery.predicateForSamples(withStart: startOfYear, end: now)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: distanceType, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: startOfYear,
            intervalComponents: DateComponents(day: 1)
        )

        do {
            let collection = try await query.result(for: store)
            var result: [Date: Double] = [:]
            for stats in collection.statistics() {
                if let sum = stats.sumQuantity() {
                    result[stats.startDate] = sum.doubleValue(for: .mile())
                }
            }

            #if targetEnvironment(simulator)
            if result.isEmpty {
                result = Self.sampleData(from: startOfYear, to: now, calendar: calendar)
                isShowingSampleData = true
            }
            #endif

            dailyMiles = result
            lastUpdated = now
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Made-up miles so the Simulator shows something realistic.
    private static func sampleData(from start: Date, to end: Date, calendar: Calendar) -> [Date: Double] {
        var data: [Date: Double] = [:]
        var day = start
        var index = 0.0
        while day <= end {
            data[day] = max(0.4, 2.6 + 1.4 * sin(index * 0.9) + 0.8 * cos(index * 0.31))
            index += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return data
    }
}
