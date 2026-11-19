import SwiftUI

/// The purple arrow round the board, showing which way it will turn. A faint arrow
/// stays put beside the "ROTATES IN" pill and down the board's side; a glowing comet
/// with an arrowhead swirls along it and now and then right round the board. Drawn in
/// a square the same size as the board; it overflows that square.
struct RotationArrow: View {
    let side: CGFloat
    /// True when the next move triggers the rotation.
    let isImminent: Bool
    /// True when the board will turn to the left: the arrow is drawn mirrored.
    var isReversed = false

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hurry = isImminent
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                RotationArrow.draw(in: &context, size: size, time: time, hurry: hurry)
            }
        }
        // Room around the board for the arrow to overflow into.
        .frame(width: side * 1.3, height: side * 1.3)
        .scaleEffect(x: isReversed ? -1 : 1, y: 1)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: isReversed)
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

    /// Draws the arrow in two layers. Underneath, a faint arrow that never moves, so
    /// the way the board will turn can always be read. Over it, a glowing comet with
    /// an arrowhead that swirls along the same path: most of the time it sweeps down
    /// the side of the board, every so often it flies a whole lap round it, and when
    /// the turn is one move away it laps without stopping.
    nonisolated private static func draw(in context: inout GraphicsContext, size: CGSize, time: Double, hurry: Bool) {
        // The canvas is 1.3 boards wide, so one board side is size / 1.3.
        let board = size.width / 1.3
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let reach = board * 0.585
        let thickness = board * 0.02

        let startAngle = -70.0     // beside the end of the pill
        let trailEnd = 48.0        // the bottom corner, clear of the boosters

        // Where the comet's head is, how long its tail is, and how bright it burns.
        var headAt = startAngle
        var tail = 60.0
        var strength = 1.0
        if hurry {
            let lap = time / 1.15 - floor(time / 1.15)
            headAt = startAngle + 360 * lap
            tail = 120
        } else {
            let cycle = (time / 9 - floor(time / 9)) * 9
            if cycle < 6.4 {
                // A sweep down the side of the board, four times over.
                let sweep = cycle / 1.6 - floor(cycle / 1.6)
                let eased = sweep * sweep * (3 - 2 * sweep)
                headAt = startAngle + (trailEnd - startAngle) * eased
                tail = 14 + 50 * sin(sweep * Double.pi)
                // It fades right out at each end, so nothing is left hanging there.
                strength = sin(sweep * Double.pi)
            } else {
                // One whole lap round the board.
                let lap = (cycle - 6.4) / 2.6
                let eased = lap * lap * (3 - 2 * lap)
                headAt = startAngle + 360 * eased
                tail = 30 + 80 * sin(lap * Double.pi)
            }
        }

        // The glow: the comet drawn fat and blurred, under everything else.
        var body = Path()
        body.move(to: point(headAt, center: center, reach: reach))
        var back = 0.0
        while back < tail {
            back += 3
            body.addLine(to: point(headAt - back, center: center, reach: reach))
        }
        let headSpot = point(headAt, center: center, reach: reach)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: board * 0.03))
            layer.stroke(
                body,
                with: .color(Theme.arrowLight.opacity(0.75 * strength)),
                style: StrokeStyle(lineWidth: thickness * 3.4, lineCap: .round, lineJoin: .round)
            )
            let glow = board * 0.07
            layer.fill(
                Path(ellipseIn: CGRect(x: headSpot.x - glow, y: headSpot.y - glow, width: glow * 2, height: glow * 2)),
                with: .color(Color.white.opacity(0.6 * strength))
            )
        }

        // The tail: a tube that thins and fades away from the head, with a bright core.
        let steps = 30
        for step in 0..<steps {
            let t0 = Double(step) / Double(steps)
            let t1 = Double(step + 1) / Double(steps)
            var piece = Path()
            piece.move(to: point(headAt - tail * t0, center: center, reach: reach))
            piece.addLine(to: point(headAt - tail * t1, center: center, reach: reach))
            let fade = (1 - t0) * (1 - t0) * strength
            let width = max(1, thickness * 2.3 * CGFloat(1 - t0 * 0.85))
            context.stroke(piece, with: .color(Theme.arrowDark.opacity(fade)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            context.stroke(piece, with: .color(Theme.arrowLight.opacity(fade)), style: StrokeStyle(lineWidth: width * 0.68, lineCap: .round))
            context.stroke(piece, with: .color(Color.white.opacity(fade * 0.9)), style: StrokeStyle(lineWidth: max(1, width * 0.26), lineCap: .round))
        }

        // Sparks shed along the tail.
        for spark in 0..<7 {
            let seed = sin(Double(spark) * 12.9898) * 43758.5453
            let along = seed - floor(seed)
            let flicker = 0.5 + 0.5 * sin(time * 9 + Double(spark) * 2.1)
            let drift = reach * CGFloat(1 + 0.035 * sin(time * 3 + Double(spark) * 1.7))
            let spot = point(headAt - tail * along, center: center, reach: drift)
            let dot = board * 0.012 * CGFloat(1 - along * 0.6)
            context.fill(
                Path(ellipseIn: CGRect(x: spot.x - dot, y: spot.y - dot, width: dot * 2, height: dot * 2)),
                with: .color(Color.white.opacity(0.85 * flicker * (1 - along) * strength))
            )
        }

        // The comet's own arrowhead: dark rim, light body, white heart.
        let pulse = 1 + 0.08 * sin(time * (hurry ? 12 : 6))
        let half = board * 0.058 * CGFloat(pulse)
        context.fill(arrowhead(at: headAt, center: center, reach: reach, half: half * 1.25), with: .color(Theme.arrowDark.opacity(strength)))
        context.fill(arrowhead(at: headAt, center: center, reach: reach, half: half), with: .color(Theme.arrowLight.opacity(strength)))
        context.fill(arrowhead(at: headAt, center: center, reach: reach, half: half * 0.5), with: .color(Color.white.opacity(0.95 * strength)))
    }

    /// An arrowhead on the path at `degrees`, pointing the way the angles grow.
    nonisolated private static func arrowhead(at degrees: Double, center: CGPoint, reach: CGFloat, half: CGFloat) -> Path {
        let tip = point(degrees + 6, center: center, reach: reach)
        let back = point(degrees - 6, center: center, reach: reach)
        let dx = tip.x - back.x
        let dy = tip.y - back.y
        let length = max(0.001, (dx * dx + dy * dy).squareRoot())
        let ux = dx / length
        let uy = dy / length
        // The head is as long as it is wide, whatever the path is doing at that spot.
        let tail = CGPoint(x: tip.x - ux * half * 2, y: tip.y - uy * half * 2)
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: tail.x - uy * half, y: tail.y + ux * half))
        head.addLine(to: CGPoint(x: tail.x + uy * half, y: tail.y - ux * half))
        head.closeSubpath()
        return head
    }
}
