import SwiftUI

/// The outline of a tile in a theme: a rounded square, a bubble, a cut gem and so on.
struct TileOutline: InsettableShape {
    var shape: Skin.TileShape
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        let side = min(box.width, box.height)
        switch shape {
        case .rounded, .neon:
            return RoundedRectangle(cornerRadius: side * 0.2, style: .continuous).path(in: box)
        case .jelly:
            return RoundedRectangle(cornerRadius: side * 0.36, style: .continuous).path(in: box)
        case .bubble, .orb:
            return Path(ellipseIn: box)
        case .gem:
            return TileOutline.cut(box, corner: side * 0.2)
        case .crystal:
            return TileOutline.cut(box, corner: side * 0.3)
        case .hex:
            return TileOutline.hexagon(box)
        }
    }

    func inset(by amount: CGFloat) -> TileOutline {
        var copy = self
        copy.inset += amount
        return copy
    }

    /// A square with its four corners cut off.
    private static func cut(_ box: CGRect, corner: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: box.minX + corner, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX - corner, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.minY + corner))
        path.addLine(to: CGPoint(x: box.maxX, y: box.maxY - corner))
        path.addLine(to: CGPoint(x: box.maxX - corner, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX + corner, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX, y: box.maxY - corner))
        path.addLine(to: CGPoint(x: box.minX, y: box.minY + corner))
        path.closeSubpath()
        return path
    }

    /// A six-sided tile, flat on top and bottom so wide numbers fit across the middle.
    private static func hexagon(_ box: CGRect) -> Path {
        let quarter = box.width * 0.24
        var path = Path()
        path.move(to: CGPoint(x: box.minX + quarter, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX - quarter, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.midY))
        path.addLine(to: CGPoint(x: box.maxX - quarter, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX + quarter, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX, y: box.midY))
        path.closeSubpath()
        return path
    }
}

/// The moving picture behind the game in a theme. Stands still when the phone is set
/// to reduce motion.
struct SceneView: View {
    let skin: Skin

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let backdrop = skin.backdrop
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                SceneArt.draw(backdrop, in: &context, size: size, time: time)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Draws each theme's backdrop. Nothing here is random: every speck's path is worked
/// out from its number and the time, so a backdrop looks the same wherever it is drawn.
enum SceneArt {
    /// The shapes that drift across a backdrop.
    enum Mark {
        case dot, ring, heart, star, diamond
    }

    static func draw(_ backdrop: Skin.Backdrop, in context: inout GraphicsContext, size: CGSize, time: Double) {
        switch backdrop {
        case .grid:
            eighties(&context, size: size, time: time)
            grid(&context, size: size, time: time)
            drift(&context, size: size, time: time, count: 10, mark: .diamond,
                  colors: [Color(hex: 0x8FF0FF), Color(hex: 0xFF7AD9)], sizes: 4...9, rising: true, pace: 0.6, twinkle: true)
        case .sun:
            sun(&context, size: size, time: time)
            drift(&context, size: size, time: time, count: 14, mark: .dot,
                  colors: [Color(hex: 0xFFE26A), Color(hex: 0xFF9F6A)], sizes: 2...6, rising: true, pace: 0.5, twinkle: true)
        case .bubbles:
            ocean(&context, size: size, time: time)
            drift(&context, size: size, time: time, count: 18, mark: .ring,
                  colors: [Color(hex: 0xBFF6FF), Color.white], sizes: 8...30, rising: true, pace: 1)
            drift(&context, size: size, time: time, count: 16, mark: .dot,
                  colors: [Color(hex: 0x8FF0FF)], sizes: 2...5, rising: true, pace: 1.5, salt: 40)
        case .hearts:
            drift(&context, size: size, time: time, count: 16, mark: .heart,
                  colors: [Color(hex: 0xFFB3E6), Color.white, Color(hex: 0xFF7AC8)], sizes: 10...24, rising: true, pace: 0.8)
            drift(&context, size: size, time: time, count: 12, mark: .dot,
                  colors: [Color.white], sizes: 2...5, rising: true, pace: 0.6, twinkle: true, salt: 40)
        case .embers:
            glow(&context, size: size, color: Color(hex: 0xFF5A1F), time: time)
            volcano(&context, size: size, time: time)
            drift(&context, size: size, time: time, count: 34, mark: .dot,
                  colors: [Color(hex: 0xFFD23F), Color(hex: 0xFF7A2E), Color(hex: 0xFF4A2E)], sizes: 2...6, rising: true, pace: 2.2, twinkle: true)
        case .snow:
            winter(&context, size: size, time: time)
            drift(&context, size: size, time: time, count: 40, mark: .dot,
                  colors: [Color.white, Color(hex: 0xD6F3FF)], sizes: 2...7, rising: false, pace: 0.9)
            drift(&context, size: size, time: time, count: 8, mark: .star,
                  colors: [Color.white], sizes: 8...14, rising: false, pace: 0.6, twinkle: true, salt: 40)
        case .coins:
            drift(&context, size: size, time: time, count: 26, mark: .dot,
                  colors: [Color(hex: 0xFFE26A), Color(hex: 0xF0B41F)], sizes: 3...9, rising: false, pace: 1.3)
            drift(&context, size: size, time: time, count: 12, mark: .diamond,
                  colors: [Color.white, Color(hex: 0xFFF3B0)], sizes: 6...13, rising: false, pace: 0.9, twinkle: true, salt: 40)
        case .lights:
            lights(&context, size: size, time: time)
            stars(&context, size: size, time: time, count: 30)
        case .stars:
            stars(&context, size: size, time: time, count: 70)
            shootingStar(&context, size: size, time: time)
        }
    }

