import SwiftUI

@main
struct ThousandMilesApp: App {
    @State private var health = HealthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(health)
        }
    }
}

/// Shows the welcome screen until the user has connected Apple Health,
/// then the main tabs. Refreshes miles whenever the app comes to the front.
struct RootView: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.healthAccessRequested) private var healthAccessRequested = false

    var body: some View {
        Group {
            if healthAccessRequested {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.coral)
        .task {
            if healthAccessRequested { await health.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && healthAccessRequested {
                Task { await health.refresh() }
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "figure.walk") }
            FriendsPlaceholderScreen()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
