import SwiftUI

/// The fuller scenes of four themes (Ocean, Lava, Frost and the 80s Neon) and the big
/// moment each one plays when something special happens in the game.
extension SceneArt {
    // MARK: Ocean

    /// Shafts of light, swaying weed, fish of three kinds and drifting jellyfish.
    static func ocean(_ context: inout GraphicsContext, size: CGSize, time: Double, painted: Bool = false) {
        let w = Double(size.width)
        let h = Double(size.height)

        if !painted {
        for ray in 0..<4 {
            let x = w * (0.12 + 0.25 * Double(ray)) + sin(time * 0.3 + Double(ray)) * 20
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x + w * 0.1, y: 0))
            path.addLine(to: CGPoint(x: x - w * 0.15, y: h * 0.8))
            path.addLine(to: CGPoint(x: x - w * 0.3, y: h * 0.8))
            path.closeSubpath()
            let alpha = 0.04 + 0.025 * sin(time * 0.6 + Double(ray) * 1.3)
            context.fill(path, with: .color(Color.white.opacity(alpha)))
        }

        for stalk in 0..<8 {
            let baseX = w * (0.04 + 0.13 * Double(stalk)) + unit(stalk, 31) * 20
            let tall = h * (0.07 + 0.1 * unit(stalk, 32))
            var path = Path()
            path.move(to: CGPoint(x: baseX, y: h))
            for step in 1...8 {
                let rise = Double(step) / 8
                let sway = sin(time * 1.1 + Double(stalk) + rise * 3) * 9 * rise
                path.addLine(to: CGPoint(x: baseX + sway, y: h - tall * rise))
            }
            let green = stalk % 2 == 0 ? Color(hex: 0x2FBF7F) : Color(hex: 0x1E8F6A)
            context.stroke(path, with: .color(green.opacity(0.6)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }

        }

        let colors: [Color] = [
            Color(hex: 0xFFB067), Color(hex: 0xFFE26A), Color(hex: 0xFF8AD8), Color(hex: 0x8FF0FF), Color(hex: 0xFF9484),
        ]
        for index in 0..<9 {
            let goesRight = index % 2 == 0
            let length = 22 + unit(index, 41) * 30
            let period = 14 + unit(index, 42) * 14
            let progress = fraction(time / period + unit(index, 43))
            let span = w + length * 4
            let x = goesRight ? span * progress - length * 2 : w + length * 2 - span * progress
            let y = h * (0.12 + 0.7 * unit(index, 44)) + sin(time * 0.9 + Double(index)) * 8
            fish(&context, x: x, y: y, length: length, color: colors[index % colors.count],
                 goesRight: goesRight, wag: sin(time * 7 + Double(index)), kind: index % 3)
        }

        for index in 0..<2 {
            let progress = fraction(time / 46 + unit(index, 47))
            let x = w * (0.2 + 0.6 * unit(index, 48)) + sin(time * 0.5 + Double(index) * 2) * 16
            let y = h * (1.1 - 1.25 * progress)
            let radius = 16 + 3 * sin(time * 2.2 + Double(index))
            jellyfish(&context, x: x, y: y, radius: radius, time: time + Double(index))
        }
    }

