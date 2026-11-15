import SwiftUI
import Charts

struct ProgressScreen: View {
    @Environment(HealthStore.self) private var health
    @AppStorage(SettingsKeys.goalMiles) private var goalMiles = 1000

    private var progress: YearProgress {
        YearProgress(dailyMiles: health.dailyMiles, goal: Double(goalMiles))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusBanner
                    ringCard
                    paceCard
                    periodsCard
                    chartCard
                    MilestonesCard(progress: progress)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("1000 Miles")
            .refreshable { await health.refresh() }
        }
    }

    // MARK: - Sections

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
                    .foregroundStyle(.secondary)
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
                        .background(Theme.gradient, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .ready where health.dailyMiles.isEmpty:
            banner("No miles yet this year. If you've been walking, check that 1000 Miles is allowed to read Walking + Running Distance and Steps in the Health app (Profile > Apps > 1000 Miles).", icon: "heart.text.square.fill")
        default:
            if health.isShowingSampleData {
                banner("Showing sample miles because the Simulator has no step data.", icon: "info.circle.fill")
            }
        }
    }

    private var ringCard: some View {
        VStack(spacing: 20) {
            ZStack {
                ProgressRing(fraction: progress.fraction)
                VStack(spacing: 2) {
                    Text(progress.total.milesText)
                        .font(Theme.bigNumber(54))
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("of \(progress.goal.wholeText) mi")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("\(progress.percent)%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.coral)
                        .padding(.top, 4)
                }
                .padding(48)
            }
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity)

            HStack {
                stat(value: progress.milesLeft.milesText, label: "miles left")
                Divider().frame(height: 36)
                stat(value: "\(progress.daysLeft)", label: progress.daysLeft == 1 ? "day left" : "days left")
            }
        }
        .card()
    }

    private var paceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Daily pace", systemImage: "speedometer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if progress.isComplete {
                Text("Goal reached! 🎉")
                    .font(.title2.bold())
                Text("Every mile from here is a bonus.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Walk \(progress.dailyPaceNeeded.milesText) mi a day to finish on time")
                    .font(.title3.bold())
                let ahead = progress.aheadBy
                HStack(spacing: 6) {
                    Image(systemName: ahead >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    Text(ahead >= 0
                         ? "\(ahead.milesText) mi ahead of pace"
                         : "\(abs(ahead).milesText) mi behind pace")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ahead >= 0 ? Theme.good : Theme.orange)
            }
        }
        .card()
    }

    private var periodsCard: some View {
        HStack {
            stat(value: progress.today.milesText, label: "today")
            Divider().frame(height: 36)
            stat(value: progress.thisWeek.milesText, label: "this week")
            Divider().frame(height: 36)
            stat(value: progress.thisMonth.milesText, label: "this month")
        }
        .card()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Miles per week", systemImage: "chart.bar.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if progress.weeks.isEmpty {
                Text("Your weekly miles will show up here.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(progress.weeks) { week in
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Miles", week.miles)
                        )
                        .foregroundStyle(Theme.gradient)
                        .cornerRadius(3)
                    }
                    RuleMark(y: .value("Weekly target", progress.weeklyTarget))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("\(progress.weeklyTarget.milesText) mi/week on pace")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
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
                .font(Theme.bigNumber(24))
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func banner(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Badges for 10%, 25%, 50%, 75% and 100% of the goal (100, 250, 500, 750, 1000 miles by default).
struct MilestonesCard: View {
    let progress: YearProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Milestones", systemImage: "medal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(progress.milestones, id: \.self) { miles in
                    let reached = progress.total >= miles
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(reached ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color(.tertiarySystemFill)))
                            Image(systemName: reached ? "star.fill" : "lock.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(reached ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.secondary))
                        }
                        .frame(width: 44, height: 44)
                        Text(miles.wholeText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(reached ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .card()
    }
}
