import Foundation
import HealthKit
import Observation
import WidgetKit

/// Reads miles for the current year from Apple Health, plus Fitbit when it's connected.
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
    /// Apps and devices that wrote steps or distance to Apple Health this year (WHOOP, Garmin…).
    private(set) var healthSourceNames: [String] = []
    /// Steps from sources outside Apple Health. Fitbit is the only one so far.
    let fitbit = FitbitConnection()

    /// Miles from Apple Health alone, before other sources are merged in.
    private var healthMiles: [Date: Double] = [:]
    private var milesPerStep = MileageReader.defaultMilesPerStep

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

        let reader = MileageReader(store: store)
        do {
            let readings = try await reader.readings()
            healthMiles = readings.miles
            milesPerStep = readings.milesPerStep
            isShowingSampleData = false
            if readings.miles.isEmpty { useSampleDataIfSimulator() }
            await fitbit.sync()
            healthSourceNames = await reader.sourceNames()
            mergeSources()
            lastUpdated = Date()
            status = .ready
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

    /// Call after Fitbit is connected or disconnected so the totals update right away.
    func mergeSources() {
        dailyMiles = MileageReader.merge(miles: healthMiles, extraSteps: [fitbit.dailySteps], milesPerStep: milesPerStep)
    }

    private func useSampleDataIfSimulator() {
        #if targetEnvironment(simulator)
        healthMiles = MileageReader.sampleData()
        isShowingSampleData = true
        #endif
        mergeSources()
    }
}