    /// A number from 0 up to 1 that is always the same for the same speck and salt.
    static func unit(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return value - floor(value)
    }

    static func fraction(_ value: Double) -> Double {
        value - floor(value)
    }

    static func path(_ mark: Mark, center: CGPoint, size: CGFloat) -> Path {
        let half = size / 2
        let box = CGRect(x: center.x - half, y: center.y - half, width: size, height: size)
        switch mark {
        case .dot, .ring:
            return Path(ellipseIn: box)
        case .diamond:
            var path = Path()
            path.move(to: CGPoint(x: box.midX, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.midY))
            path.addLine(to: CGPoint(x: box.midX, y: box.maxY))
            path.addLine(to: CGPoint(x: box.minX, y: box.midY))
            path.closeSubpath()
            return path
        case .star:
            var path = Path()
            for corner in 0..<10 {
                let angle = Double(corner) * Double.pi / 5 - Double.pi / 2
                let reach = Double(corner % 2 == 0 ? half : half * 0.45)
                let point = CGPoint(x: Double(center.x) + cos(angle) * reach, y: Double(center.y) + sin(angle) * reach)
                if corner == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            return path
        case .heart:
            let bottom = CGPoint(x: box.midX, y: box.minY + size * 0.95)
            var path = Path()
            path.move(to: bottom)
            path.addCurve(
                to: CGPoint(x: box.minX, y: box.minY + size * 0.3),
                control1: CGPoint(x: box.minX + size * 0.1, y: box.minY + size * 0.7),
                control2: CGPoint(x: box.minX, y: box.minY + size * 0.5)
            )
            path.addArc(
                center: CGPoint(x: box.minX + size * 0.25, y: box.minY + size * 0.3),
                radius: size * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
            )
            path.addArc(
                center: CGPoint(x: box.minX + size * 0.75, y: box.minY + size * 0.3),
                radius: size * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
            )
            path.addCurve(
                to: bottom,
                control1: CGPoint(x: box.maxX, y: box.minY + size * 0.5),
                control2: CGPoint(x: box.minX + size * 0.9, y: box.minY + size * 0.7)
            )
            path.closeSubpath()
            return path
        }
    }

    /// Specks that float up (or fall) across the whole picture, fading in and out.
    private static func drift(
        _ context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        count: Int,
        mark: Mark,
        colors: [Color],
        sizes: ClosedRange<Double>,
        rising: Bool,
        pace: Double,
        twinkle: Bool = false,
        salt: Int = 0
    ) {
        let width = Double(size.width)
        let height = Double(size.height)
        for index in 0..<count {
            let period = (9 + unit(index, salt + 2) * 9) / pace
            let progress = fraction(time / period + unit(index, salt + 3))
            let sway = sin(time * 0.7 + Double(index)) * 10
            let x = unit(index, salt + 1) * width + sway
            let y = rising ? height * (1.1 - 1.2 * progress) : height * (-0.1 + 1.2 * progress)
            let markSize = sizes.lowerBound + unit(index, salt + 4) * (sizes.upperBound - sizes.lowerBound)
            var alpha = (0.3 + 0.5 * unit(index, salt + 5)) * sin(progress * Double.pi)
            if twinkle {
                alpha *= 0.55 + 0.45 * sin(time * 2.2 + Double(index) * 1.7)
            }
            let color = colors[index % colors.count].opacity(alpha)
            let shape = path(mark, center: CGPoint(x: x, y: y), size: CGFloat(markSize))
            if mark == .ring {
                context.stroke(shape, with: .color(color), lineWidth: 1.5)
            } else {
                context.fill(shape, with: .color(color))
            }
        }
    }

    /// Stars that stay put and twinkle.
    private static func stars(_ context: inout GraphicsContext, size: CGSize, time: Double, count: Int) {
        let width = Double(size.width)
        let height = Double(size.height)
        for index in 0..<count {
            let x = unit(index, 11) * width
            let y = unit(index, 12) * height
            let starSize = 1.5 + unit(index, 13) * 2.5
            let alpha = 0.25 + 0.7 * abs(sin(time * (0.5 + unit(index, 14)) + Double(index)))
            let shape = path(.dot, center: CGPoint(x: x, y: y), size: CGFloat(starSize))
            context.fill(shape, with: .color(Color.white.opacity(alpha)))
        }
    }

    /// A streak of light across the top of the sky every few seconds.
    private static func shootingStar(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        let every = 5.0
        let phase = fraction(time / every)
        guard phase < 0.14 else { return }
        let progress = phase / 0.14
        let turn = Int(floor(time / every))
        let width = Double(size.width)
        let height = Double(size.height)
        let startX = unit(turn, 21) * width * 0.6
        let startY = unit(turn, 22) * height * 0.35
        let headX = startX + progress * width * 0.5
        let headY = startY + progress * height * 0.16
        var trail = Path()
        trail.move(to: CGPoint(x: headX - width * 0.12, y: headY - height * 0.038))
        trail.addLine(to: CGPoint(x: headX, y: headY))
        context.stroke(trail, with: .color(Color.white.opacity(0.9 * (1 - progress))), lineWidth: 2)
        let head = path(.dot, center: CGPoint(x: headX, y: headY), size: 4)
        context.fill(head, with: .color(Color.white.opacity(1 - progress)))
    }

    /// Lines on a floor that roll toward you.
    private static func grid(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        let width = Double(size.width)
        let height = Double(size.height)
        let horizon = height * 0.8
        let roll = fraction(time * 0.25)
        for line in 0..<8 {
            let depth = (Double(line) + roll) / 8
            let y = horizon + (height - horizon) * depth * depth
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
            context.stroke(path, with: .color(Color(hex: 0xFF7AD9).opacity(0.05 + 0.22 * depth)), lineWidth: 1)
        }
        for line in -7...7 {
            var path = Path()
            path.move(to: CGPoint(x: width / 2 + Double(line) * width * 0.035, y: horizon))
            path.addLine(to: CGPoint(x: width / 2 + Double(line) * width * 0.24, y: height))
            context.stroke(path, with: .color(Color(hex: 0x3FA9FF).opacity(0.16)), lineWidth: 1)
        }
    }

    /// A big sun low in the sky, with bands of sky showing through its lower half.
    private static func sun(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        let width = Double(size.width)
        let height = Double(size.height)
        let radius = width * 0.46
        let centerX = width / 2
        let centerY = height * 0.9
        let disc = Path(ellipseIn: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2))
        let slide = fraction(time * 0.06)
        context.drawLayer { layer in
            layer.opacity = 0.5
            layer.fill(
                disc,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xFFE26A), Color(hex: 0xFF4FA3)]),
                    startPoint: CGPoint(x: centerX, y: centerY - radius),
                    endPoint: CGPoint(x: centerX, y: centerY + radius * 0.4)
                )
            )
            layer.blendMode = .destinationOut
            for band in 0..<6 {
                let depth = (Double(band) + slide) / 6
                let y = centerY - radius * 0.35 + radius * 1.1 * depth
                let thickness = 3 + 10 * depth
                layer.fill(Path(CGRect(x: 0, y: y, width: width, height: thickness)), with: .color(Color.black))
            }
        }
    }

    /// A warm glow rising from the bottom, breathing slowly.
    private static func glow(_ context: inout GraphicsContext, size: CGSize, color: Color, time: Double) {
        let width = Double(size.width)
        let height = Double(size.height)
        let strength = 0.3 + 0.1 * sin(time * 1.3)
        context.fill(
            Path(CGRect(x: 0, y: height * 0.55, width: width, height: height * 0.45)),
            with: .linearGradient(
                Gradient(colors: [color.opacity(0), color.opacity(strength)]),
                startPoint: CGPoint(x: 0, y: height * 0.55),
                endPoint: CGPoint(x: 0, y: height)
            )
        )
    }

    /// Soft coloured lights that wander about and slowly change colour.
    private static func lights(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        let width = Double(size.width)
        let height = Double(size.height)
        let radius = width * 0.36
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: CGFloat(width * 0.12)))
            for light in 0..<4 {
                let turn = Double(light)
                let x = width / 2 + cos(time * 0.35 + turn * 1.6) * width * 0.34
                let y = height * (0.2 + 0.2 * turn) + sin(time * 0.45 + turn) * height * 0.06
                let color = Color(hue: fraction(time * 0.05 + turn * 0.25), saturation: 0.8, brightness: 1)
                layer.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(color.opacity(0.3))
                )
            }
        }
    }
}

