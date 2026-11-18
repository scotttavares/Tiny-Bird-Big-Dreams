import SwiftUI
import UIKit

enum Theme {
    static let ink = Color(uiColor: MoodPalette.ink)
    static let cream = Color(uiColor: MoodPalette.cream)
    static let backdrop = LinearGradient(
        colors: [Color(uiColor: UIColor(hex: 0xC9B8FF)), Color(uiColor: UIColor(hex: 0xFFC7D9)), Color(uiColor: UIColor(hex: 0xFFE7C2))],
        startPoint: .top, endPoint: .bottom
    )

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .rounded) }
}

/// A SwiftUI rendering of a jelly, matching the SpriteKit look: glossy body plus face.
struct JellyBadge: View {
    let mood: Mood
    var size: CGFloat = 56
    var wobble = false
    @State private var squish = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Theme.ink.opacity(0.18))
                .frame(width: size * 0.9, height: size * 0.22)
                .blur(radius: size * 0.05)
                .offset(y: size * 0.47)
            Circle()
                .fill(RadialGradient(
                    colors: [MoodPalette.lightColor(mood), MoodPalette.color(mood), MoodPalette.deepColor(mood)],
                    center: UnitPoint(x: 0.36, y: 0.3), startRadius: 0, endRadius: size * 0.56
                ))
                .overlay(Circle().strokeBorder(MoodPalette.deepColor(mood).opacity(0.45), lineWidth: size * 0.05))
                .overlay(
                    Ellipse()
                        .fill(.white.opacity(0.85))
                        .frame(width: size * 0.3, height: size * 0.15)
                        .rotationEffect(.degrees(-26))
                        .offset(x: -size * 0.19, y: -size * 0.25)
                )
                .overlay(JellyFace(mood: mood).padding(size * 0.08))
                .frame(width: size, height: size)
                .scaleEffect(x: squish ? 1.08 : 1, y: squish ? 0.92 : 1, anchor: .bottom)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard wobble else { return }
            withAnimation(.easeInOut(duration: mood == .nervous ? 0.35 : 0.9).repeatForever(autoreverses: true)) {
                squish = true
            }
        }
        .accessibilityLabel("\(mood.title) jelly")
    }
}

/// The face, drawn to match `JellyNode`.
struct JellyFace: View {
    let mood: Mood

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2 / 0.92
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let ink = GraphicsContext.Shading.color(Theme.ink)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x * r, y: c.y - y * r) }
            let eyeY: CGFloat = 0.12, eyeX: CGFloat = 0.3
            switch mood {
            case .happy:
                for side: CGFloat in [-1, 1] {
                    var eye = Path()
                    eye.addArc(center: p(side * eyeX, eyeY - 0.04), radius: r * 0.12,
                               startAngle: .degrees(-27), endAngle: .degrees(-153), clockwise: true)
                    context.stroke(eye, with: ink, style: StrokeStyle(lineWidth: r * 0.08, lineCap: .round))
                    let cheek = CGRect(x: p(side * 0.52, -0.08).x - r * 0.14, y: p(0, -0.08).y - r * 0.08, width: r * 0.28, height: r * 0.16)
                    context.fill(Path(ellipseIn: cheek), with: .color(Color(uiColor: UIColor(hex: 0xFF6F91, alpha: 0.45))))
                }
                var mouth = Path()
                mouth.move(to: p(-0.2, -0.12))
                mouth.addQuadCurve(to: p(0.2, -0.12), control: p(0, -0.48))
                mouth.closeSubpath()
                context.fill(mouth, with: .color(Color(uiColor: UIColor(hex: 0x6B2A3A))))
            case .grumpy:
                drawEyes(context, p: p, r: r, size: 0.2, pupil: 0.075, y: eyeY - 0.02, spread: eyeX)
                for side: CGFloat in [-1, 1] {
                    var brow = Path()
                    brow.move(to: p(side * (eyeX + 0.16), eyeY + 0.2))
                    brow.addLine(to: p(side * (eyeX - 0.14), eyeY + 0.07))
                    context.stroke(brow, with: ink, style: StrokeStyle(lineWidth: r * 0.09, lineCap: .round))
                }
                var frown = Path()
                frown.move(to: p(-0.17, -0.3))
                frown.addQuadCurve(to: p(0.17, -0.3), control: p(0, -0.1))
                context.stroke(frown, with: ink, style: StrokeStyle(lineWidth: r * 0.08, lineCap: .round))
            case .nervous:
                drawEyes(context, p: p, r: r, size: 0.27, pupil: 0.06, y: eyeY, spread: eyeX)
                var wave = Path()
                wave.move(to: p(-0.2, -0.24))
                for i in 1...4 {
                    let x = -0.2 + CGFloat(i) * 0.1
                    wave.addQuadCurve(to: p(x, -0.24), control: p(x - 0.05, i % 2 == 0 ? -0.3 : -0.18))
                }
                context.stroke(wave, with: ink, style: StrokeStyle(lineWidth: r * 0.06, lineCap: .round))
                var drop = Path()
                drop.move(to: p(0.62, 0.56))
                drop.addQuadCurve(to: p(0.62, 0.36), control: p(0.75, 0.4))
                drop.addQuadCurve(to: p(0.62, 0.56), control: p(0.49, 0.4))
                context.fill(drop, with: .color(Color(uiColor: UIColor(hex: 0xBDEBFF))))
            }
        }
    }

    private func drawEyes(_ context: GraphicsContext, p: (CGFloat, CGFloat) -> CGPoint, r: CGFloat, size: CGFloat, pupil: CGFloat, y: CGFloat, spread: CGFloat) {
        for side: CGFloat in [-1, 1] {
            let center = p(side * spread, y)
            let white = CGRect(x: center.x - r * size / 2, y: center.y - r * size * 0.575, width: r * size, height: r * size * 1.15)
            context.fill(Path(ellipseIn: white), with: .color(.white))
            context.stroke(Path(ellipseIn: white), with: .color(Theme.ink.opacity(0.6)), lineWidth: 1)
            let dot = CGRect(x: center.x - r * pupil, y: center.y - r * pupil, width: r * pupil * 2, height: r * pupil * 2)
            context.fill(Path(ellipseIn: dot), with: .color(Theme.ink))
        }
    }
}

/// A big, squishy button.
struct JellyButtonStyle: ButtonStyle {
    var color: Color = Color(uiColor: MoodPalette.base(.happy))
    var foreground: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(19, weight: .heavy))
            .foregroundStyle(foreground)
            .padding(.horizontal, 26)
            .padding(.vertical, 15)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.75), color], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 2))
                    .shadow(color: Theme.ink.opacity(0.18), radius: 8, y: 5)
            )
            .scaleEffect(x: configuration.isPressed ? 1.06 : 1, y: configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// Round icon button used in the top bar.
struct IconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(.white.opacity(0.75)))
                .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                .shadow(color: Theme.ink.opacity(0.12), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct StarRow: View {
    let earned: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < earned ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < earned ? Color(uiColor: UIColor(hex: 0xFFB020)) : Theme.ink.opacity(0.25))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(earned) of 3 stars")
    }
}
