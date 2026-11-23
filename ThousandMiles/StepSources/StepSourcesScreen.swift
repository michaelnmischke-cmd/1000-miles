import AuthenticationServices
import SwiftUI

/// Settings > Step sources: where your miles come from, and connecting Fitbit.
struct StepSourcesScreen: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(\.openURL) private var openURL
    @State private var confirmDisconnect = false

    /// Popular devices and apps that send steps to Apple Health on their own.
    private let healthPartners = [
        "WHOOP", "Garmin Connect", "Oura", "Polar Flow", "COROS",
        "Withings", "Zepp (Amazfit)", "Ultrahuman", "Strava", "Nike Run Club",
    ]

    var body: some View {
        let fitbit = health.fitbit
        Form {
            Section {
                Label("Apple Health", systemImage: "heart.fill")
                    .foregroundStyle(Theme.ink)
                if health.healthSourceNames.isEmpty {
                    Text("No steps yet this year.")
                        .foregroundStyle(Theme.inkMuted)
                } else {
                    ForEach(health.healthSourceNames, id: \.self) { name in
                        Label(name, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.ink)
                            .symbolRenderingMode(.multicolor)
                    }
                }
            } header: {
                Text("Counting now")
            } footer: {
                Text("These apps and devices sent steps or distance to Apple Health this year, so they already count toward your miles.")
            }

            Section {
                DisclosureGroup("How to add one") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Most trackers can send steps to Apple Health, including \(ListFormatter.localizedString(byJoining: healthPartners)).")
                        Text("1. Open the tracker's app on your iPhone.")
                        Text("2. In its settings, find Apple Health. It's often under Connected Apps, Integrations or Partner Apps.")
                        Text("3. Turn it on and allow Steps, plus Walking + Running Distance if it's offered.")
                        Text("4. Come back here and pull down on the Progress screen. It shows up in the list above once it has synced.")
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.vertical, 4)
                }
                Button("Open the Health app") {
                    if let url = URL(string: "x-apple-health://") { openURL(url) }
                }
            } header: {
                Text("WHOOP, Garmin, Oura and more")
            }

            Section {
                fitbitRow(fitbit)
            } header: {
                Text("Fitbit")
            } footer: {
                Text(fitbitFooter(fitbit))
            }

            Section("No double counting") {
                Text("A walk can be seen by your iPhone, your watch and your Fitbit at once, so sources are never added together. For each day, the source that saw the most wins. Inside Apple Health, Health itself merges overlapping devices.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            ZStack {
                Theme.paper
                TopoBackground()
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Step sources")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Disconnect Fitbit?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) {
                Task {
                    await fitbit.disconnect()
                    health.mergeSources()
                }
            }
        } message: {
            Text("Fitbit steps stop counting toward your miles. Your Fitbit account isn't changed.")
        }
    }

    @ViewBuilder
    private func fitbitRow(_ fitbit: FitbitConnection) -> some View {
        if !fitbit.isAvailable {
            Label("Coming soon", systemImage: "clock")
                .foregroundStyle(Theme.inkMuted)
        } else if fitbit.isConnected {
            LabeledContent {
                if fitbit.isWorking {
                    ProgressView()
                } else if let synced = fitbit.lastSynced {
                    Text(synced, format: .relative(presentation: .named))
                }
            } label: {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.forest)
            }
            Button("Sync now") {
                Task {
                    await fitbit.sync()
                    health.mergeSources()
                }
            }
            Button("Disconnect Fitbit", role: .destructive) { confirmDisconnect = true }
        } else {
            Button {
                Task {
                    await fitbit.connect { url, scheme in
                        try await webAuthenticationSession.authenticate(using: url, callbackURLScheme: scheme)
                    }
                    health.mergeSources()
                }
            } label: {
                HStack {
                    Label("Connect Fitbit", systemImage: "link")
                    Spacer()
                    if fitbit.isWorking { ProgressView() }
                }
            }
            .disabled(fitbit.isWorking)
        }

        if let problem = fitbit.problem {
            Label(problem, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Theme.trail)
        }
    }

    private func fitbitFooter(_ fitbit: FitbitConnection) -> String {
        if !fitbit.isAvailable {
            return "Fitbit doesn't send steps to Apple Health, so 1000 Miles will connect to it directly through your Google account. This isn't switched on in this version yet."
        }
        if fitbit.isConnected {
            return "Fitbit steps are turned into miles using your stride. Home screen widgets don't include Fitbit miles yet; the app does."
        }
        return "Fitbit doesn't send steps to Apple Health, so 1000 Miles reads them directly. You'll sign in with the Google account your Fitbit uses. Only your daily step counts are read, and they stay on this iPhone."
    }
}
