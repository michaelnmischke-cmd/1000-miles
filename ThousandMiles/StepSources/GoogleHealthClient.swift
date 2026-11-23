import Foundation

/// Reads daily step totals from the Google Health API (where Fitbit data lives now).
struct GoogleHealthClient {
    var calendar: Calendar = .current
    var session: URLSession = .shared

    /// Google returns at most 90 days of steps per request.
    private static let maxDaysPerRequest = 90

    /// Steps per day from `start` through today, keyed by the start of each day.
    /// Days the Fitbit wasn't worn are left out.
    func dailySteps(from start: Date, to end: Date = Date()) async throws -> [Date: Double] {
        let token = try await GoogleHealthAuth.validAccessToken()
        var result: [Date: Double] = [:]
        var chunkStart = calendar.startOfDay(for: start)
        let lastDay = calendar.startOfDay(for: end)
        while chunkStart <= lastDay {
            let chunkEnd = min(
                calendar.date(byAdding: .day, value: Self.maxDaysPerRequest, to: chunkStart)!,
                calendar.date(byAdding: .day, value: 1, to: lastDay)!
            )
            let points = try await rollUp(token: token, from: chunkStart, toExclusive: chunkEnd)
            for point in points {
                guard let day = point.civilStartTime?.date.flatMap(date(from:)),
                      let text = point.steps?.countSum,
                      let count = Double(text) else { continue }
                result[day] = count
            }
            chunkStart = chunkEnd
        }
        return result
    }

    // MARK: Request

    private func rollUp(token: String, from start: Date, toExclusive end: Date) async throws -> [RollupPoint] {
        let url = GoogleHealthConfig.apiBase
            .appendingPathComponent("users/me/dataTypes/steps/dataPoints:dailyRollUp")
        var points: [RollupPoint] = []
        var pageToken: String?
        repeat {
            var body = RollupRequest(
                range: .init(start: civil(start), end: civil(end)),
                windowSizeDays: 1
            )
            body.pageToken = pageToken
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                let text = String(decoding: data, as: UTF8.self)
                if text.contains("ACCOUNT_NOT_LINKED") { throw GoogleHealthError.accountNotLinked }
                if status == 401 { throw GoogleHealthError.signedOut }
                throw GoogleHealthError.server("Fitbit data couldn't be loaded (error \(status)).")
            }
            let page = try JSONDecoder().decode(RollupResponse.self, from: data)
            points += page.rollupDataPoints ?? []
            pageToken = page.nextPageToken
        } while pageToken?.isEmpty == false
        return points
    }

    private func civil(_ day: Date) -> CivilDateTime {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return CivilDateTime(
            date: .init(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0),
            time: .init(hours: 0, minutes: 0, seconds: 0, nanos: 0)
        )
    }

    private func date(from civil: CivilDate) -> Date? {
        calendar.date(from: DateComponents(year: civil.year, month: civil.month, day: civil.day))
    }

    // MARK: JSON shapes

    private struct CivilDate: Codable {
        var year: Int
        var month: Int
        var day: Int
    }

    private struct TimeOfDay: Codable {
        var hours: Int?
        var minutes: Int?
        var seconds: Int?
        var nanos: Int?
    }

    private struct CivilDateTime: Codable {
        var date: CivilDate?
        var time: TimeOfDay?
    }

    private struct RollupRequest: Encodable {
        struct Range: Encodable {
            var start: CivilDateTime
            var end: CivilDateTime
        }
        var range: Range
        var windowSizeDays: Int
        var pageToken: String?
    }

    private struct RollupResponse: Decodable {
        var rollupDataPoints: [RollupPoint]?
        var nextPageToken: String?
    }

    private struct RollupPoint: Decodable {
        struct Steps: Decodable { var countSum: String? }
        var civilStartTime: CivilDateTime?
        var steps: Steps?
    }
}
