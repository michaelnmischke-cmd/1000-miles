import SwiftUI
import UIKit

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
        .tint(Theme.trail)
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
    init() {
        // Dark trail-map tab bar with a trail-blaze yellow selected tab.
        let look = UITabBarAppearance()
        look.configureWithOpaqueBackground()
        look.backgroundColor = UIColor(Theme.tabBar)
        look.shadowColor = .clear
        for item in [look.stackedLayoutAppearance, look.inlineLayoutAppearance, look.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor(Theme.tabInactive)
            item.normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.tabInactive)]
            item.selected.iconColor = UIColor(Theme.blaze)
            item.selected.titleTextAttributes = [.foregroundColor: UIColor(Theme.blaze)]
        }
        UITabBar.appearance().standardAppearance = look
        UITabBar.appearance().scrollEdgeAppearance = look
    }

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
