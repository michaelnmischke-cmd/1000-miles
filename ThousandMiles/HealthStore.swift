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
        /// iOS hasn't shown the Health permission sheet yet (or it was dismissed).
        case needsPermission
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
    private var readTypes: Set<HKObjectType> { [distanceType] }

    var isHealthAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Shows the Health permission sheet if iOS hasn't asked yet. Safe to call any time:
    /// once the user has answered, iOS doesn't show the sheet again.
    func requestAccess() async {
        guard isHealthAvailable else {
            status = .unavailable
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    /// True when iOS still needs to show the permission sheet.
    private func needsToAsk() async -> Bool {
        let requestStatus = try? await store.statusForAuthorizationRequest(toShare: [], read: readTypes)
        return requestStatus == .shouldRequest
    }

    func refresh() async {
        guard isHealthAvailable else {
            status = .unavailable
            return
        }

        // Ask for permission first if it hasn't been granted or denied yet.
        if await needsToAsk() {
            await requestAccess()
            if case .failed = status {
                useSampleDataIfSimulator()
                return
            }
            if await needsToAsk() {
                status = .needsPermission
                useSampleDataIfSimulator()
                return
            }
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
            dailyMiles = result
            lastUpdated = now
            isShowingSampleData = false
            status = .ready
            if result.isEmpty { useSampleDataIfSimulator() }
        } catch let error as HKError where error.code == .errorAuthorizationNotDetermined {
            status = .needsPermission
            useSampleDataIfSimulator()
        } catch {
            status = .failed(Self.describe(error))
            useSampleDataIfSimulator()
        }
    }

    private static func describe(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("entitlement") {
            return "\(text). In Xcode, open Signing & Capabilities and make sure a Team is selected."
        }
        return text
    }

    /// The Simulator has no real steps, so fill in made-up miles to show the design.
    private func useSampleDataIfSimulator() {
        #if targetEnvironment(simulator)
        let now = Date()
        let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
        dailyMiles = Self.sampleData(from: startOfYear, to: now, calendar: calendar)
        isShowingSampleData = true
        #endif
    }

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
