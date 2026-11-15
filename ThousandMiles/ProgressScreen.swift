import SwiftUI
import Charts

struct ProgressScreen: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKeys.goalMiles) private var goalMiles = 1000

    private static let songURL = URL(string: "https://www.youtube.com/watch?v=tbNlMtqrYS0")!

    private var progress: YearProgress {
        YearProgress(dailyMiles: health.dailyMiles, goal: Double(goalMiles))
    }

    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusBanner
                    header
                    trailMap
                    signs
                    SideTrailsSection()
                    songButton
                    periodsSection
                    chartSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background {
                ZStack {
                    Theme.paper
                    TopoBackground()
                }
                .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await health.refresh() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Eyebrow("Day \(dayOfYear) · \(String(progress.year)) trail")
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("MILE \(Int(progress.total.rounded(.down)).formatted())")
                    .font(Theme.display(64))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(decimalPart)
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.trail)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(progress.total.milesText) miles of \(progress.goal.wholeText)")
        }
        .padding(.top, 8)
    }

    /// ".3" from 847.3
    private var decimalPart: String {
        let tenths = Int(((progress.total - progress.total.rounded(.down)) * 10).rounded(.down))
        return ".\(tenths)"
    }

    private var trailMap: some View {
        TrailMap(
            fraction: progress.fraction,
            milestones: progress.milestones.map { miles in
                (fraction: miles / progress.goal, label: miles.wholeText)
            },
            youLabel: "You · \(progress.total.milesText)"
        )
        .frame(height: 230)
        .padding(.top, 14)
    }

    private var signs: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if progress.isComplete {
                    sign(label: "Summit reached", value: "\(progress.total.milesText) MI")
                    sign(label: "Bonus miles", value: "\((progress.total - progress.goal).milesText) MI")
                } else {
                    sign(label: "To the summit", value: "\(progress.milesLeft.milesText) MI")
                    sign(label: "Daily pace", value: "\(progress.dailyPaceNeeded.milesText) MI")
                }
            }
            if !progress.isComplete {
                let ahead = progress.aheadBy
                Label(ahead >= 0
                      ? "\(ahead.milesText) mi ahead of pace · \(progress.daysLeft) days left"
                      : "\(abs(ahead).milesText) mi behind pace · \(progress.daysLeft) days left",
                      systemImage: ahead >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ahead >= 0 ? Theme.forest : Theme.trail)
            }
        }
    }

    private func sign(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .opacity(0.85)
            Text(value)
                .font(Theme.display(24, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .signPlate()
    }

    private var songButton: some View {
        Button {
            openURL(Self.songURL)
        } label: {
            Label("Play the song", systemImage: "music.note")
                .font(.system(size: 12, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(Theme.ink)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Theme.ink, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch health.status {
        case .unavailable:
            banner("Apple Health isn't available on this device.", icon: "exclamationmark.triangle.fill")
        case .failed(let message):
            banner("Couldn't read Health data: \(message)", icon: "exclamationmark.triangle.fill")
        case .needsPermission:
            VStack(alignment: .leading, spacing: 12) {
                Label("1000 Miles needs permission to read your walking and running distance from Apple Health.", systemImage: "heart.text.square.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkMuted)
                Button {
                    Task {
                        await health.requestAccess()
                        await health.refresh()
                    }
                } label: {
                    Text("Connect Apple Health")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(Theme.trail, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.trail.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .ready where health.dailyMiles.isEmpty:
            banner("No miles yet this year. If you've been walking, check that 1000 Miles is allowed to read Walking + Running Distance and Steps in the Health app (Profile > Apps > 1000 Miles).", icon: "heart.text.square.fill")
        default:
            if health.isShowingSampleData {
                banner("Showing sample miles because the Simulator has no step data.", icon: "info.circle.fill")
            }
        }
    }

    private var periodsSection: some View {
        HStack {
            stat(value: progress.today.milesText, label: "today")
            stat(value: progress.thisWeek.milesText, label: "this week")
            stat(value: progress.thisMonth.milesText, label: "this month")
        }
        .card()
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Miles per week")

            if progress.weeks.isEmpty {
                Text("Your weekly miles will show up here.")
                    .foregroundStyle(Theme.inkMuted)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(progress.weeks) { week in
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Miles", week.miles)
                        )
                        .foregroundStyle(Theme.trail)
                        .cornerRadius(2)
                    }
                    RuleMark(y: .value("Weekly target", progress.weeklyTarget))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Theme.inkMuted)
                        .annotation(position: .top, alignment: .leading) {
                            Text("\(progress.weeklyTarget.milesText) mi/week on pace")
                                .font(.caption2)
                                .foregroundStyle(Theme.inkMuted)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.track)
                        AxisValueLabel().foregroundStyle(Theme.inkMuted)
                    }
                }
                .frame(height: 160)
            }
        }
        .card()
    }

    // MARK: - Helpers

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.display(28, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func banner(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(Theme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.trail.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
