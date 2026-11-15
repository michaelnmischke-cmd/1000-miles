import Foundation
import HealthKit
import Observation
import WidgetKit

/// Reads miles from Apple Health for the current year.
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

    var isHealthAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Shows the Health permission sheet if iOS hasn't asked yet. Safe to call any time:
    /// once the user has answered, iOS doesn't show the sheet again.
    func requestAccess() async {
        guard isHealthAvailable else {
            status = .unavailable
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: MileageReader.readTypes)
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    /// True when iOS still needs to show the permission sheet
    /// (for example, the first time after an update adds step counting).
    private func needsToAsk() async -> Bool {
        let requestStatus = try? await store.statusForAuthorizationRequest(toShare: [], read: MileageReader.readTypes)
        return requestStatus == .shouldRequest
    }

    func refresh() async {
        guard isHealthAvailable else {
            status = .unavailable
            return
        }

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

        do {
            let result = try await MileageReader(store: store).dailyMiles()
            dailyMiles = result
            lastUpdated = Date()
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

        // Let the widgets pick up the new numbers.
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func describe(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("entitlement") {
            return "\(text). In Xcode, open Signing & Capabilities and make sure a Team is selected."
        }
        return text
    }

    private func useSampleDataIfSimulator() {
        #if targetEnvironment(simulator)
        dailyMiles = MileageReader.sampleData()
        isShowingSampleData = true
        #endif
    }
}
