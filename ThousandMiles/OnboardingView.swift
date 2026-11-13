import SwiftUI

/// First screen: explains the app and asks for Apple Health access.
struct OnboardingView: View {
    @Environment(HealthStore.self) private var health
    @AppStorage(SettingsKeys.healthAccessRequested) private var healthAccessRequested = false
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                ProgressRing(fraction: 0.72, lineWidth: 22)
                Image(systemName: "figure.walk")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Theme.gradient)
            }
            .frame(width: 200, height: 200)

            VStack(spacing: 12) {
                Text("Walk 1000 miles\nthis year")
                    .font(Theme.bigNumber(36))
                    .multilineTextAlignment(.center)
                Text("1000 Miles counts the walking and running distance your iPhone and Apple Watch already record in Apple Health.")
                    .font(.body)
                    .foregroundStyle(.secondary)
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
                    .background(Theme.gradient, in: Capsule())
                }
                .disabled(isWorking)

                Label("Your Health data stays on your iPhone.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