    /// One fish. Kind 0 is slim, kind 1 tall with fins, kind 2 striped.
    static func fish(
        _ context: inout GraphicsContext,
        x: Double, y: Double, length: Double, color: Color,
        goesRight: Bool, wag: Double, kind: Int
    ) {
        let dir: Double = goesRight ? 1 : -1
        let tall = length * (kind == 1 ? 0.7 : 0.42)
        let tailX = x - dir * length * 0.45
        var tail = Path()
        tail.move(to: CGPoint(x: tailX, y: y))
        tail.addLine(to: CGPoint(x: tailX - dir * length * 0.38, y: y - tall * 0.55 + wag * 3))
        tail.addLine(to: CGPoint(x: tailX - dir * length * 0.38, y: y + tall * 0.55 + wag * 3))
        tail.closeSubpath()
        context.fill(tail, with: .color(color.opacity(0.6)))

        if kind == 1 {
            var fins = Path()
            fins.move(to: CGPoint(x: x - length * 0.15, y: y - tall * 0.4))
            fins.addLine(to: CGPoint(x: x - dir * length * 0.2, y: y - tall * 0.95))
            fins.addLine(to: CGPoint(x: x + length * 0.15, y: y - tall * 0.4))
            fins.closeSubpath()
            fins.move(to: CGPoint(x: x - length * 0.15, y: y + tall * 0.4))
            fins.addLine(to: CGPoint(x: x - dir * length * 0.2, y: y + tall * 0.95))
            fins.addLine(to: CGPoint(x: x + length * 0.15, y: y + tall * 0.4))
            fins.closeSubpath()
            context.fill(fins, with: .color(color.opacity(0.55)))
        }

        let body = Path(ellipseIn: CGRect(x: x - length / 2, y: y - tall / 2, width: length, height: tall))
        context.fill(body, with: .color(color.opacity(0.75)))

        if kind == 2 {
            for stripe in 0..<2 {
                let stripeX = x + dir * length * (0.02 - 0.2 * Double(stripe))
                var line = Path()
                line.move(to: CGPoint(x: stripeX, y: y - tall * 0.42))
                line.addLine(to: CGPoint(x: stripeX, y: y + tall * 0.42))
                context.stroke(line, with: .color(Color.white.opacity(0.6)), lineWidth: CGFloat(length * 0.07))
            }
        }

        let eyeX = x + dir * length * 0.3
        let eye = max(2.5, length * 0.09)
        context.fill(Path(ellipseIn: CGRect(x: eyeX - eye / 2, y: y - tall * 0.12 - eye / 2, width: eye, height: eye)),
                     with: .color(Color.white.opacity(0.9)))
        context.fill(Path(ellipseIn: CGRect(x: eyeX - eye / 4 + dir * eye * 0.15, y: y - tall * 0.12 - eye / 4, width: eye / 2, height: eye / 2)),
                     with: .color(Color.black.opacity(0.85)))
    }

