import WidgetKit
import SwiftUI
import HealthKit
import AppIntents

// MARK: - Settings people can change by long-pressing the widget > Edit Widget

struct GoalIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Yearly goal"
    static var description = IntentDescription("Set this to the same goal you use in the app.")

    @Parameter(title: "Goal (miles)", default: 1000)
    var goalMiles: Int
}

// MARK: - Data

struct MilesEntry: TimelineEntry {
    let date: Date
    let progress: YearProgress
    /// False when Health couldn't be read and there's nothing saved yet.
    let hasData: Bool
}

struct MilesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MilesEntry {
        MilesEntry(date: Date(), progress: YearProgress(dailyMiles: MileageReader.sampleData(), goal: 1000), hasData: true)
    }

    func snapshot(for configuration: GoalIntent, in context: Context) async -> MilesEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        return await makeEntry(goal: configuration.goalMiles)
    }

    func timeline(for configuration: GoalIntent, in context: Context) async -> Timeline<MilesEntry> {
        let entry = await makeEntry(goal: configuration.goalMiles)
        // Check again in about 15 minutes. iOS may wait longer to save battery.
        let next = Date().addingTimeInterval(15 * 60)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func makeEntry(goal: Int) async -> MilesEntry {
        let daily = await loadMiles()
        let progress = YearProgress(dailyMiles: daily ?? [:], goal: Double(max(goal, 1)))
        return MilesEntry(date: Date(), progress: progress, hasData: daily != nil)
    }

    /// Reads Health directly. While the phone is locked Health can't be read,
    /// so the last good result is saved and reused.
    private func loadMiles() async -> [Date: Double]? {
        #if targetEnvironment(simulator)
        return MileageReader.sampleData()
        #else
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        if let fresh = try? await MileageReader(store: HKHealthStore()).dailyMiles(), !fresh.isEmpty {
            MilesCache.save(fresh)
            return fresh
        }
        return MilesCache.load()
        #endif
    }
}

/// Saves the last miles the widget read, in the widget's own storage.
enum MilesCache {
    private static let key = "cachedDailyMiles"

    static func save(_ miles: [Date: Double]) {
        let plain = Dictionary(uniqueKeysWithValues: miles.map { (String($0.key.timeIntervalSince1970), $0.value) })
        UserDefaults.standard.set(plain, forKey: key)
    }

    static func load() -> [Date: Double]? {
        guard let plain = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] else { return nil }
        let year = Calendar.current.component(.year, from: Date())
        var result: [Date: Double] = [:]
        for (key, value) in plain {
            guard let seconds = Double(key) else { continue }
            let day = Date(timeIntervalSince1970: seconds)
            // Ignore last year's miles after January 1.
            if Calendar.current.component(.year, from: day) == year {
                result[day] = value
            }
        }
        return result
    }
}

// MARK: - Views

struct MilesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MilesEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .systemMedium: medium
            default: small
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private var p: YearProgress { entry.progress }

    private var small: some View {
        ZStack {
            WidgetRing(fraction: p.fraction, lineWidth: 12)
            VStack(spacing: 0) {
                Text(entry.hasData ? p.total.wholeText : "–")
                    .font(Theme.bigNumber(30))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("of \(p.goal.wholeText) mi")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(22)
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            ZStack {
                WidgetRing(fraction: p.fraction, lineWidth: 12)
                Text("\(p.percent)%")
                    .font(Theme.bigNumber(20))
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.hasData ? "\(p.total.milesText) mi" : "Open 1000 Miles")
                    .font(Theme.bigNumber(26))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(p.milesLeft.wholeText) mi left · \(p.daysLeft) days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if p.isComplete {
                    Text("Goal reached! 🎉")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.good)
                } else {
                    Text("Walk \(p.dailyPaceNeeded.milesText) mi a day")
                        .font(.subheadline.weight(.semibold))
                    Text(p.aheadBy >= 0
                         ? "\(p.aheadBy.milesText) mi ahead"
                         : "\(abs(p.aheadBy).milesText) mi behind")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(p.aheadBy >= 0 ? Theme.good : Theme.orange)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var circular: some View {
        Gauge(value: p.fraction) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text(p.total.wholeText)
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("1000 Miles")
                .font(.headline)
                .widgetAccentable()
            Text("\(p.total.milesText) mi · \(p.percent)%")
                .font(.body.weight(.semibold))
            Gauge(value: p.fraction) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
        }
    }
}

/// A ring without animation (widgets are still images).
struct WidgetRing: View {
    var fraction: Double
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.coral.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(min(fraction, 1), 0.001))
                .stroke(
                    AngularGradient(colors: [Theme.orange, Theme.coral], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * max(fraction, 0.001))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

// MARK: - Widget

struct ThousandMilesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ThousandMilesWidget", intent: GoalIntent.self, provider: MilesProvider()) { entry in
            MilesWidgetView(entry: entry)
        }
        .configurationDisplayName("1000 Miles")
        .description("Your progress toward this year's goal.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct ThousandMilesWidgetBundle: WidgetBundle {
    var body: some Widget {
        ThousandMilesWidget()
    }
}
