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

// MARK: - Views (Trailhead look, see docs/design-trailhead.md)

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
        .containerBackground(for: .widget) {
            switch family {
            case .systemMedium: Theme.signWood
            case .systemSmall: Theme.paper
            default: Color.clear
            }
        }
    }

    private var p: YearProgress { entry.progress }

    /// Paper map: "MILE 847" with a little trail climbing in the corner.
    private var small: some View {
        ZStack(alignment: .topLeading) {
            TrailMap(fraction: p.fraction, lineWidth: 6, pinSize: 14, animated: false)
                .frame(width: 96, height: 72)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow("Mile")
                Text(entry.hasData ? p.total.wholeText : "–")
                    .font(Theme.display(40))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("of \(p.goal.wholeText)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
        }
    }

    /// Wooden trail sign with a straight trail and milestone ticks.
    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.hasData ? "MILE \(p.total.milesText)" : "OPEN 1000 MILES")
                    .font(Theme.display(32))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Eyebrow(p.isComplete ? "Summit!" : "\(p.milesLeft.wholeText) to go", color: Theme.signText)
            }
            StraightTrail(fraction: p.fraction, milestones: YearProgress.milestoneFractions)
                .frame(height: 22)
            HStack {
                Text("Jan 1")
                Spacer()
                Text(p.isComplete
                     ? "Today \(p.today.milesText) mi"
                     : (p.aheadBy >= 0
                        ? "\(p.aheadBy.milesText) mi ahead"
                        : "\(abs(p.aheadBy).milesText) mi behind"))
                    .foregroundStyle(p.aheadBy >= 0 || p.isComplete ? Theme.signText : Theme.blaze)
                Spacer()
                Text("Summit")
            }
            .font(.system(size: 10, weight: .semibold))
            .opacity(0.9)
        }
        .foregroundStyle(Theme.signText)
    }

    private var circular: some View {
        Gauge(value: p.fraction) {
            Image(systemName: "figure.hiking")
        } currentValueLabel: {
            Text(p.total.wholeText)
                .font(Theme.display(16))
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("1000 MILES")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .widgetAccentable()
            Text("\(p.total.milesText) mi · \(p.percent)%")
                .font(Theme.display(20, weight: .heavy))
            Gauge(value: p.fraction) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
        }
    }
}

/// A flat trail for the medium widget: dotted ahead, blaze-yellow behind, a tick at each milestone.
struct StraightTrail: View {
    var fraction: Double
    var milestones: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, mid = geo.size.height / 2
            let f = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                line(from: 0, to: w, y: mid)
                    .stroke(Theme.signText.opacity(0.45), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [0.5, 7]))
                line(from: 0, to: w * f, y: mid)
                    .stroke(Theme.blaze, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                ForEach(milestones, id: \.self) { m in
                    Rectangle()
                        .fill(Theme.signText)
                        .frame(width: 1.5, height: geo.size.height * 0.8)
                        .position(x: w * m, y: mid)
                }
                Circle()
                    .fill(Theme.trail)
                    .overlay(Circle().strokeBorder(Theme.signText, lineWidth: 2))
                    .frame(width: 13, height: 13)
                    .position(x: w * f, y: mid)
            }
        }
    }

    private func line(from x0: CGFloat, to x1: CGFloat, y: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: x0, y: y))
        p.addLine(to: CGPoint(x: x1, y: y))
        return p
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
