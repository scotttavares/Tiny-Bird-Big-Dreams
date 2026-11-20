import SwiftUI

/// The fuller scenes and big moments of the other five themes: Sunset, Bubblegum,
/// Gold Rush, Party Lights and Galaxy.
extension SceneArt {
    // MARK: Sunset

    /// One bird, drawn as two curved wings. `flap` runs from -1 (wings down) to 1 (up).
    static func bird(_ context: inout GraphicsContext, x: Double, y: Double, span: Double, flap: Double, color: Color) {
        let tip = y - flap * span * 0.45
        var wings = Path()
        wings.move(to: CGPoint(x: x - span, y: tip))
        wings.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - span * 0.5, y: tip - span * 0.3))
        wings.addQuadCurve(to: CGPoint(x: x + span, y: tip), control: CGPoint(x: x + span * 0.5, y: tip - span * 0.3))
        context.stroke(wings, with: .color(color), style: StrokeStyle(lineWidth: CGFloat(max(1.5, span * 0.16)), lineCap: .round, lineJoin: .round))
    }

    /// A palm tree in silhouette, its fronds swaying.
    static func palm(_ context: inout GraphicsContext, x: Double, base: Double, height: Double, lean: Double, time: Double) {
        let dark = Color(hex: 0x1A0618)
        let topX = x + lean
        let topY = base - height
        var trunk = Path()
        trunk.move(to: CGPoint(x: x, y: base))
        trunk.addQuadCurve(to: CGPoint(x: topX, y: topY), control: CGPoint(x: x + lean * 0.15, y: base - height * 0.55))
        context.stroke(trunk, with: .color(dark), style: StrokeStyle(lineWidth: CGFloat(height * 0.065), lineCap: .round))
        for frond in 0..<7 {
            let spread = -200.0 + 220.0 * Double(frond) / 6
            let angle = (spread + sin(time * 1.2 + Double(frond)) * 5) * Double.pi / 180
            let length = height * 0.5
            let endX = topX + cos(angle) * length
            let endY = topY + sin(angle) * length * 0.7 + length * 0.3
            var leaf = Path()
            leaf.move(to: CGPoint(x: topX, y: topY))
            leaf.addQuadCurve(to: CGPoint(x: endX, y: endY), control: CGPoint(x: topX + cos(angle) * length * 0.6, y: topY + sin(angle) * length * 0.7 - length * 0.2))
            context.stroke(leaf, with: .color(dark), style: StrokeStyle(lineWidth: CGFloat(height * 0.045), lineCap: .round))
        }
    }

    /// The sea under the setting sun, with light glittering on it, two palms, thin
    /// clouds and a few birds.
    static func sunsetScene(_ context: inout GraphicsContext, size: CGSize, time: Double, painted: Bool = false) {
        let w = Double(size.width)
        let h = Double(size.height)
        // The painted sea starts a little higher than the drawn one.
        let horizon = h * (painted ? 0.79 : 0.9)

        if !painted {
        for cloud in 0..<3 {
            let x = fraction(time / (70 + 20 * Double(cloud)) + unit(cloud, 111)) * (w * 1.6) - w * 0.4
            let y = h * (0.1 + 0.09 * Double(cloud))
            let box = CGRect(x: x, y: y, width: w * 0.42, height: h * 0.012)
            context.fill(Path(roundedRect: box, cornerRadius: CGFloat(h * 0.006)), with: .color(Color(hex: 0xFFB3C8).opacity(0.16)))
        }

        context.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)), with: .color(Color(hex: 0x2A0A3A).opacity(0.85)))
        }

        for glint in 0..<16 {
            let depth = Double(glint) / 16
            let y = horizon + (h - horizon) * (0.08 + 0.9 * depth)
            let reach = w * (0.06 + 0.3 * depth)
            let x = w / 2 + sin(time * 1.3 + Double(glint) * 1.9) * reach * 0.5
            let alpha = 0.25 + 0.4 * abs(sin(time * 2 + Double(glint)))
            var dash = Path()
            dash.move(to: CGPoint(x: x - reach * 0.3, y: y))
            dash.addLine(to: CGPoint(x: x + reach * 0.3, y: y))
            let tint = glint % 2 == 0 ? Color(hex: 0xFFE26A) : Color(hex: 0xFF8AB8)
            context.stroke(dash, with: .color(tint.opacity(alpha)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }

        if !painted {
        palm(&context, x: w * 0.1, base: h, height: h * 0.2, lean: w * 0.07, time: time)
        palm(&context, x: w * 0.93, base: h, height: h * 0.16, lean: -w * 0.06, time: time + 2)

        }

        for index in 0..<5 {
            let progress = fraction(time / (22 + 6 * unit(index, 112)) + unit(index, 113))
            let x = progress * (w + 80) - 40
            let y = h * (0.14 + 0.22 * unit(index, 114)) + sin(time * 0.8 + Double(index)) * 6
            bird(&context, x: x, y: y, span: 7 + 4 * unit(index, 115), flap: sin(time * 6 + Double(index) * 2), color: Color(hex: 0x1A0618).opacity(0.8))
        }
    }

    /// The sun flares and a great flock of birds sweeps across the screen.
    static func flock(_ context: inout GraphicsContext, size: CGSize, progress: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let strength = sin(min(1, max(0, progress)) * Double.pi)
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(Color(hex: 0xFFB067).opacity(0.2 * strength)))
        // Rays fan out from the sun.
        for ray in 0..<12 {
            let angle = Double(ray) * Double.pi / 6 + progress * 0.8
            var wedge = Path()
            wedge.move(to: CGPoint(x: w / 2, y: h * 0.9))
            wedge.addLine(to: CGPoint(x: w / 2 + cos(angle - 0.07) * h * 1.2, y: h * 0.9 + sin(angle - 0.07) * h * 1.2))
            wedge.addLine(to: CGPoint(x: w / 2 + cos(angle + 0.07) * h * 1.2, y: h * 0.9 + sin(angle + 0.07) * h * 1.2))
            wedge.closeSubpath()
            context.fill(wedge, with: .color(Color(hex: 0xFFE26A).opacity(0.16 * strength)))
        }
        for index in 0..<42 {
            let lead = unit(index, 116) * 0.35
            let x = (progress * 1.5 - lead) * (w + 120) - 60
            let lane = unit(index, 117)
            let swoop = sin(progress * Double.pi) * h * 0.2 * (lane - 0.5)
            let bob = sin(progress * 9 + Double(index)) * 8
            let y = h * (0.12 + 0.6 * lane) - swoop + bob
            bird(&context, x: x, y: y, span: 10 + 12 * unit(index, 118), flap: sin(progress * 40 + Double(index) * 1.7), color: Color(hex: 0x1A0618).opacity(0.9))
        }
    }

    // MARK: Bubblegum

    /// Soft pastel hills, rising balloons, falling sprinkles and gum bubbles that
    /// swell and pop.
    static func candyScene(_ context: inout GraphicsContext, size: CGSize, time: Double, painted: Bool = false) {
        let w = Double(size.width)
        let h = Double(size.height)

        if !painted {
        let hills: [(x: Double, wide: Double, tall: Double, color: UInt32)] = [
            (0.15, 0.7, 0.16, 0xFF9FDC), (0.85, 0.75, 0.2, 0xC79BFF), (0.5, 0.8, 0.12, 0x9FE8FF),
        ]
        for hill in hills {
            let box = CGRect(x: w * hill.x - w * hill.wide / 2, y: h - h * hill.tall, width: w * hill.wide, height: h * hill.tall * 2)
            context.fill(Path(ellipseIn: box), with: .color(Color(hex: hill.color).opacity(0.5)))
        }

        }

        let sprinkleColors: [Color] = [Color(hex: 0xFFE26A), Color(hex: 0x86F2BC), Color(hex: 0x8FF0FF), Color.white, Color(hex: 0xFF8AD8)]
        for index in 0..<26 {
            let progress = fraction(time / (10 + 8 * unit(index, 121)) + unit(index, 122))
            let x = unit(index, 123) * w + sin(time + Double(index)) * 8
            let y = h * (-0.05 + 1.1 * progress)
            let angle = time * (1 + unit(index, 124)) + Double(index)
            var bit = Path()
            bit.move(to: CGPoint(x: x - cos(angle) * 5, y: y - sin(angle) * 5))
            bit.addLine(to: CGPoint(x: x + cos(angle) * 5, y: y + sin(angle) * 5))
            context.stroke(bit, with: .color(sprinkleColors[index % sprinkleColors.count].opacity(0.75)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        let balloonColors: [Color] = [Color(hex: 0xFF7AC8), Color(hex: 0x8FF0FF), Color(hex: 0xFFE26A), Color(hex: 0xC79BFF), Color(hex: 0x86F2BC)]
        for index in 0..<5 {
            let progress = fraction(time / (26 + 10 * unit(index, 125)) + unit(index, 126))
            let x = w * (0.1 + 0.8 * unit(index, 127)) + sin(time * 0.7 + Double(index)) * 14
            let y = h * (1.15 - 1.35 * progress)
            let wide = 30 + 12 * unit(index, 128)
            let tall = wide * 1.25
            var string = Path()
            string.move(to: CGPoint(x: x, y: y + tall / 2))
            for step in 1...6 {
                let down = Double(step) / 6
                string.addLine(to: CGPoint(x: x + sin(time * 2 + down * 6 + Double(index)) * 4, y: y + tall / 2 + down * tall * 1.2))
            }
            context.stroke(string, with: .color(Color.white.opacity(0.5)), lineWidth: 1.2)
            let tint = balloonColors[index % balloonColors.count]
            context.fill(Path(ellipseIn: CGRect(x: x - wide / 2, y: y - tall / 2, width: wide, height: tall)), with: .color(tint.opacity(0.8)))
            context.fill(Path(ellipseIn: CGRect(x: x - wide * 0.28, y: y - tall * 0.32, width: wide * 0.22, height: tall * 0.26)), with: .color(Color.white.opacity(0.55)))
            var knot = Path()
            knot.move(to: CGPoint(x: x, y: y + tall / 2 - 1))
            knot.addLine(to: CGPoint(x: x - 4, y: y + tall / 2 + 6))
            knot.addLine(to: CGPoint(x: x + 4, y: y + tall / 2 + 6))
            knot.closeSubpath()
            context.fill(knot, with: .color(tint.opacity(0.8)))
        }

        // Gum bubbles swell, then pop.
        for index in 0..<3 {
            let life = fraction(time / (5 + 2 * unit(index, 129)) + unit(index, 130))
            let x = w * (0.2 + 0.3 * Double(index)) + unit(index, 131) * 30
            let y = h * (0.86 - 0.05 * unit(index, 132))
            let full = 26 + 14 * unit(index, 133)
            if life < 0.85 {
                let radius = full * (0.15 + 0.85 * life / 0.85)
                let ball = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                context.fill(ball, with: .color(Color(hex: 0xFF9FDC).opacity(0.55)))
                context.stroke(ball, with: .color(Color.white.opacity(0.6)), lineWidth: 1.5)
                context.fill(Path(ellipseIn: CGRect(x: x - radius * 0.5, y: y - radius * 0.6, width: radius * 0.4, height: radius * 0.3)), with: .color(Color.white.opacity(0.6)))
            } else {
                let burst = (life - 0.85) / 0.15
                let radius = full * (1 + burst * 0.8)
                context.stroke(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                               with: .color(Color(hex: 0xFF9FDC).opacity(0.8 * (1 - burst))), lineWidth: 3)
            }
        }
    }

    /// One enormous gum bubble swells over the whole screen and bursts.
    static func bubblePop(_ context: inout GraphicsContext, size: CGSize, progress: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let centerX = w / 2
        let centerY = h * 0.55
        let pink = Color(hex: 0xFF8AD8)
        let swell = 0.62
        if progress < swell {
            let grown = progress / swell
            let radius = w * 0.8 * (grown * grown * (3 - 2 * grown)) + sin(progress * 40) * 3
            let ball = Path(ellipseIn: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2))
            context.fill(ball, with: .color(pink.opacity(0.42)))
            context.stroke(ball, with: .color(Color.white.opacity(0.75)), lineWidth: 3)
            context.fill(Path(ellipseIn: CGRect(x: centerX - radius * 0.55, y: centerY - radius * 0.65, width: radius * 0.42, height: radius * 0.26)),
                         with: .color(Color.white.opacity(0.6)))
        } else {
            let burst = (progress - swell) / (1 - swell)
            context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(Color.white.opacity(0.35 * max(0, 1 - burst * 3))))
            let radius = w * 0.8 * (1 + burst * 0.5)
            context.stroke(Path(ellipseIn: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2)),
                           with: .color(pink.opacity(0.9 * (1 - burst))), lineWidth: CGFloat(10 * (1 - burst) + 1))
            for drop in 0..<36 {
                let angle = unit(drop, 134) * 2 * Double.pi
                let reach = w * 0.8 * (0.9 + burst * (0.3 + 0.9 * unit(drop, 135)))
                let x = centerX + cos(angle) * reach
                let y = centerY + sin(angle) * reach + burst * burst * h * 0.2
                let dropSize = (10 + 16 * unit(drop, 136)) * (1 - burst * 0.5)
                context.fill(path(.dot, center: CGPoint(x: x, y: y), size: CGFloat(dropSize)), with: .color(pink.opacity(0.9 * (1 - burst))))
            }
        }
    }

    // MARK: Gold Rush

    /// Rocky ground with veins of gold that glint, a rail track, and a mine cart
    /// heaped with gold that rolls across.
    static func mineScene(_ context: inout GraphicsContext, size: CGSize, time: Double, painted: Bool = false) {
        let w = Double(size.width)
        let h = Double(size.height)
        let rail = h * 0.955

        if !painted {
        let crags: [(x: Double, y: Double)] = [
            (0, 0.9), (0.08, 0.86), (0.16, 0.89), (0.27, 0.83), (0.36, 0.88), (0.5, 0.85),
            (0.62, 0.89), (0.73, 0.82), (0.84, 0.88), (0.93, 0.85), (1, 0.89),
        ]
        var ridge = Path()
        ridge.move(to: CGPoint(x: 0, y: h))
        for crag in crags {
            ridge.addLine(to: CGPoint(x: w * crag.x, y: h * crag.y))
        }
        ridge.addLine(to: CGPoint(x: w, y: h))
        ridge.closeSubpath()
        context.fill(
            ridge,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x4A2E12), Color(hex: 0x1A0E04)]),
                startPoint: CGPoint(x: 0, y: h * 0.82),
                endPoint: CGPoint(x: 0, y: h)
            )
        )
        // Veins of gold in the rock.
        for vein in 0..<9 {
            let x = w * (0.06 + 0.11 * Double(vein)) + unit(vein, 141) * 14
            let y = h * (0.895 + 0.04 * unit(vein, 142))
            let alpha = 0.3 + 0.7 * abs(sin(time * (1 + unit(vein, 143)) + Double(vein)))
            context.fill(path(.diamond, center: CGPoint(x: x, y: y), size: CGFloat(6 + 5 * unit(vein, 144))),
                         with: .color(Color(hex: 0xFFE26A).opacity(alpha)))
        }

        }

        // The track: painted, with the drawn one standing in if the picture is missing.
        if !prop(&context, "prop-track", x: w / 2, y: rail, width: w * 1.04, anchor: 0.3) {
            var track = Path()
            track.move(to: CGPoint(x: 0, y: rail))
            track.addLine(to: CGPoint(x: w, y: rail))
            context.stroke(track, with: .color(Color(hex: 0x8A8F9C)), lineWidth: 3)
            for sleeper in 0..<14 {
                let x = w * (Double(sleeper) + 0.5) / 14
                var tie = Path()
                tie.move(to: CGPoint(x: x, y: rail + 2))
                tie.addLine(to: CGPoint(x: x, y: rail + 9))
                context.stroke(tie, with: .color(Color(hex: 0x5A3B22)), lineWidth: 5)
            }
        }

        // The cart rolls across, waits out of sight, and comes round again.
        let trip = fraction(time / 11)
        guard trip < 0.6 else { return }
        let cartW = w * 0.16
        let cartH = cartW * 0.5
        let x = (trip / 0.6) * (w + cartW * 2) - cartW
        // A painted cart, jolting as it rolls.
        let jolt = sin(time * 11) * 0.012
        if prop(&context, "prop-minecart", x: x, y: rail + cartW * 0.05, width: cartW * 1.7, anchor: 1, turn: jolt) {
            return
        }
        let bottom = rail - cartW * 0.11
        // The heap of gold.
        for lump in 0..<6 {
            let lumpX = x - cartW * 0.32 + cartW * 0.13 * Double(lump)
            let bump = sin(Double(lump) * 1.3 + 1)
            let lumpY = bottom - cartH - cartW * (0.02 + 0.07 * bump * bump)
            context.fill(path(.dot, center: CGPoint(x: lumpX, y: lumpY), size: CGFloat(cartW * 0.2)), with: .color(Color(hex: 0xFFD23F)))
            context.fill(path(.dot, center: CGPoint(x: lumpX - cartW * 0.02, y: lumpY - cartW * 0.03), size: CGFloat(cartW * 0.07)), with: .color(Color.white.opacity(0.8)))
        }
        var body = Path()
        body.move(to: CGPoint(x: x - cartW * 0.5, y: bottom - cartH))
        body.addLine(to: CGPoint(x: x + cartW * 0.5, y: bottom - cartH))
        body.addLine(to: CGPoint(x: x + cartW * 0.38, y: bottom))
        body.addLine(to: CGPoint(x: x - cartW * 0.38, y: bottom))
        body.closeSubpath()
        context.fill(body, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x7A6A5A), Color(hex: 0x3A2E26)]),
            startPoint: CGPoint(x: x, y: bottom - cartH),
            endPoint: CGPoint(x: x, y: bottom)
        ))
        context.stroke(body, with: .color(Color(hex: 0x1A120C)), lineWidth: 2)
        for wheel in [-1.0, 1.0] {
            let wheelX = x + wheel * cartW * 0.26
            let radius = cartW * 0.11
            context.fill(path(.dot, center: CGPoint(x: wheelX, y: rail - radius), size: CGFloat(radius * 2)), with: .color(Color(hex: 0x1A120C)))
            let turn = x / radius
            var spoke = Path()
            spoke.move(to: CGPoint(x: wheelX - cos(turn) * radius * 0.8, y: rail - radius - sin(turn) * radius * 0.8))
            spoke.addLine(to: CGPoint(x: wheelX + cos(turn) * radius * 0.8, y: rail - radius + sin(turn) * radius * 0.8))
            context.stroke(spoke, with: .color(Color(hex: 0x8A8F9C)), lineWidth: 2)
        }
    }

    /// Gold coins pour down the whole screen, spinning as they fall.
    static func coinRain(_ context: inout GraphicsContext, size: CGSize, progress: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let flash = max(0, 1 - progress * 3)
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(Color(hex: 0xFFD23F).opacity(0.3 * flash)))
        for coin in 0..<48 {
            let delay = unit(coin, 151) * 0.45
            let fall = (progress - delay) / 0.55
            guard fall > 0, fall < 1.15 else { continue }
            let x = unit(coin, 152) * w + sin(fall * 5 + Double(coin)) * 10
            let y = -40 + (h + 80) * fall * fall
            let radius = 12 + 12 * unit(coin, 153)
            let spin = abs(cos(fall * 14 + Double(coin)))
            let wide = radius * 2 * max(0.12, spin)
            let box = CGRect(x: x - wide / 2, y: y - radius, width: wide, height: radius * 2)
            context.fill(Path(ellipseIn: box), with: .color(Color(hex: 0xE8A81E)))
            context.fill(Path(ellipseIn: box.insetBy(dx: CGFloat(wide * 0.12), dy: CGFloat(radius * 0.24))), with: .color(Color(hex: 0xFFE26A)))
            context.stroke(Path(ellipseIn: box), with: .color(Color(hex: 0x9A6612)), lineWidth: 1.5)
        }
    }

    // MARK: Party Lights

    /// A mirror ball throwing beams round the room, over a dance floor whose
    /// squares light up in turn.
    static func discoScene(_ context: inout GraphicsContext, size: CGSize, time: Double, painted: Bool = false) {
        let w = Double(size.width)
        let h = Double(size.height)
        let ballX = w / 2
        let ballY = h * 0.075
        let radius = w * 0.085

        // Beams.
        for beam in 0..<6 {
            let angle = time * 0.4 + Double(beam) * Double.pi / 3
            let color = Color(hue: fraction(time * 0.06 + Double(beam) / 6), saturation: 0.8, brightness: 1)
            var wedge = Path()
            wedge.move(to: CGPoint(x: ballX, y: ballY))
            wedge.addLine(to: CGPoint(x: ballX + cos(angle - 0.08) * h * 1.2, y: ballY + abs(sin(angle - 0.08)) * h * 1.2))
            wedge.addLine(to: CGPoint(x: ballX + cos(angle + 0.08) * h * 1.2, y: ballY + abs(sin(angle + 0.08)) * h * 1.2))
            wedge.closeSubpath()
            context.fill(wedge, with: .color(color.opacity(0.08)))
        }

        if !painted {
        // The dance floor.
        let floorTop = h * 0.88
        let columns = 6
        let rows = 2
        let beat = Int(floor(time * 2))
        for row in 0..<rows {
            for column in 0..<columns {
                let lit = (column + row * 3 + beat) % 4 == 0
                let hue = fraction(Double(column) / Double(columns) + Double(row) * 0.3 + Double(beat) * 0.07)
                let box = CGRect(
                    x: w * Double(column) / Double(columns) + 2,
                    y: floorTop + (h - floorTop) * Double(row) / Double(rows) + 2,
                    width: w / Double(columns) - 4,
                    height: (h - floorTop) / Double(rows) - 4
                )
                context.fill(Path(roundedRect: box, cornerRadius: 4),
                             with: .color(Color(hue: hue, saturation: 0.75, brightness: 1).opacity(lit ? 0.55 : 0.14)))
            }
        }

        }

        // The mirror ball on its string.
        var string = Path()
        string.move(to: CGPoint(x: ballX, y: 0))
        string.addLine(to: CGPoint(x: ballX, y: ballY - radius))
        context.stroke(string, with: .color(Color.white.opacity(0.4)), lineWidth: 1.5)
        // A painted ball, swinging gently; the drawn one stands in without it.
        let swing = sin(time * 0.7) * 0.06
        if !prop(&context, "prop-mirrorball", x: ballX, y: ballY - radius * 1.9, width: radius * 1.9, anchor: 0, turn: swing) {
            let ball = Path(ellipseIn: CGRect(x: ballX - radius, y: ballY - radius, width: radius * 2, height: radius * 2))
            context.fill(
                ball,
                with: .radialGradient(
                    Gradient(colors: [Color.white, Color(hex: 0x9AA3C4), Color(hex: 0x3A3F5A)]),
                    center: CGPoint(x: ballX - radius * 0.3, y: ballY - radius * 0.3),
                    startRadius: 0,
                    endRadius: CGFloat(radius * 1.3)
                )
            )
            // Its little mirrors: rings round it and lines down it.
            for ring in 1...3 {
                let offset = radius * (Double(ring) - 2) * 0.5
                let half = sqrt(max(0, radius * radius - offset * offset))
                var line = Path()
                line.move(to: CGPoint(x: ballX - half, y: ballY + offset))
                line.addLine(to: CGPoint(x: ballX + half, y: ballY + offset))
                context.stroke(line, with: .color(Color.black.opacity(0.3)), lineWidth: 1)
            }
            for slice in 0..<5 {
                let across = fraction(time * 0.15 + Double(slice) / 5)
                let wide = radius * 2 * abs(cos(across * Double.pi))
                context.stroke(Path(ellipseIn: CGRect(x: ballX - wide / 2, y: ballY - radius, width: wide, height: radius * 2)),
                               with: .color(Color.black.opacity(0.25)), lineWidth: 1)
            }
        }
        for spark in 0..<7 {
            let around = fraction(time * 0.3 + unit(spark, 161))
            let x = ballX + (around * 2 - 1) * radius * 0.85
            let y = ballY + (unit(spark, 162) * 2 - 1) * radius * 0.7
            let alpha = sin(around * Double.pi)
            context.fill(path(.diamond, center: CGPoint(x: x, y: y), size: CGFloat(radius * 0.28)), with: .color(Color.white.opacity(alpha)))
        }
    }

    /// Fireworks go off all over the screen.
    static func fireworks(_ context: inout GraphicsContext, size: CGSize, progress: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let bursts: [(x: Double, y: Double, delay: Double, hue: Double)] = [
            (0.5, 0.4, 0.0, 0.92), (0.22, 0.26, 0.12, 0.55), (0.78, 0.3, 0.2, 0.14),
            (0.3, 0.62, 0.3, 0.33), (0.72, 0.64, 0.38, 0.78),
        ]
        for (index, burst) in bursts.enumerated() {
            let local = (progress - burst.delay) / 0.6
            guard local > 0, local < 1 else { continue }
            let centerX = w * burst.x
            let centerY = h * burst.y
            let reach = w * 0.36 * (1 - (1 - local) * (1 - local))
            let color = Color(hue: burst.hue, saturation: 0.8, brightness: 1)
            if local < 0.15 {
                let glow = w * 0.12 * (1 - local / 0.15)
                context.fill(path(.dot, center: CGPoint(x: centerX, y: centerY), size: CGFloat(glow * 2)), with: .color(Color.white.opacity(0.8)))
            }
            for spark in 0..<26 {
                let angle = Double(spark) / 26 * 2 * Double.pi + Double(index)
                let far = reach * (0.75 + 0.25 * unit(spark + index * 31, 171))
                let x = centerX + cos(angle) * far
                let y = centerY + sin(angle) * far + local * local * h * 0.06
                let inner = far * 0.82
                var trail = Path()
                trail.move(to: CGPoint(x: centerX + cos(angle) * inner, y: centerY + sin(angle) * inner + local * local * h * 0.06))
                trail.addLine(to: CGPoint(x: x, y: y))
                context.stroke(trail, with: .color(color.opacity(0.9 * (1 - local))), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                context.fill(path(.dot, center: CGPoint(x: x, y: y), size: 5), with: .color(Color.white.opacity(1 - local)))
            }
        }
    }

    // MARK: Galaxy

    /// Drifting clouds of colour, a ringed planet with a moon going round it, and a
    /// flying saucer that crosses the sky now and then.
    static func spaceScene(_ context: inout GraphicsContext, size: CGSize, time: Double, painted: Bool = false) {
        let w = Double(size.width)
        let h = Double(size.height)

        if !painted {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: CGFloat(w * 0.1)))
            let clouds: [(x: Double, y: Double, color: UInt32)] = [(0.75, 0.2, 0x7A4FFF), (0.3, 0.45, 0x1FB5B0), (0.8, 0.7, 0xE0409F)]
            for (index, cloud) in clouds.enumerated() {
                let x = w * cloud.x + sin(time * 0.1 + Double(index) * 2) * w * 0.05
                let y = h * cloud.y + cos(time * 0.08 + Double(index)) * h * 0.02
                let radius = w * 0.3
                layer.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius * 0.7, width: radius * 2, height: radius * 1.4)),
                           with: .color(Color(hex: cloud.color).opacity(0.2)))
            }
        }

        // The planet, with its ring behind and in front of it.
        let planetX = w * 0.2
        let planetY = h * 0.86
        let radius = w * 0.19
        let ringBox = CGRect(x: -radius * 1.75, y: -radius * 0.42, width: radius * 3.5, height: radius * 0.84)
        let tilt = CGAffineTransform(translationX: CGFloat(planetX), y: CGFloat(planetY)).rotated(by: -0.35)
        let ring = Path(ellipseIn: ringBox).applying(tilt)
        let ringStyle = StrokeStyle(lineWidth: CGFloat(radius * 0.16))
        context.stroke(ring, with: .color(Color(hex: 0xFFD9A0).opacity(0.55)), style: ringStyle)

        let planet = Path(ellipseIn: CGRect(x: planetX - radius, y: planetY - radius, width: radius * 2, height: radius * 2))
        context.fill(
            planet,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFB067), Color(hex: 0xC8507A), Color(hex: 0x5A2A7A)]),
                startPoint: CGPoint(x: planetX - radius, y: planetY - radius),
                endPoint: CGPoint(x: planetX + radius, y: planetY + radius)
            )
        )
        context.drawLayer { layer in
            layer.clip(to: planet)
            for band in 0..<4 {
                let y = planetY - radius * 0.7 + radius * 0.42 * Double(band)
                layer.fill(Path(CGRect(x: planetX - radius, y: y, width: radius * 2, height: radius * 0.14)),
                           with: .color(Color.white.opacity(0.12)))
            }
            // The night side.
            layer.fill(Path(ellipseIn: CGRect(x: planetX - radius * 0.55, y: planetY - radius * 0.7, width: radius * 2.2, height: radius * 2.2)),
                       with: .color(Color.black.opacity(0.28)))
        }
        // The near half of the ring crosses in front of the planet.
        context.stroke(ring.trimmedPath(from: 0, to: 0.5), with: .color(Color(hex: 0xFFD9A0).opacity(0.75)), style: ringStyle)

        // A moon going round.
        let orbit = time * 0.35
        let moonX = planetX + cos(orbit) * radius * 2.1
        let moonY = planetY - radius * 0.5 + sin(orbit) * radius * 0.55
        context.fill(path(.dot, center: CGPoint(x: moonX, y: moonY), size: CGFloat(radius * 0.26)), with: .color(Color(hex: 0xDADAE6).opacity(0.9)))

        }

        // A flying saucer crosses the top of the sky.
        let trip = fraction(time / 19)
        if trip < 0.4 {
            let across = trip / 0.4
            let x = across * (w + 120) - 60
            let y = h * 0.16 + sin(time * 2.5) * 8
            let wide = w * 0.14
            // The painted saucer, tipping as it flies; the drawn one stands in without it.
            // A little film of the saucer with its alien waving, played round and round
            // as it flies by. Without the film, its two pictures are shown in turn.
            let frame = Int(floor(time * 12)) % 50
            let film = "prop-alien-f" + (frame < 10 ? "0" : "") + String(frame)
            let pose = Int(floor(time * 3)) % 2 == 0 ? "critter-ufo" : "critter-ufo-2"
            let tilt = sin(time * 2.5) * 0.1
            let isFilmed = prop(&context, film, x: x, y: y, width: wide * 1.9, turn: tilt)
            if !isFilmed, !prop(&context, pose, x: x, y: y, width: wide * 1.5, turn: tilt) {
                context.fill(Path(ellipseIn: CGRect(x: x - wide * 0.28, y: y - wide * 0.3, width: wide * 0.56, height: wide * 0.4)),
                             with: .color(Color(hex: 0x8FF0FF).opacity(0.75)))
                context.fill(Path(ellipseIn: CGRect(x: x - wide / 2, y: y - wide * 0.12, width: wide, height: wide * 0.26)),
                             with: .color(Color(hex: 0x9AA3C4)))
                for light in 0..<4 {
                    let on = (Int(floor(time * 4)) + light) % 2 == 0
                    let lightX = x - wide * 0.33 + wide * 0.22 * Double(light)
                    context.fill(path(.dot, center: CGPoint(x: lightX, y: y + wide * 0.02), size: CGFloat(wide * 0.07)),
                                 with: .color((on ? Color(hex: 0xFFE26A) : Color(hex: 0xFF7AD9)).opacity(0.95)))
                }
            }
        }
    }

    /// The stars stretch into streaks, as if the screen had jumped to light speed,
    /// and a rocket flies across.
    static func warp(_ context: inout GraphicsContext, size: CGSize, progress: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let strength = sin(min(1, max(0, progress)) * Double.pi)
        let centerX = w / 2
        let centerY = h * 0.45
        let far = sqrt(w * w + h * h) * 0.6
        for streak in 0..<110 {
            let angle = unit(streak, 181) * 2 * Double.pi
            let from = fraction(unit(streak, 182) + progress * 1.3) * far
            let to = from * (1 + 0.35 * strength) + 6
            var line = Path()
            line.move(to: CGPoint(x: centerX + cos(angle) * from, y: centerY + sin(angle) * from))
            line.addLine(to: CGPoint(x: centerX + cos(angle) * to, y: centerY + sin(angle) * to))
            let tint = streak % 3 == 0 ? Color(hex: 0x8FF0FF) : Color.white
            context.stroke(line, with: .color(tint.opacity(0.85 * strength * (from / far + 0.2))),
                           style: StrokeStyle(lineWidth: CGFloat(1 + 2.5 * from / far), lineCap: .round))
        }

        // The rocket goes from the bottom-left to the top-right.
        let x = -w * 0.15 + progress * w * 1.3
        let y = h * 0.95 - progress * h * 0.95
        let heading = atan2(-h * 0.95, w * 1.3) + Double.pi / 2
        let length = w * 0.2
        let wide = length * 0.34
        let place = CGAffineTransform(translationX: CGFloat(x), y: CGFloat(y)).rotated(by: CGFloat(heading))

        // Its flame, flickering, and the smoke it leaves.
        var flame = Path()
        flame.move(to: CGPoint(x: -wide * 0.3, y: length * 0.45))
        flame.addLine(to: CGPoint(x: 0, y: length * (0.95 + 0.25 * sin(progress * 90))))
        flame.addLine(to: CGPoint(x: wide * 0.3, y: length * 0.45))
        flame.closeSubpath()
        context.fill(flame.applying(place), with: .color(Color(hex: 0xFF9F2E)))
        for puff in 1...8 {
            let back = Double(puff) * 0.035
            let puffX = -w * 0.15 + (progress - back) * w * 1.3
            let puffY = h * 0.95 - (progress - back) * h * 0.95
            context.fill(path(.dot, center: CGPoint(x: puffX, y: puffY), size: CGFloat(wide * (0.5 + 0.12 * Double(puff)))),
                         with: .color(Color.white.opacity(0.35 * (1 - Double(puff) / 9))))
        }

        var fins = Path()
        fins.move(to: CGPoint(x: -wide * 0.5, y: length * 0.15))
        fins.addLine(to: CGPoint(x: -wide * 1.0, y: length * 0.5))
        fins.addLine(to: CGPoint(x: -wide * 0.5, y: length * 0.42))
        fins.closeSubpath()
        fins.move(to: CGPoint(x: wide * 0.5, y: length * 0.15))
        fins.addLine(to: CGPoint(x: wide * 1.0, y: length * 0.5))
        fins.addLine(to: CGPoint(x: wide * 0.5, y: length * 0.42))
        fins.closeSubpath()
        context.fill(fins.applying(place), with: .color(Color(hex: 0xE0409F)))

        var hull = Path()
        hull.move(to: CGPoint(x: 0, y: -length * 0.55))
        hull.addQuadCurve(to: CGPoint(x: wide * 0.5, y: 0), control: CGPoint(x: wide * 0.5, y: -length * 0.35))
        hull.addLine(to: CGPoint(x: wide * 0.5, y: length * 0.45))
        hull.addLine(to: CGPoint(x: -wide * 0.5, y: length * 0.45))
        hull.addLine(to: CGPoint(x: -wide * 0.5, y: 0))
        hull.addQuadCurve(to: CGPoint(x: 0, y: -length * 0.55), control: CGPoint(x: -wide * 0.5, y: -length * 0.35))
        hull.closeSubpath()
        context.fill(hull.applying(place), with: .color(Color(hex: 0xE9EEF5)))
        let window = Path(ellipseIn: CGRect(x: -wide * 0.24, y: -length * 0.14, width: wide * 0.48, height: wide * 0.48))
        context.fill(window.applying(place), with: .color(Color(hex: 0x3FA9FF)))
        context.stroke(window.applying(place), with: .color(Color(hex: 0x5A6478)), lineWidth: 2)
    }
}
