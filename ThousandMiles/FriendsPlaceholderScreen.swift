import SwiftUI

/// Placeholder until friends and leaderboards are built (stage 3).
struct FriendsPlaceholderScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Friends are coming soon",
                systemImage: "person.2.fill",
                description: Text("Soon you'll be able to add friends, compare miles on leaderboards, and send high fives.")
            )
            .navigationTitle("Friends")
        }
    }
}
