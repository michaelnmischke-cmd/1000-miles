import SwiftUI

/// First screen: explains the app and asks for Apple Health access.
struct OnboardingView: View {
    @Environment(HealthStore.self) private var health
    @AppStorage(SettingsKeys.healthAccessRequested) private var healthAccessRequested = false
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            TrailMap(
                fraction: 0.62,
                milestones: [(0.1, "100"), (0.25, "250"), (0.5, "500"), (0.75, "750"), (1, "1000")]
            )
            .frame(height: 220)
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Text("WALK 1000 MILES\nTHIS YEAR")
                    .font(Theme.display(44))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("1000 Miles counts the walking and running distance your iPhone and Apple Watch already record in Apple Health.")
                    .font(.body)
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        isWorking = true
                        await health.requestAccess()
                        await health.refresh()
                        healthAccessRequested = true
                        isWorking = false
                    }
                } label: {
                    HStack {
                        if isWorking { ProgressView().tint(.white) }
                        Text("Connect Apple Health")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(Theme.trail, in: Capsule())
                }
                .disabled(isWorking)

                Label("Your Health data stays on your iPhone.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background {
            ZStack {
                Theme.paper
                TopoBackground()
            }
            .ignoresSafeArea()
        }
    }
}