/// A shape drawn through points given as fractions of its frame (0 to 1 each way).
struct Outline: Shape {
    var points: [CGPoint]
    var isClosed = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let spot = CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
            if index == 0 {
                path.move(to: spot)
            } else {
                path.addLine(to: spot)
            }
        }
        if isClosed {
            path.closeSubpath()
        }
        return path
    }
}

/// A stone block: an uneven boulder with thickness, flat faces, cracks and speckles.
/// Each theme makes it of something else: rock, coral, ice, cooling magma and so on.
struct StoneView: View {
    let size: CGFloat
    var look: Skin.StoneLook = .rock

    /// The colours of one kind of stone.
    private struct Palette {
        /// The top face, lit corner to shaded corner.
        let face: [UInt32]
        /// The side of the block, seen below the top face.
        let side: UInt32
        let crack: UInt32
        /// Glowing cracks (magma) or pale ones (ice) are drawn wider, with a glow.
        var glow = false
    }

    private var palette: Palette {
        switch look {
        case .rock: return Palette(face: [0xC9CDD6, 0x8E93A0, 0x5A5F6B], side: 0x33363F, crack: 0x2B2F39)
        case .sandstone: return Palette(face: [0xF0D2A8, 0xC89660, 0x8A5C36], side: 0x4F3018, crack: 0x4A2E18)
        case .coral: return Palette(face: [0xFFB0A8, 0xE8647E, 0x9A3560], side: 0x5A1838, crack: 0x5A1838)
        case .candy: return Palette(face: [0xFBD0FF, 0xCE8FEA, 0x8457B0], side: 0x4A2A70, crack: 0x4A2A70)
        case .magma: return Palette(face: [0x5A4744, 0x33252A, 0x170E0E], side: 0x0C0606, crack: 0xFF8A2E, glow: true)
        case .ice: return Palette(face: [0xF2FAFF, 0xB4DBF8, 0x6AA6D8], side: 0x3A6E9E, crack: 0xFFFFFF, glow: true)
        case .nugget: return Palette(face: [0xFFEC9A, 0xE8B030, 0x9A6612], side: 0x5A3A08, crack: 0x5A3A08)
        case .mirror: return Palette(face: [0xD2C6FF, 0x8468E8, 0x43308E], side: 0x231650, crack: 0x231650)
        case .moon: return Palette(face: [0xE2E2EA, 0xA2A2B2, 0x5C5C70], side: 0x30303E, crack: 0x3A3A4A)
        }
    }

