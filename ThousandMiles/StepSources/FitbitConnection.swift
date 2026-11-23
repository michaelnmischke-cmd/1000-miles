import AuthenticationServices
import Foundation
import Observation

/// The Fitbit connection: signing in, signing out, and the latest daily steps.
///
/// Steps are saved on the iPhone so the app still shows Fitbit miles when it's offline.
@MainActor
@Observable
final class FitbitConnection {
    private(set) var isConnected = GoogleHealthAuth.isSignedIn
    private(set) var dailySteps: [Date: Double] = FitbitStorage.loadSteps()
    private(set) var lastSynced: Date? = FitbitStorage.lastSynced()
    private(set) var problem: String?
    private(set) var isWorking = false

    var isAvailable: Bool { GoogleHealthConfig.isConfigured }

    /// Signs in with the browser sheet that SwiftUI's `webAuthenticationSession` provides.
    func connect(using authenticate: (URL, String) async throws -> URL) async {
        problem = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let request = try GoogleHealthAuth.makeRequest()
            let callback = try await authenticate(request.url, GoogleHealthConfig.callbackScheme)
            _ = try await GoogleHealthAuth.finish(callback: callback, request: request)
            isConnected = true
            await sync()
        } catch let error as GoogleHealthError {
            if case .cancelled = error { return }
            problem = error.localizedDescription
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // Closing the sign-in sheet isn't a problem worth showing.
            return
        } catch {
            problem = error.localizedDescription
        }
    }

    func disconnect() async {
        await GoogleHealthAuth.signOut()
        isConnected = false
        dailySteps = [:]
        lastSynced = nil
        problem = nil
        FitbitStorage.clear()
    }

    /// Fetches this year's steps. Keeps the last good numbers if it can't reach Google.
    func sync(now: Date = Date()) async {
        guard isConnected else { return }
        let calendar = Calendar.current
        let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
        do {
            let steps = try await GoogleHealthClient().dailySteps(from: startOfYear, to: now)
            dailySteps = steps
            lastSynced = now
            problem = nil
            FitbitStorage.save(steps, at: now)
        } catch GoogleHealthError.signedOut {
            isConnected = false
            problem = GoogleHealthError.signedOut.localizedDescription
        } catch {
            problem = error.localizedDescription
        }
    }
}

/// Keeps the last Fitbit steps on the iPhone so the app still shows them offline.
private enum FitbitStorage {
    static let stepsKey = "fitbitDailySteps"
    static let lastSyncedKey = "fitbitLastSynced"

    static func save(_ steps: [Date: Double], at date: Date) {
        let byTimestamp = Dictionary(uniqueKeysWithValues: steps.map { (String($0.key.timeIntervalSince1970), $0.value) })
        UserDefaults.standard.set(byTimestamp, forKey: stepsKey)
        UserDefaults.standard.set(date, forKey: lastSyncedKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: stepsKey)
        UserDefaults.standard.removeObject(forKey: lastSyncedKey)
    }

    static func lastSynced() -> Date? {
        GoogleHealthAuth.isSignedIn ? UserDefaults.standard.object(forKey: lastSyncedKey) as? Date : nil
    }

    static func loadSteps() -> [Date: Double] {
        guard GoogleHealthAuth.isSignedIn,
              let saved = UserDefaults.standard.dictionary(forKey: stepsKey) as? [String: Double] else { return [:] }
        let thisYear = Calendar.current.component(.year, from: Date())
        var result: [Date: Double] = [:]
        for (key, value) in saved {
            guard let seconds = TimeInterval(key) else { continue }
            let day = Date(timeIntervalSince1970: seconds)
            if Calendar.current.component(.year, from: day) == thisYear { result[day] = value }
        }
        return result
    }
}
