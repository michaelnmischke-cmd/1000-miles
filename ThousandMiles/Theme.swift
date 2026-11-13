import SwiftUI

enum Theme {
    static let orange = Color(red: 1.00, green: 0.58, blue: 0.20)
    static let coral = Color(red: 1.00, green: 0.36, blue: 0.42)
    static let good = Color(red: 0.20, green: 0.78, blue: 0.45)

    static let gradient = LinearGradient(
        colors: [orange, coral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func bigNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

enum SettingsKeys {
    static let goalMiles = "goalMiles"
    static let healthAccessRequested = "healthAccessRequested"
}

extension Double {
    /// "12.3"
    var milesText: String { formatted(.number.precision(.fractionLength(1))) }
    /// "1,000"
    var wholeText: String { formatted(.number.precision(.fractionLength(0))) }
}

/// A rounded card background used across screens.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}
