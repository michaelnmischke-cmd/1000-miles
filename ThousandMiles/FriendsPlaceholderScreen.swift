import SwiftUI

/// Placeholder until friends and leaderboards are built (stage 3).
struct FriendsPlaceholderScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Friends are coming soon",
                systemImage: "person.2.fill",
                description: Text("Soon you'll be able to add friends, see everyone on the same trail, compare miles on leaderboards, and send high fives.")
            )
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Theme.paper
                    TopoBackground()
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Friends")
        }
    }
}