    static func jellyfish(_ context: inout GraphicsContext, x: Double, y: Double, radius: Double, time: Double) {
        let glow = Color(hex: 0xE2B8FF)
        for strand in 0..<4 {
            let startX = x + (Double(strand) - 1.5) * radius * 0.45
            var path = Path()
            path.move(to: CGPoint(x: startX, y: y))
            for step in 1...6 {
                let down = Double(step) / 6
                let wave = sin(time * 2 + Double(strand) + down * 5) * 5 * down
                path.addLine(to: CGPoint(x: startX + wave, y: y + radius * 1.8 * down))
            }
            context.stroke(path, with: .color(glow.opacity(0.4)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        var dome = Path()
        dome.move(to: CGPoint(x: x - radius, y: y))
        dome.addArc(center: CGPoint(x: x, y: y), radius: CGFloat(radius), startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        dome.closeSubpath()
        context.fill(dome, with: .color(glow.opacity(0.45)))
        context.stroke(dome, with: .color(Color.white.opacity(0.5)), lineWidth: 1.5)
    }

    /// A shark bursts up from the bottom of the screen, jaws open, and sinks back.
    static func shark(_ context: inout GraphicsContext, size: CGSize, progress: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let rise = sin(min(1, max(0, progress)) * Double.pi)
        let eased = rise * rise * (3 - 2 * rise)
        let bodyW = w * 0.86
        let bodyH = h * 0.62
        let tipY = h - eased * bodyH * 0.92
        let cx = w / 2 + sin(progress * 22) * 5 * eased

        // Spray thrown up as it breaks the surface.
        for drop in 0..<26 {
            let angle = Double.pi * (0.12 + 0.76 * unit(drop, 71))
            let reach = eased * h * 0.34 * (0.4 + unit(drop, 72))
            let x = cx + cos(angle) * bodyW * 0.62
            let y = h - sin(angle) * reach
            let dropSize = 5 + 9 * unit(drop, 73)
            context.fill(path(.dot, center: CGPoint(x: x, y: y), size: CGFloat(dropSize)),
                         with: .color(Color.white.opacity(0.75 * eased)))
        }

        var body = Path()
        body.move(to: CGPoint(x: cx - bodyW / 2, y: tipY + bodyH * 1.1))
        body.addCurve(
            to: CGPoint(x: cx, y: tipY),
            control1: CGPoint(x: cx - bodyW / 2, y: tipY + bodyH * 0.45),
            control2: CGPoint(x: cx - bodyW * 0.2, y: tipY + bodyH * 0.02)
        )
        body.addCurve(
            to: CGPoint(x: cx + bodyW / 2, y: tipY + bodyH * 1.1),
            control1: CGPoint(x: cx + bodyW * 0.2, y: tipY + bodyH * 0.02),
            control2: CGPoint(x: cx + bodyW / 2, y: tipY + bodyH * 0.45)
        )
        body.closeSubpath()
        context.fill(
            body,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x8496AD), Color(hex: 0x3D4A5C)]),
                startPoint: CGPoint(x: cx, y: tipY),
                endPoint: CGPoint(x: cx, y: tipY + bodyH)
            )
        )

        // The pale underside round the mouth.
        let bellyW = bodyW * 0.76
        let bellyH = bodyH * 0.56
        let bellyY = tipY + bodyH * 0.58
        context.fill(Path(ellipseIn: CGRect(x: cx - bellyW / 2, y: bellyY - bellyH / 2, width: bellyW, height: bellyH)),
                     with: .color(Color(hex: 0xE9EEF5)))

        // The open mouth, wider the higher the shark has come.
        let mouthW = bodyW * 0.56
        let mouthH = bodyH * 0.34 * (0.55 + 0.45 * eased)
        let mouthY = tipY + bodyH * 0.56
        context.fill(Path(ellipseIn: CGRect(x: cx - mouthW / 2, y: mouthY - mouthH / 2, width: mouthW, height: mouthH)),
                     with: .color(Color(hex: 0x7A0F1E)))
        context.fill(Path(ellipseIn: CGRect(x: cx - mouthW * 0.36, y: mouthY - mouthH * 0.3, width: mouthW * 0.72, height: mouthH * 0.66)),
                     with: .color(Color(hex: 0x2A0308)))

        let teeth = 9
        let toothW = mouthW / Double(teeth) * 0.9
        let toothH = mouthH * 0.3
        for tooth in 0..<teeth {
            let x = cx - mouthW / 2 + mouthW * (Double(tooth) + 0.5) / Double(teeth)
            let across = (x - cx) / (mouthW / 2)
            let edge = mouthH / 2 * sqrt(max(0, 1 - across * across))
            var upper = Path()
            upper.move(to: CGPoint(x: x - toothW / 2, y: mouthY - edge))
            upper.addLine(to: CGPoint(x: x + toothW / 2, y: mouthY - edge))
            upper.addLine(to: CGPoint(x: x, y: mouthY - edge + toothH))
            upper.closeSubpath()
            var lower = Path()
            lower.move(to: CGPoint(x: x - toothW / 2, y: mouthY + edge))
            lower.addLine(to: CGPoint(x: x + toothW / 2, y: mouthY + edge))
            lower.addLine(to: CGPoint(x: x, y: mouthY + edge - toothH * 0.8))
            lower.closeSubpath()
            context.fill(upper, with: .color(Color.white))
            context.fill(lower, with: .color(Color.white))
        }

        for side in [-1.0, 1.0] {
            let eyeX = cx + side * bodyW * 0.3
            let eyeY = tipY + bodyH * 0.3
            let eye = bodyW * 0.07
            context.fill(Path(ellipseIn: CGRect(x: eyeX - eye / 2, y: eyeY - eye / 2, width: eye, height: eye)),
                         with: .color(Color.black))
            context.fill(Path(ellipseIn: CGRect(x: eyeX - eye * 0.3, y: eyeY - eye * 0.3, width: eye * 0.25, height: eye * 0.25)),
                         with: .color(Color.white.opacity(0.9)))
            let nostril = bodyW * 0.02
            context.fill(Path(ellipseIn: CGRect(x: cx + side * bodyW * 0.07 - nostril / 2, y: tipY + bodyH * 0.14, width: nostril, height: nostril * 1.6)),
                         with: .color(Color.black.opacity(0.6)))
        }
    }

    // MARK: Lava

    /// How far down the screen the crater is: where it sits in the painted backdrop.
    private static let craterY = 0.585