    /// The edge of the rock, clockwise from the top-left.
    private static let rim: [CGPoint] = [
        CGPoint(x: 0.24, y: 0.07), CGPoint(x: 0.63, y: 0.04), CGPoint(x: 0.90, y: 0.21),
        CGPoint(x: 0.97, y: 0.57), CGPoint(x: 0.83, y: 0.89), CGPoint(x: 0.46, y: 0.97),
        CGPoint(x: 0.13, y: 0.86), CGPoint(x: 0.03, y: 0.47),
    ]
    /// The face that catches the light, top-left.
    private static let lit: [CGPoint] = [
        CGPoint(x: 0.24, y: 0.07), CGPoint(x: 0.63, y: 0.04), CGPoint(x: 0.56, y: 0.33),
        CGPoint(x: 0.29, y: 0.41), CGPoint(x: 0.03, y: 0.47),
    ]
    /// The face in shadow, bottom-right.
    private static let shaded: [CGPoint] = [
        CGPoint(x: 0.97, y: 0.57), CGPoint(x: 0.83, y: 0.89), CGPoint(x: 0.46, y: 0.97),
        CGPoint(x: 0.52, y: 0.66), CGPoint(x: 0.75, y: 0.51),
    ]
    /// The cracks, each a line through a few points.
    private static let cracks: [[CGPoint]] = [
        [CGPoint(x: 0.29, y: 0.41), CGPoint(x: 0.56, y: 0.33), CGPoint(x: 0.75, y: 0.51), CGPoint(x: 0.97, y: 0.57)],
        [CGPoint(x: 0.56, y: 0.33), CGPoint(x: 0.52, y: 0.66), CGPoint(x: 0.46, y: 0.97)],
        [CGPoint(x: 0.52, y: 0.66), CGPoint(x: 0.33, y: 0.72), CGPoint(x: 0.13, y: 0.86)],
    ]
    /// Speckles: where (as fractions), how big (as a fraction of the size), dark or light.
    private static let speckles: [(x: CGFloat, y: CGFloat, size: CGFloat, isDark: Bool)] = [
        (0.36, 0.22, 0.05, false), (0.70, 0.30, 0.04, true), (0.20, 0.60, 0.05, true),
        (0.42, 0.52, 0.035, false), (0.66, 0.76, 0.05, true), (0.82, 0.42, 0.035, false),
        (0.30, 0.84, 0.035, true),
    ]

