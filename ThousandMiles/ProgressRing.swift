import SwiftUI

/// The big ring that fills up as you get closer to your goal.
struct ProgressRing: View {
    var fraction: Double
    var lineWidth: CGFloat = 26

    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.coral.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(shown, 0.001))
                .stroke(
                    AngularGradient(
                        colors: [Theme.orange, Theme.coral],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(shown, 0.001))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .onAppear { animate(to: fraction) }
        .onChange(of: fraction) { _, newValue in animate(to: newValue) }
    }

    private func animate(to value: Double) {
        withAnimation(.spring(response: 1.1, dampingFraction: 0.85)) {
            shown = min(max(value, 0), 1)
        }
    }
}

#Preview {
    ProgressRing(fraction: 0.62)
        .frame(width: 260, height: 260)
}