    /// A volcano with lava running down it, a pool of slow, bubbling lava along the
    /// bottom, and a small spurt from the crater every few seconds.
    static func volcano(_ context: inout GraphicsContext, size: CGSize, time: Double, painted: Bool = false) {
        let w = Double(size.width)
        let h = Double(size.height)
        let top = h * craterY
        let lip = top + h * 0.012
        let orange = Color(hex: 0xFF7A2E)

        let pulse = 0.5 + 0.5 * sin(time * 2)
        let halo = w * 0.26
        context.fill(
            Path(ellipseIn: CGRect(x: w / 2 - halo, y: top - halo, width: halo * 2, height: halo * 2)),
            with: .radialGradient(
                Gradient(colors: [orange.opacity(0.45 + 0.2 * pulse), orange.opacity(0)]),
                center: CGPoint(x: w / 2, y: top),
                startRadius: 0,
                endRadius: CGFloat(halo)
            )
        )

        if !painted {
        var cone = Path()
        cone.move(to: CGPoint(x: -w * 0.05, y: h))
        cone.addLine(to: CGPoint(x: w * 0.22, y: h * 0.88))
        cone.addLine(to: CGPoint(x: w * 0.40, y: top))
        cone.addLine(to: CGPoint(x: w * 0.46, y: lip))
        cone.addLine(to: CGPoint(x: w * 0.54, y: lip))
        cone.addLine(to: CGPoint(x: w * 0.60, y: top))
        cone.addLine(to: CGPoint(x: w * 0.80, y: h * 0.89))
        cone.addLine(to: CGPoint(x: w * 1.05, y: h))
        cone.closeSubpath()
        context.fill(
            cone,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x4A1A12), Color(hex: 0x120605)]),
                startPoint: CGPoint(x: w / 2, y: top),
                endPoint: CGPoint(x: w / 2, y: h)
            )
        )

        // Three streams of lava, wobbling as they run down.
        for stream in 0..<3 {
            let lean = Double(stream - 1)
            var path = Path()
            path.move(to: CGPoint(x: w * 0.5 + lean * w * 0.03, y: lip))
            for step in 1...10 {
                let down = Double(step) / 10
                let wobble = sin(down * 9 + Double(stream) * 2 + time * 0.8) * w * 0.012
                let x = w * 0.5 + lean * w * (0.03 + 0.2 * down) + wobble
                path.addLine(to: CGPoint(x: x, y: lip + (h - lip) * down))
            }
            let width = 6 + 2 * sin(time * 1.7 + Double(stream))
            context.stroke(path, with: .color(Color(hex: 0xE0321E).opacity(0.7)),
                           style: StrokeStyle(lineWidth: CGFloat(width + 6), lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(orange),
                           style: StrokeStyle(lineWidth: CGFloat(width), lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Color(hex: 0xFFE26A).opacity(0.9)),
                           style: StrokeStyle(lineWidth: CGFloat(width * 0.35), lineCap: .round, lineJoin: .round))
        }

        // The pool: a thick surface that heaves slowly.
        var pool = Path()
        pool.move(to: CGPoint(x: 0, y: h))
        for step in 0...24 {
            let x = w * Double(step) / 24
            let swell = sin(x * 0.018 + time * 1.2) * h * 0.008 + sin(x * 0.041 - time * 0.8) * h * 0.006
            pool.addLine(to: CGPoint(x: x, y: h * 0.945 + swell))
        }
        pool.addLine(to: CGPoint(x: w, y: h))
        pool.closeSubpath()
        context.fill(
            pool,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFE26A), orange, Color(hex: 0xC81E1E)]),
                startPoint: CGPoint(x: 0, y: h * 0.93),
                endPoint: CGPoint(x: 0, y: h)
            )
        )
        }

        // Bubbles swell on the pool and pop.
        for bubble in 0..<6 {
            let life = fraction(time / (2.5 + unit(bubble, 55) * 2) + unit(bubble, 56))
            guard life < 0.9 else { continue }
            let radius = 3 + 9 * life
            let x = unit(bubble, 57) * w
            let ring = Path(ellipseIn: CGRect(x: x - radius, y: h * 0.955 - radius, width: radius * 2, height: radius * 2))
            context.fill(ring, with: .color(Color(hex: 0xFFE26A).opacity(0.5 * (1 - life))))
            context.stroke(ring, with: .color(Color(hex: 0xFFF3B0).opacity(0.9 * (1 - life))), lineWidth: 1.5)
        }

        // A small spurt from the crater now and then.
        let every = 5.0
        let phase = fraction(time / every)
        if phase < 0.25 {
            let t = phase / 0.25
            let turn = Int(floor(time / every)) % 1000
            for blob in 0..<10 {
                let seed = blob + turn * 7
                let reach = (unit(seed, 51) - 0.5) * w * 0.5
                let up = h * (0.16 + 0.2 * unit(seed, 52))
                let x = w / 2 + reach * t
                let y = top - up * 2.2 * t + up * 2.4 * t * t
                let blobSize = 9 - 5 * t
                context.fill(path(.dot, center: CGPoint(x: x, y: y), size: CGFloat(blobSize + 4)),
                             with: .color(Color(hex: 0xE0321E).opacity(0.8 * (1 - t * 0.6))))
                context.fill(path(.dot, center: CGPoint(x: x, y: y), size: CGFloat(blobSize)),
                             with: .color(Color(hex: 0xFFD23F).opacity(1 - t * 0.5)))
            }
        }
    }

    /// The volcano erupts: blobs of lava arc out of the crater, land all over the
    /// screen (the board included) and drip before they fade.
    static func eruption(_ context: inout GraphicsContext, size: CGSize, progress: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let top = h * craterY
        let flash = max(0, 1 - progress * 3)
        if flash > 0 {
            context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(Color(hex: 0xFF7A2E).opacity(0.38 * flash)))
        }
        let flight = 0.42
        for blob in 0..<34 {
            let delay = unit(blob, 61) * 0.22
            let local = (progress - delay) / flight
            guard local > 0 else { continue }
            let landX = w * (0.08 + 0.84 * unit(blob, 62))
            let landY = h * (0.16 + 0.52 * unit(blob, 63))
            let radius = 8 + 14 * unit(blob, 64)
            if local < 1 {
                for trail in 0..<3 {
                    let at = max(0, local - Double(trail) * 0.06)
                    let x = w / 2 + (landX - w / 2) * at
                    let y = top + (landY - top) * at - h * 0.26 * sin(at * Double.pi)
                    let trailSize = radius * (1.6 - 0.4 * Double(trail))
                    context.fill(path(.dot, center: CGPoint(x: x, y: y), size: CGFloat(trailSize)),
                                 with: .color(Color(hex: trail == 0 ? 0xFFD23F : 0xFF5A1F).opacity(1 - 0.3 * Double(trail))))
                }
            } else {
                let left = 1 - delay - flight
                let fade = max(0, 1 - (progress - delay - flight) / left)
                let wide = radius * 2.6
                let high = radius * 1.5
                context.fill(Path(ellipseIn: CGRect(x: landX - wide / 2, y: landY - high / 2, width: wide, height: high)),
                             with: .color(Color(hex: 0xE0321E).opacity(0.9 * fade)))
                context.fill(Path(ellipseIn: CGRect(x: landX - wide * 0.3, y: landY - high * 0.35, width: wide * 0.6, height: high * 0.6)),
                             with: .color(Color(hex: 0xFFB02E).opacity(0.95 * fade)))
                // Two drips run down from the splat.
                for drip in 0..<2 {
                    let dripX = landX + (Double(drip) - 0.5) * wide * 0.5
                    let run = (1 - fade) * radius * (3 + 2 * Double(drip))
                    var line = Path()
                    line.move(to: CGPoint(x: dripX, y: landY))
                    line.addLine(to: CGPoint(x: dripX, y: landY + high * 0.4 + run))
                    context.stroke(line, with: .color(Color(hex: 0xE0321E).opacity(0.9 * fade)),
                                   style: StrokeStyle(lineWidth: CGFloat(radius * 0.45), lineCap: .round))
                }
            }
        }
    }

    // MARK: Frost

    /// Snowy pines, a blanket of snow along the bottom and a snowman.
    static func winter(_ context: inout GraphicsContext, size: CGSize, time: Double, painted: Bool = false) {
        let w = Double(size.width)
        let h = Double(size.height)
        let ground = h * 0.93

        if !painted {
        for tree in 0..<6 {
            let x = w * (0.04 + 0.17 * Double(tree)) + unit(tree, 81) * 18
            let tall = h * (0.08 + 0.05 * unit(tree, 82))
            let wide = tall * 0.5
            for tier in 0..<3 {
                let tierTop = ground - tall + tall * 0.27 * Double(tier)
                let tierWide = wide * (0.55 + 0.22 * Double(tier))
                let tierBottom = tierTop + tall * 0.46
                var branch = Path()
                branch.move(to: CGPoint(x: x, y: tierTop))
                branch.addLine(to: CGPoint(x: x + tierWide, y: tierBottom))
                branch.addLine(to: CGPoint(x: x - tierWide, y: tierBottom))
                branch.closeSubpath()
                context.fill(branch, with: .color(Color(hex: 0x12403C).opacity(0.95)))
                // Snow lying on the top of each tier.
                var snow = Path()
                snow.move(to: CGPoint(x: x, y: tierTop))
                snow.addLine(to: CGPoint(x: x + tierWide * 0.5, y: tierTop + tall * 0.23))
                snow.addLine(to: CGPoint(x: x, y: tierTop + tall * 0.16))
                snow.addLine(to: CGPoint(x: x - tierWide * 0.5, y: tierTop + tall * 0.23))
                snow.closeSubpath()
                context.fill(snow, with: .color(Color.white.opacity(0.9)))
            }
        }

        var drift = Path()
        drift.move(to: CGPoint(x: 0, y: h))
        for step in 0...24 {
            let x = w * Double(step) / 24
            drift.addLine(to: CGPoint(x: x, y: ground + sin(x * 0.021) * h * 0.008 + sin(x * 0.05 + 2) * h * 0.004))
        }
        drift.addLine(to: CGPoint(x: w, y: h))
        drift.closeSubpath()
        context.fill(
            drift,
            with: .linearGradient(
                Gradient(colors: [Color.white, Color(hex: 0xBFDCFA)]),
                startPoint: CGPoint(x: 0, y: ground),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        }

        snowman(&context, x: w * 0.82, ground: ground + h * 0.006, unitSize: w * 0.06, time: time)
    }

    static func snowman(_ context: inout GraphicsContext, x: Double, ground: Double, unitSize: Double, time: Double) {
        let base = unitSize
        let middle = unitSize * 0.74
        let head = unitSize * 0.52
        let baseY = ground - base * 0.85
        let middleY = baseY - base * 0.75 - middle * 0.55
        let headY = middleY - middle * 0.7 - head * 0.6
        let wave = sin(time * 2.4) * 0.25

        // Stick arms; the right one waves.
        var arms = Path()
        arms.move(to: CGPoint(x: x - middle * 0.8, y: middleY))
        arms.addLine(to: CGPoint(x: x - middle * 1.9, y: middleY - middle * 0.5))
        arms.move(to: CGPoint(x: x + middle * 0.8, y: middleY))
        arms.addLine(to: CGPoint(x: x + middle * 1.8, y: middleY - middle * (0.9 + wave)))
        context.stroke(arms, with: .color(Color(hex: 0x5A3B22)), style: StrokeStyle(lineWidth: CGFloat(max(2, unitSize * 0.09)), lineCap: .round))

        let balls: [(y: Double, radius: Double)] = [(baseY, base), (middleY, middle), (headY, head)]
        for ball in balls {
            let box = CGRect(x: x - ball.radius, y: ball.y - ball.radius, width: ball.radius * 2, height: ball.radius * 2)
            context.fill(
                Path(ellipseIn: box),
                with: .linearGradient(
                    Gradient(colors: [Color.white, Color(hex: 0xC4DCF5)]),
                    startPoint: CGPoint(x: x - ball.radius, y: ball.y - ball.radius),
                    endPoint: CGPoint(x: x + ball.radius, y: ball.y + ball.radius)
                )
            )
        }

        // Scarf, buttons, eyes, carrot and hat.
        let scarfY = headY + head * 0.8
        context.fill(Path(roundedRect: CGRect(x: x - head * 0.95, y: scarfY, width: head * 1.9, height: head * 0.38), cornerRadius: CGFloat(head * 0.15)),
                     with: .color(Color(hex: 0xE0321E)))
        context.fill(Path(roundedRect: CGRect(x: x + head * 0.35, y: scarfY, width: head * 0.4, height: head * 1.1), cornerRadius: CGFloat(head * 0.12)),
                     with: .color(Color(hex: 0xC02818)))
        for button in 0..<3 {
            let buttonY = middleY - middle * 0.4 + middle * 0.4 * Double(button)
            context.fill(path(.dot, center: CGPoint(x: x, y: buttonY), size: CGFloat(unitSize * 0.14)), with: .color(Color(hex: 0x1B1F2A)))
        }
        for side in [-1.0, 1.0] {
            context.fill(path(.dot, center: CGPoint(x: x + side * head * 0.36, y: headY - head * 0.18), size: CGFloat(unitSize * 0.13)),
                         with: .color(Color(hex: 0x1B1F2A)))
        }
        var carrot = Path()
        carrot.move(to: CGPoint(x: x, y: headY - head * 0.02))
        carrot.addLine(to: CGPoint(x: x - head * 0.95, y: headY + head * 0.14))
        carrot.addLine(to: CGPoint(x: x, y: headY + head * 0.26))
        carrot.closeSubpath()
        context.fill(carrot, with: .color(Color(hex: 0xFF8A2E)))
        let hat = Color(hex: 0x161A26)
        context.fill(Path(CGRect(x: x - head * 1.05, y: headY - head * 0.82, width: head * 2.1, height: head * 0.2)), with: .color(hat))
        context.fill(Path(CGRect(x: x - head * 0.65, y: headY - head * 1.75, width: head * 1.3, height: head * 1.0)), with: .color(hat))
        context.fill(Path(CGRect(x: x - head * 0.65, y: headY - head * 1.05, width: head * 1.3, height: head * 0.2)), with: .color(Color(hex: 0xE0321E)))
    }

    /// A blizzard blows across the whole screen.
    static func blizzard(_ context: inout GraphicsContext, size: CGSize, progress: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let strength = sin(min(1, max(0, progress)) * Double.pi)
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(Color.white.opacity(0.22 * strength)))
        for flake in 0..<150 {
            let x = fraction(unit(flake, 91) + progress * (0.7 + unit(flake, 92))) * w * 1.2 - w * 0.1
            let y = fraction(unit(flake, 93) + progress * 0.35) * h
            let length = 10 + 22 * unit(flake, 94)
            var streak = Path()
            streak.move(to: CGPoint(x: x, y: y))
            streak.addLine(to: CGPoint(x: x + length, y: y + length * 0.35))
            context.stroke(streak, with: .color(Color.white.opacity(0.85 * strength)),
                           style: StrokeStyle(lineWidth: CGFloat(1.5 + 2.5 * unit(flake, 95)), lineCap: .round))
        }
    }

    // MARK: 80s Neon

    /// Stars, a wire-frame mountain range on the horizon and slowly turning neon triangles.
    static func eighties(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let horizon = h * 0.8
        let pink = Color(hex: 0xFF4FD8)
        let cyan = Color(hex: 0x3FF0FF)

        for star in 0..<34 {
            let x = unit(star, 101) * w
            let y = unit(star, 102) * horizon * 0.8
            let alpha = 0.2 + 0.6 * abs(sin(time * (0.5 + unit(star, 103)) + Double(star)))
            context.fill(path(.dot, center: CGPoint(x: x, y: y), size: CGFloat(1.5 + 2 * unit(star, 104))),
                         with: .color(Color.white.opacity(alpha)))
        }

        let peaks: [(x: Double, y: Double)] = [
            (0, 0.0), (0.1, 0.06), (0.2, 0.02), (0.32, 0.1), (0.45, 0.03),
            (0.58, 0.08), (0.7, 0.01), (0.82, 0.09), (0.92, 0.04), (1, 0.0),
        ]
        var ridge = Path()
        var range = Path()
        range.move(to: CGPoint(x: 0, y: horizon))
        for (index, peak) in peaks.enumerated() {
            let point = CGPoint(x: w * peak.x, y: horizon - h * peak.y)
            if index == 0 {
                ridge.move(to: point)
            } else {
                ridge.addLine(to: point)
            }
            range.addLine(to: point)
        }
        range.addLine(to: CGPoint(x: w, y: horizon))
        range.closeSubpath()
        context.fill(range, with: .color(Color(hex: 0x0A0630).opacity(0.92)))
        for peak in peaks {
            var rib = Path()
            rib.move(to: CGPoint(x: w * peak.x, y: horizon - h * peak.y))
            rib.addLine(to: CGPoint(x: w * (0.5 + (peak.x - 0.5) * 1.15), y: horizon))
            context.stroke(rib, with: .color(cyan.opacity(0.3)), lineWidth: 1)
        }
        context.stroke(ridge, with: .color(pink.opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

        var line = Path()
        line.move(to: CGPoint(x: 0, y: horizon))
        line.addLine(to: CGPoint(x: w, y: horizon))
        context.stroke(line, with: .color(cyan.opacity(0.75)), lineWidth: 2)

        let tints: [Color] = [pink, cyan, Color(hex: 0xFFE26A)]
        for shape in 0..<3 {
            let turn = Double(shape)
            let centerX = w * (0.2 + 0.3 * turn)
            let centerY = h * (0.1 + 0.07 * turn) + sin(time * 0.5 + turn) * 10
            let radius = 16 + 6 * turn
            var triangle = Path()
            for corner in 0..<3 {
                let angle = time * 0.3 + turn + Double(corner) * 2 * Double.pi / 3
                let point = CGPoint(x: centerX + cos(angle) * radius, y: centerY + sin(angle) * radius)
                if corner == 0 {
                    triangle.move(to: point)
                } else {
                    triangle.addLine(to: point)
                }
            }
            triangle.closeSubpath()
            context.stroke(triangle, with: .color(tints[shape].opacity(0.55)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
    }

    /// Bars of laser light sweep up the screen.
    static func lasers(_ context: inout GraphicsContext, size: CGSize, progress: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let strength = sin(min(1, max(0, progress)) * Double.pi)
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(Color(hex: 0xFF4FD8).opacity(0.14 * strength)))
        for beam in 0..<7 {
            let y = h * (1 - fraction(progress * 1.4 + Double(beam) / 7))
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: w, y: y))
            let tint = beam % 2 == 0 ? Color(hex: 0xFF4FD8) : Color(hex: 0x3FF0FF)
            context.stroke(line, with: .color(tint.opacity(0.35 * strength)), lineWidth: 10)
            context.stroke(line, with: .color(Color.white.opacity(0.8 * strength)), lineWidth: 2)
        }
    }

    // MARK: Moments

    /// Every theme has a big moment of its own.
    static func hasMoment(_ backdrop: Skin.Backdrop) -> Bool {
        true
    }

    static func moment(_ backdrop: Skin.Backdrop, in context: inout GraphicsContext, size: CGSize, progress: Double) {
        switch backdrop {
        case .bubbles: shark(&context, size: size, progress: progress)
        case .embers: eruption(&context, size: size, progress: progress)
        case .snow: blizzard(&context, size: size, progress: progress)
        case .grid: lasers(&context, size: size, progress: progress)
        case .sun: flock(&context, size: size, progress: progress)
        case .hearts: bubblePop(&context, size: size, progress: progress)
        case .coins: coinRain(&context, size: size, progress: progress)
        case .lights: fireworks(&context, size: size, progress: progress)
        case .stars: warp(&context, size: size, progress: progress)
        }
    }
}

/// A theme's big moment, drawn once over the whole screen: the shark, the eruption,
/// the fireworks and so on. Skipped when the phone is set to reduce motion.
struct ThemeMoment: View {
    let backdrop: Skin.Backdrop

    static let seconds = 1.8

    @State private var start = Date()
    @State private var isOver = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if !isOver, !reduceMotion {
                let kind = backdrop
                let began = start
                TimelineView(.animation) { timeline in
                    let progress = timeline.date.timeIntervalSince(began) / Self.seconds
                    Canvas { context, size in
                        if progress >= 0, progress < 1 {
                            SceneArt.moment(kind, in: &context, size: size, progress: progress)
                        }
                    }
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(Int(Self.seconds * 1000) + 100))
            isOver = true
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Plays the theme's big moment when the game earns it: a new level, a chain, a
/// four-tile merge, or five merges before the board turns.
struct ThemeMoments: ViewModifier {
    let store: GameStore
    let sounds: SoundPlayer

    @State private var momentID = 0
    /// The scene whose moment is playing. Usually the theme's own; a shark out of a
    /// crate brings its own.
    @State private var playing = Skin.Backdrop.grid

    private func play() {
        guard SceneArt.hasMoment(Skin.current.backdrop) else { return }
        playing = Skin.current.backdrop
        momentID += 1
        sounds.play(.boom, volume: 0.8)
        // The shark does not just show its teeth: as it covers the board it throws
        // the tiles about and knocks a couple off.
        if Skin.current.backdrop == .bubbles {
            let game = store
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                if !game.stirBoard() {
                    // A move was still playing: try once more when it has finished.
                    try? await Task.sleep(for: .milliseconds(600))
                    game.stirBoard()
                }
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if momentID > 0 {
                    ThemeMoment(backdrop: playing)
                        .id(momentID)
                        .ignoresSafeArea()
                }
            }
            .onChange(of: store.levelEvent) { _, _ in
                play()
            }
            .onChange(of: store.superEvent) { _, _ in
                if store.lastSuperCount >= 4 {
                    play()
                }
            }
            .onChange(of: store.heatEvent) { _, _ in
                if store.turnMerges >= 5 {
                    play()
                }
            }
            .onChange(of: store.comboEvent) { _, _ in
                play()
            }
            .onChange(of: store.crateOpenEvent) { _, _ in
                // The shark out of a crate surfaces in any theme. The game has
                // already taken its tiles.
                if store.lastCrateFind == .shark {
                    playing = .bubbles
                    momentID += 1
                }
            }
    }
}

/// Frost only: snow settles along the top of the board, deeper the longer it is
/// left. A turn of the board shakes it off.
struct SnowCap: View {
    let side: CGFloat
    /// Changes when the board turns.
    let shakeOff: Int

    @State private var since = Date()

    var body: some View {
        let began = since
        TimelineView(.animation(minimumInterval: 0.25)) { timeline in
            let grown = min(1, max(0, timeline.date.timeIntervalSince(began) / 30))
            Canvas { context, size in
                let w = Double(size.width)
                let h = Double(size.height)
                var path = Path()
                path.move(to: CGPoint(x: w * 0.03, y: h))
                for step in 0...30 {
                    let across = Double(step) / 30
                    let bump = 0.55 + 0.25 * sin(across * 19) + 0.2 * sin(across * 43 + 1)
                    let edge = pow(sin(across * Double.pi), 0.35)
                    path.addLine(to: CGPoint(x: w * (0.03 + 0.94 * across), y: h - h * grown * bump * edge))
                }
                path.addLine(to: CGPoint(x: w * 0.97, y: h))
                path.closeSubpath()
                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [Color.white, Color(hex: 0xCFE6FF)]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: h)
                    )
                )
            }
        }
        .frame(width: side, height: side * 0.09)
        .onChange(of: shakeOff) { _, _ in
            since = Date()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