    var body: some View {
        let colors = palette
        let rock = Outline(points: Self.rim)
        let round = StrokeStyle(lineWidth: size * 0.09, lineCap: .round, lineJoin: .round)
        let crackWidth = max(1, size * (colors.glow ? 0.034 : 0.022))
        let crack = StrokeStyle(lineWidth: crackWidth, lineCap: .round, lineJoin: .round)
        let crackColor = Color(hex: colors.crack, opacity: colors.glow ? 1 : 0.75)
        let face = LinearGradient(
            colors: colors.face.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        // The moon's speckles are craters: bigger and all dark.
        let speckScale: CGFloat = look == .moon ? 1.9 : 1
        // The top face sits a little above the block's side, which gives it thickness.
        let depth = size * 0.09
        let top = size * 0.9 - depth

        ZStack(alignment: .top) {
            // The side of the block: the same outline, lower down and dark.
            ZStack {
                rock.stroke(Color(hex: colors.side), style: round)
                rock.fill(Color(hex: colors.side))
            }
            .frame(width: size * 0.9, height: top)
            .offset(y: depth)

            ZStack {
                // A fat rounded stroke under the fill takes the sharpness off the corners.
                rock.stroke(Color(hex: colors.face[2]), style: round)
                rock.fill(face)
                Outline(points: Self.lit).fill(Color.white.opacity(0.22))
                Outline(points: Self.shaded).fill(Color.black.opacity(0.22))

                ForEach(0..<Self.speckles.count, id: \.self) { index in
                    let speck = Self.speckles[index]
                    let isDark = speck.isDark || look == .moon
                    Circle()
                        .fill(isDark ? Color.black.opacity(0.26) : Color.white.opacity(0.4))
                        .frame(width: size * speck.size * speckScale, height: size * speck.size * speckScale)
                        .position(x: size * 0.9 * speck.x, y: top * speck.y)
                }

                ForEach(0..<Self.cracks.count, id: \.self) { index in
                    Outline(points: Self.cracks[index], isClosed: false)
                        .stroke(crackColor, style: crack)
                        .shadow(color: colors.glow ? crackColor : Color.clear, radius: size * 0.05)
                }
                // A thin light edge along the lit side.
                Outline(points: [Self.rim[7], Self.rim[0], Self.rim[1], Self.rim[2]], isClosed: false)
                    .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: max(1, size * 0.025), lineCap: .round, lineJoin: .round))
            }
            .frame(width: size * 0.9, height: top)
        }
        .frame(width: size * 0.9, height: size * 0.9, alignment: .top)
        .frame(width: size, height: size)
    }
}
