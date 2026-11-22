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
    /// How excited the game is: 0 calm, 1 warming up (a speed streak), 2 wild (double
    /// points, a long streak or a nearly full board). The arrow moves slowly and
    /// stays purple when calm; it speeds up and changes colour as things heat up.
    var heat = 0

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hurry = isImminent
        let warmth = heat
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                RotationArrow.draw(in: &context, size: size, now: time, hurry: hurry, heat: warmth)
            }
        }
        // Room around the board for the arrow to overflow into.
        .frame(width: side * 1.3, height: side * 1.3)
        .scaleEffect(x: isReversed ? -1 : 1, y: 1)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: isReversed)
        .shadow(color: (DecorStyle.forSkin(Skin.current.id)?.arrowDark ?? Theme.arrowDark).opacity(0.9), radius: side * 0.03, x: 0, y: 0)
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
    nonisolated private static func draw(in context: inout GraphicsContext, size: CGSize, now: Double, hurry: Bool, heat: Int) {
        // Calm play runs the arrow at well under half speed; it quickens with the game.
        let speed = heat >= 2 ? 1.25 : (heat == 1 ? 0.75 : 0.4)
        let time = now * speed
        // Purple when calm, orange when warming up, every colour in turn when wild.
        let spin = now * 0.6 - floor(now * 0.6)
        let look = DecorStyle.forSkin(Skin.current.id)
        var light = look?.arrowLight ?? Theme.arrowLight
        var dark = look?.arrowDark ?? Theme.arrowDark
        if heat >= 2 {
            light = Color(hue: spin, saturation: 0.75, brightness: 1)
            dark = Color(hue: spin, saturation: 0.95, brightness: 0.7)
        } else if heat == 1 {
            light = Color(hue: 0.09, saturation: 0.85, brightness: 1)
            dark = Color(hue: 0.04, saturation: 0.95, brightness: 0.8)
        }
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
                with: .color(light.opacity(0.75 * strength)),
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
            context.stroke(piece, with: .color(dark.opacity(fade)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            context.stroke(piece, with: .color(light.opacity(fade)), style: StrokeStyle(lineWidth: width * 0.68, lineCap: .round))
            context.stroke(piece, with: .color(Color.white.opacity(fade * 0.9)), style: StrokeStyle(lineWidth: max(1, width * 0.26), lineCap: .round))
        }

        // In a leafy theme the tail is a vine: leaves grow off it on both sides.
        if let look, look.isLeafy {
            for leaf in 0..<7 {
                let along = (Double(leaf) + 0.6) / 7.5
                let here = point(headAt - tail * along, center: center, reach: reach)
                let next = point(headAt - tail * along + 2, center: center, reach: reach)
                let heading = atan2(Double(next.y - here.y), Double(next.x - here.x))
                let sideways = leaf % 2 == 0 ? 1.0 : -1.0
                let sway = 0.12 * sin(time * 3 + Double(leaf))
                var copy = context
                copy.opacity = (1 - along * 0.7) * strength
                copy.translateBy(x: here.x, y: here.y)
                copy.rotate(by: .radians(heading + sideways * (1.0 + sway) + Double.pi / 2))
                DecorArt.leaf(in: &copy, size: board * 0.062 * CGFloat(1 - along * 0.45), light: light, dark: dark)
            }
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

        // The comet's head: a glossy ball of light with a chevron flying just ahead
        // of it, pointing the way the board will turn.
        let pulse = 1 + 0.08 * sin(time * (hurry ? 12 : 6))
        let radius = board * 0.05 * CGFloat(pulse)
        let ahead = point(headAt + 6, center: center, reach: reach)
        let behind = point(headAt - 6, center: center, reach: reach)
        let gapX = ahead.x - behind.x
        let gapY = ahead.y - behind.y
        let gap = max(0.001, (gapX * gapX + gapY * gapY).squareRoot())
        let ux = gapX / gap
        let uy = gapY / gap

        let ball = CGRect(x: headSpot.x - radius, y: headSpot.y - radius, width: radius * 2, height: radius * 2)
        let shine = Gradient(colors: [Color.white.opacity(strength), light.opacity(strength), dark.opacity(strength)])
        let lit = CGPoint(x: headSpot.x - radius * 0.35, y: headSpot.y - radius * 0.35)
        context.fill(Path(ellipseIn: ball), with: .radialGradient(shine, center: lit, startRadius: 0, endRadius: radius * 1.35))
        context.stroke(Path(ellipseIn: ball), with: .color(Color.white.opacity(0.55 * strength)), lineWidth: max(1, radius * 0.1))

        let tip = CGPoint(x: headSpot.x + ux * radius * 2.3, y: headSpot.y + uy * radius * 2.3)
        let root = CGPoint(x: headSpot.x + ux * radius * 1.35, y: headSpot.y + uy * radius * 1.35)
        let spread = radius * 0.85
        var chevron = Path()
        chevron.move(to: CGPoint(x: root.x - uy * spread, y: root.y + ux * spread))
        chevron.addLine(to: tip)
        chevron.addLine(to: CGPoint(x: root.x + uy * spread, y: root.y - ux * spread))
        let rim = StrokeStyle(lineWidth: radius * 0.62, lineCap: .round, lineJoin: .round)
        let core = StrokeStyle(lineWidth: radius * 0.34, lineCap: .round, lineJoin: .round)
        context.stroke(chevron, with: .color(dark.opacity(strength)), style: rim)
        context.stroke(chevron, with: .color(Color.white.opacity(strength)), style: core)
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
