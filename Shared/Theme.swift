import SwiftUI
import UIKit

/// The "Trailhead" look: your year is a hiking trail up a topo map.
/// Full design notes: docs/design-trailhead.md
/// Lives in Shared/ so the app and the widget use the same colors and shapes.
enum Theme {
    // MARK: Colors (light / dark)

    /// Screen background, like a paper map.
    static let paper = dynamic(light: 0xE4EADF, dark: 0x0F1813)
    /// Main text and lines.
    static let ink = dynamic(light: 0x1C2A22, dark: 0xE4EADF)
    /// Secondary text and small labels.
    static let inkMuted = dynamic(light: 0x5C6E61, dark: 0x8FA596)
    /// Topographic contour lines behind each screen.
    static let contour = dynamic(light: 0xB4C3B1, dark: 0x1F3027)
    /// The walked part of the trail, the "you" pin and the app's accent color.
    static let trail = dynamic(light: 0xC8452C, dark: 0xFF6B4A)
    /// The part of the trail still ahead (drawn dotted), and dashed dividers.
    static let path = dynamic(light: 0x9FB0A3, dark: 0x3D5246)
    /// Background of rings and bars.
    static let track = dynamic(light: 0xC9D3C4, dark: 0x24372D)
    /// Second accent: ahead of pace, goal rings, high fives.
    static let forest = dynamic(light: 0x2F5D46, dark: 0x7FC79B)
    /// Wooden trail-sign plates.
    static let signWood = dynamic(light: 0x3E2A1F, dark: 0x4A3324)
    /// Text on trail signs.
    static let signText = Color(hex: 0xF1E6C8)
    /// Trail-blaze yellow: selected tab, progress on wooden signs.
    static let blaze = Color(hex: 0xF2C14E)
    static let tabBar = dynamic(light: 0x1C2A22, dark: 0x070D0A)
    static let tabInactive = dynamic(light: 0x9DB2A3, dark: 0x6F8577)

    /// Kept for older call sites: "good" means ahead of pace, "behind" means behind.
    static let good = forest
    static let behind = trail

    // MARK: Type

    /// Tall, condensed signage numbers and titles (SF Pro Compressed, heavy).
    /// Use with uppercase text.
    static func display(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight).width(.compressed)
    }

    /// Kept so existing calls still compile; now uses the trail-sign style.
    static func bigNumber(_ size: CGFloat) -> Font { display(size) }

    // MARK: Helpers

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
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

// MARK: - Trail shapes

/// The S-shaped trail that climbs from bottom left to the summit at the top.
/// Drawn in a 264 x 196 design box and stretched to whatever frame it gets.
struct TrailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 264, sy = rect.height / 196
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(28, 190))
        path.addCurve(to: p(200, 144), control1: p(110, 194), control2: p(210, 176))
        path.addCurve(to: p(58, 96), control1: p(190, 114), control2: p(60, 128))
        path.addCurve(to: p(208, 46), control1: p(56, 64), control2: p(214, 80))
        path.addCurve(to: p(132, 10), control1: p(204, 22), control2: p(150, 18))
        return path
    }

    /// The point on the trail at a fraction from 0 (start) to 1 (summit).
    static func point(at fraction: Double, in rect: CGRect) -> CGPoint {
        let f = min(max(fraction, 0.0005), 1)
        let full = TrailShape().path(in: rect)
        return full.trimmedPath(from: 0, to: f).currentPoint ?? CGPoint(x: rect.minX, y: rect.maxY)
    }
}

/// Wavy contour lines, like a topographic map, drawn behind a screen.
struct TopoBackground: View {
    var lineCount = 12

    var body: some View {
        Canvas { context, size in
            let gap = size.height / CGFloat(lineCount)
            for i in 0..<lineCount {
                let y = gap * (CGFloat(i) + 0.6)
                let w = size.width
                var line = Path()
                line.move(to: CGPoint(x: -20, y: y + 20))
                line.addCurve(to: CGPoint(x: w * 0.68, y: y - 10),
                              control1: CGPoint(x: w * 0.23, y: y - 30),
                              control2: CGPoint(x: w * 0.45, y: y + 40))
                line.addCurve(to: CGPoint(x: w + 20, y: y - 20),
                              control1: CGPoint(x: w * 0.85, y: y - 40),
                              control2: CGPoint(x: w * 0.95, y: y + 10))
                context.stroke(line, with: .color(Theme.contour), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A small wooden sign on a post, used for milestones on the trail.
struct MilestoneSign: View {
    let text: String
    var isSummit = false

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 8, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.signText)
                .padding(.horizontal, 4)
                .frame(minWidth: 28, minHeight: 13)
                .background(isSummit ? Theme.trail : Theme.signWood, in: RoundedRectangle(cornerRadius: 2))
            Rectangle()
                .fill(Theme.signWood)
                .frame(width: 1.5, height: 12)
        }
    }
}

// MARK: - Cards

/// A wooden trail-sign plate with a cream inset border.
struct SignPlateStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Theme.signText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.signWood, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Theme.signText, lineWidth: 1.5)
                    .padding(3)
            )
    }
}

/// A plain section on the map: no box, just padding and a dashed rule on top.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { DashedRule() }
    }
}

/// A 1 pt dashed divider in the trail's dotted color.
struct DashedRule: View {
    var body: some View {
        Line()
            .stroke(Theme.path, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}

/// Small uppercase label above a section, like "DAY 319 · 2026 TRAIL".
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.inkMuted

    init(_ text: String, color: Color = Theme.inkMuted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
    func signPlate() -> some View { modifier(SignPlateStyle()) }
}
