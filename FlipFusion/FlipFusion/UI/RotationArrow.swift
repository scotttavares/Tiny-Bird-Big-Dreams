import SwiftUI

/// The purple arrow that sweeps clockwise around the board: it leaves the right end of
/// the "ROTATES IN" pill, points down the board's right side, and trails off under the
/// bottom edge. Drawn in a square the same size as the board; it overflows that square.
struct RotationArrow: View {
    let side: CGFloat
    /// True when the next move triggers the rotation.
    let isImminent: Bool

    @State private var pulse = false

    var body: some View {
        Canvas { context, size in
            RotationArrow.draw(in: &context, size: size)
        }
        // Room around the board for the arrow to overflow into.
        .frame(width: side * 1.3, height: side * 1.3)
        .shadow(color: Theme.arrowDark.opacity(0.9), radius: side * 0.03, x: 0, y: 0)
        .opacity(isImminent ? (pulse ? 1.0 : 0.5) : 0.85)
        .onChange(of: isImminent, initial: true) { _, imminent in
            if imminent {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulse = false
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A point on the rounded-square path around the board. 0° is the middle of the
    /// right side and angles grow clockwise on screen.
    nonisolated private static func point(_ degrees: Double, center: CGPoint, reach: CGFloat) -> CGPoint {
        let radians = degrees * Double.pi / 180
        let c = cos(radians)
        let s = sin(radians)
        let x = (c < 0 ? -1.0 : 1.0) * abs(c).squareRoot()
        let y = (s < 0 ? -1.0 : 1.0) * abs(s).squareRoot()
        return CGPoint(x: center.x + reach * CGFloat(x), y: center.y + reach * CGFloat(y))
    }

    nonisolated private static func draw(in context: inout GraphicsContext, size: CGSize) {
        // The canvas is 1.3 boards wide, so one board side is size / 1.3.
        let board = size.width / 1.3
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let reach = board * 0.585
        let thickness = board * 0.02

        let startAngle = -70.0     // beside the right end of the pill
        let headAngle = -24.0      // arrowhead, upper right of the board
        let trailStart = -6.0
        let trailEnd = 48.0        // the bottom-right corner, clear of the boosters

        // The shaft from the pill to the arrowhead.
        var shaft = Path()
        var angle = startAngle
        shaft.move(to: point(angle, center: center, reach: reach))
        while angle < headAngle - 6 {
            angle += 2
            shaft.addLine(to: point(angle, center: center, reach: reach))
        }
        context.stroke(
            shaft,
            with: .linearGradient(
                Gradient(colors: [Theme.arrowDark, Theme.arrowLight]),
                startPoint: point(startAngle, center: center, reach: reach),
                endPoint: point(headAngle, center: center, reach: reach)
            ),
            style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round)
        )

        // The arrowhead, pointing along the path.
        let tip = point(headAngle + 5, center: center, reach: reach)
        let back = point(headAngle - 7, center: center, reach: reach)
        let dx = tip.x - back.x
        let dy = tip.y - back.y
        let length = max(0.001, (dx * dx + dy * dy).squareRoot())
        let ux = dx / length
        let uy = dy / length
        let half = board * 0.045
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: back.x - uy * half, y: back.y + ux * half))
        head.addLine(to: CGPoint(x: back.x + uy * half, y: back.y - ux * half))
        head.closeSubpath()
        context.fill(head, with: .color(Theme.arrowLight))

        // The trail: widest at the bottom-right corner, thinning and fading to its end.
        let steps = 60
        for step in 0..<steps {
            let t0 = Double(step) / Double(steps)
            let t1 = Double(step + 1) / Double(steps)
            let a0 = trailStart + (trailEnd - trailStart) * t0
            let a1 = trailStart + (trailEnd - trailStart) * t1
            var piece = Path()
            piece.move(to: point(a0, center: center, reach: reach))
            piece.addLine(to: point(a1, center: center, reach: reach))
            // Swell up to a peak a third of the way along, then taper.
            let swell: Double = t0 < 0.35 ? 0.55 + 0.45 * (t0 / 0.35) : 1.0 - 0.9 * ((t0 - 0.35) / 0.65)
            let alpha: Double = t0 < 0.35 ? 0.95 : 0.95 - 0.75 * ((t0 - 0.35) / 0.65)
            context.stroke(
                piece,
                with: .color(Theme.arrowLight.opacity(alpha)),
                style: StrokeStyle(lineWidth: max(1, thickness * 1.5 * CGFloat(swell)), lineCap: .round)
            )
        }
    }
}
