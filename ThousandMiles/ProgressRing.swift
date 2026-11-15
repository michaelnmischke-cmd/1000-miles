import SwiftUI

/// A small ring for hand-logged goals ("side trails", like 500 pull-ups).
/// The main miles goal is drawn as a TrailMap instead.
struct ProgressRing: View {
    var fraction: Double
    var lineWidth: CGFloat = 5
    var color: Color = Theme.forest

    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(shown, 0.001))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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
    ProgressRing(fraction: 0.74)
        .frame(width: 44, height: 44)
}
