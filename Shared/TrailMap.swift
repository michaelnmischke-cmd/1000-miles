import SwiftUI

/// The year drawn as a trail: dotted where you still have to walk, solid where you've been,
/// wooden signs at each milestone, and a pin where you are now.
/// Used on the Progress screen, the onboarding screen and (without signs) the small widget.
struct TrailMap: View {
    /// How far along the year's goal you are, 0 to 1.
    var fraction: Double
    /// Milestones as (fraction of goal, label), e.g. (0.25, "250").
    var milestones: [(fraction: Double, label: String)] = []
    /// Text on the "you are here" tag, e.g. "You · 847.3". Nil hides the tag.
    var youLabel: String? = nil
    var lineWidth: CGFloat = 5
    var pinSize: CGFloat = 12
    /// Widgets are still images, so they skip the fill-up animation.
    var animated = true

    @State private var shown: Double = 0

    private var drawn: Double { animated ? shown : min(max(fraction, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let here = TrailShape.point(at: drawn, in: rect)
            ZStack(alignment: .topLeading) {
                TrailShape()
                    .stroke(Theme.path, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [0.5, lineWidth * 1.8]))
                TrailShape()
                    .trim(from: 0, to: max(drawn, 0.001))
                    .stroke(Theme.trail, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                ForEach(Array(milestones.enumerated()), id: \.offset) { _, m in
                    let pt = TrailShape.point(at: m.fraction, in: rect)
                    MilestoneSign(text: m.label, isSummit: m.fraction >= 1)
                        // The sign's post ends on the trail.
                        .position(x: pt.x, y: pt.y - 12.5)
                }

                // "You are here"
                Circle()
                    .fill(Theme.trail.opacity(0.25))
                    .frame(width: pinSize * 1.9, height: pinSize * 1.9)
                    .position(here)
                Circle()
                    .fill(Theme.trail)
                    .overlay(Circle().strokeBorder(.white, lineWidth: max(pinSize / 6, 1.5)))
                    .frame(width: pinSize, height: pinSize)
                    .position(here)

                if let youLabel {
                    Text(youLabel)
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.paper)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.ink, in: Capsule())
                        .fixedSize()
                        // Put the tag on whichever side has more room.
                        .position(x: here.x > rect.midX ? here.x - 50 : here.x + 50, y: here.y)
                }
            }
        }
        .onAppear { if animated { animate(to: fraction) } }
        .onChange(of: fraction) { _, newValue in if animated { animate(to: newValue) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trail map")
        .accessibilityValue("\(Int((min(fraction, 1) * 100).rounded(.down))) percent of the way to the summit")
    }

    private func animate(to value: Double) {
        withAnimation(.spring(response: 1.4, dampingFraction: 0.9)) {
            shown = min(max(value, 0), 1)
        }
    }
}

#Preview {
    ZStack {
        Theme.paper.ignoresSafeArea()
        TopoBackground().ignoresSafeArea()
        TrailMap(
            fraction: 0.847,
            milestones: [(0.1, "100"), (0.25, "250"), (0.5, "500"), (0.75, "750"), (1, "1000")],
            youLabel: "You · 847.3"
        )
        .frame(height: 220)
        .padding()
    }
}
