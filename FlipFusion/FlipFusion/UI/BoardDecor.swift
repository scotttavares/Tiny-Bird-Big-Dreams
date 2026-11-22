import SwiftUI

/// One thing that grows, hangs or sits on a themed board's rim.
enum DecorItem: Equatable, Sendable {
    case leaf(Color, Color)
    case flower(Color)
    case star(Color)
    case heart(Color)
    case gem(Color)
    case bubble(Color)
    case crystal(Color, Color)
    case flame
    case flag(Color)
    case snow
}

/// How a theme dresses the board and the arrow round it: the rim's material, the
/// strand that winds along it (a vine, a rope, a crack of fire), what is strung on
/// it, and the arrow's colours. The plain themes have none.
struct DecorStyle: Equatable, Sendable {
    var rimLight: Color
    var rimDark: Color
    var strand: Color?
    var items: [DecorItem]
    var corner: DecorItem
    var arrowLight: Color
    var arrowDark: Color
    /// The arrow's tail is a vine with leaves on it.
    var isLeafy = false

    nonisolated static func forSkin(_ id: String) -> DecorStyle? {
        switch id {
        case "rainforest":
            let leaf = DecorItem.leaf(Color(hex: 0x7BD957), Color(hex: 0x1F6B2C))
            let young = DecorItem.leaf(Color(hex: 0xB6E86A), Color(hex: 0x3E8E2F))
            return DecorStyle(
                rimLight: Color(hex: 0x9A6A3A), rimDark: Color(hex: 0x4A2C12), strand: Color(hex: 0x4FB04A),
                items: [leaf, young, .flower(Color(hex: 0xF0405A)), leaf, young, .flower(Color(hex: 0xFFB52E))],
                corner: .flower(Color(hex: 0xF0405A)),
                arrowLight: Color(hex: 0x9BE36A), arrowDark: Color(hex: 0x2E7D32), isLeafy: true
            )
        case "jurassic":
            let fern = DecorItem.leaf(Color(hex: 0xA9C95A), Color(hex: 0x3E5A1E))
            let dark = DecorItem.leaf(Color(hex: 0x6FA03C), Color(hex: 0x24401A))
            let tooth = DecorItem.crystal(Color(hex: 0xFFF6DC), Color(hex: 0xC9B98A))
            return DecorStyle(
                rimLight: Color(hex: 0xA8966A), rimDark: Color(hex: 0x4B3F26), strand: Color(hex: 0x6E9433),
                items: [fern, dark, tooth, fern, dark],
                corner: tooth,
                arrowLight: Color(hex: 0xC3DA72), arrowDark: Color(hex: 0x55702A), isLeafy: true
            )
        case "ocean":
            let weed = DecorItem.leaf(Color(hex: 0x4FE0B8), Color(hex: 0x0F7A6B))
            return DecorStyle(
                rimLight: Color(hex: 0x55D6E8), rimDark: Color(hex: 0x0E5C8A), strand: Color(hex: 0x2BB89A),
                items: [weed, .bubble(Color(hex: 0x8FE8FF)), .star(Color(hex: 0xFF8A4C)), weed, .bubble(Color(hex: 0xC9F6FF))],
                corner: .star(Color(hex: 0xFF6F61)),
                arrowLight: Color(hex: 0x8FEFFF), arrowDark: Color(hex: 0x1479B8)
            )
        case "frost":
            let shard = DecorItem.crystal(Color(hex: 0xF2FCFF), Color(hex: 0x7CC4F2))
            return DecorStyle(
                rimLight: Color(hex: 0xE6F8FF), rimDark: Color(hex: 0x6FB6E8), strand: nil,
                items: [shard, .snow, shard, .bubble(Color(hex: 0xE8F8FF)), shard],
                corner: .snow,
                arrowLight: Color(hex: 0xEAFBFF), arrowDark: Color(hex: 0x69B7F0)
            )
        case "lava":
            return DecorStyle(
                rimLight: Color(hex: 0x6A3A2A), rimDark: Color(hex: 0x1E0D08), strand: Color(hex: 0xFF7A1F),
                items: [.flame, .bubble(Color(hex: 0xFFB347)), .flame, .flame, .bubble(Color(hex: 0xFF6A2A))],
                corner: .flame,
                arrowLight: Color(hex: 0xFFC05A), arrowDark: Color(hex: 0xE0401A)
            )
        case "galaxy":
            return DecorStyle(
                rimLight: Color(hex: 0xA98BFF), rimDark: Color(hex: 0x2B1A6B), strand: nil,
                items: [.star(Color(hex: 0xFFF3A8)), .bubble(Color(hex: 0xB69CFF)), .star(Color.white), .bubble(Color(hex: 0x6FD8FF))],
                corner: .star(Color(hex: 0xFFE27A)),
                arrowLight: Color(hex: 0xC08CFF), arrowDark: Color(hex: 0x6C4BFF)
            )
        case "gold":
            return DecorStyle(
                rimLight: Color(hex: 0xFFE98A), rimDark: Color(hex: 0xB8791A), strand: nil,
                items: [.gem(Color(hex: 0x5FE3FF)), .bubble(Color(hex: 0xFFD24A)), .gem(Color(hex: 0xFF6FB5)), .bubble(Color(hex: 0xFFC02E)), .gem(Color(hex: 0x7CF29A))],
                corner: .gem(Color(hex: 0xFF4D6D)),
                arrowLight: Color(hex: 0xFFE98A), arrowDark: Color(hex: 0xC58A1A)
            )
        case "bubblegum":
            return DecorStyle(
                rimLight: Color(hex: 0xFFC2E2), rimDark: Color(hex: 0xE0559F), strand: Color.white,
                items: [.heart(Color(hex: 0xFF5FA8)), .bubble(Color(hex: 0xC9A8FF)), .heart(Color(hex: 0xFF8FC8)), .star(Color(hex: 0xFFE066))],
                corner: .heart(Color(hex: 0xFF3D8B)),
                arrowLight: Color(hex: 0xFFC2E2), arrowDark: Color(hex: 0xE0559F)
            )
        case "party":
            return DecorStyle(
                rimLight: Color(hex: 0xFF7AE0), rimDark: Color(hex: 0x5B2BD6), strand: Color.white,
                items: [.flag(Color(hex: 0xFF4D6D)), .flag(Color(hex: 0xFFD23F)), .flag(Color(hex: 0x3DDC97)), .flag(Color(hex: 0x4DA3FF))],
                corner: .star(Color(hex: 0xFFE066)),
                arrowLight: Color(hex: 0xFF8AE6), arrowDark: Color(hex: 0x7A3BFF)
            )
        case "sunset":
            let palm = DecorItem.leaf(Color(hex: 0x4E9A6B), Color(hex: 0x1C4A38))
            return DecorStyle(
                rimLight: Color(hex: 0xFFC05A), rimDark: Color(hex: 0xD9406B), strand: nil,
                items: [palm, .bubble(Color(hex: 0xFFD86B)), palm, .star(Color(hex: 0xFFE9A8))],
                corner: .bubble(Color(hex: 0xFFB13D)),
                arrowLight: Color(hex: 0xFFC76B), arrowDark: Color(hex: 0xE2526F)
            )
        default:
            return nil
        }
    }
}

/// The shapes a themed rim is made of. Each is drawn standing on the origin and
/// pointing up, `size` tall; the caller moves and turns the canvas first.
enum DecorArt {
    /// A number from 0 to 1 that is always the same for the same input.
    nonisolated static func noise(_ x: Double) -> Double {
        let v = sin(x * 12.9898) * 43758.5453
        return v - floor(v)
    }

    /// A point on a rounded square's edge and the direction pointing away from it.
    /// `t` runs from 0 to 1 clockwise, starting at the left end of the top edge.
    nonisolated static func rim(_ t: Double, rect: CGRect, radius r: CGFloat) -> (point: CGPoint, nx: CGFloat, ny: CGFloat) {
        let width = rect.width
        let straight = width - 2 * r
        let arc = CGFloat(Double.pi) * r / 2
        let piece = straight + arc
        var along = CGFloat(t - floor(t)) * 4 * piece
        let turns = min(3, Int(along / piece))
        along -= CGFloat(turns) * piece

        var x: CGFloat
        var y: CGFloat
        var nx: CGFloat
        var ny: CGFloat
        if along <= straight {
            x = r + along
            y = 0
            nx = 0
            ny = -1
        } else {
            let angle = Double((along - straight) / max(0.001, r))
            x = (width - r) + r * CGFloat(sin(angle))
            y = r - r * CGFloat(cos(angle))
            nx = CGFloat(sin(angle))
            ny = -CGFloat(cos(angle))
        }
        // Turn the top edge round to the side it belongs on.
        var cx = x - width / 2
        var cy = y - width / 2
        for _ in 0..<turns {
            let oldX = cx
            cx = -cy
            cy = oldX
            let oldN = nx
            nx = -ny
            ny = oldN
        }
        return (CGPoint(x: rect.midX + cx, y: rect.midY + cy), nx, ny)
    }

    nonisolated static func disc(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    nonisolated static func leaf(in context: inout GraphicsContext, size s: CGFloat, light: Color, dark: Color) {
        var shape = Path()
        shape.move(to: CGPoint.zero)
        shape.addQuadCurve(to: CGPoint(x: 0, y: -s), control: CGPoint(x: -0.6 * s, y: -0.45 * s))
        shape.addQuadCurve(to: CGPoint.zero, control: CGPoint(x: 0.6 * s, y: -0.45 * s))
        let shade = Gradient(colors: [light, dark])
        context.fill(shape, with: .linearGradient(shade, startPoint: CGPoint(x: -0.3 * s, y: -0.8 * s), endPoint: CGPoint(x: 0.3 * s, y: -0.1 * s)))
        context.stroke(shape, with: .color(dark), lineWidth: max(0.5, s * 0.04))
        var rib = Path()
        rib.move(to: CGPoint(x: 0, y: -0.06 * s))
        rib.addLine(to: CGPoint(x: 0, y: -0.86 * s))
        context.stroke(rib, with: .color(Color.white.opacity(0.45)), style: StrokeStyle(lineWidth: max(0.5, s * 0.045), lineCap: .round))
    }

    nonisolated static func draw(_ item: DecorItem, in context: inout GraphicsContext, size s: CGFloat) {
        switch item {
        case .leaf(let light, let dark):
            leaf(in: &context, size: s, light: light, dark: dark)

        case .flower(let color):
            let middle = -0.45 * s
            for petal in 0..<5 {
                let angle = Double(petal) * 2 * Double.pi / 5 - Double.pi / 2
                let px = 0.27 * s * CGFloat(cos(angle))
                let py = middle + 0.27 * s * CGFloat(sin(angle))
                let shade = Gradient(colors: [Color.white, color])
                context.fill(disc(px, py, 0.21 * s), with: .radialGradient(shade, center: CGPoint(x: px, y: py - 0.08 * s), startRadius: 0, endRadius: 0.3 * s))
            }
            context.fill(disc(0, middle, 0.13 * s), with: .color(Color(hex: 0xFFD83D)))
            context.stroke(disc(0, middle, 0.13 * s), with: .color(Color(hex: 0xC98A12)), lineWidth: max(0.5, s * 0.03))

        case .star(let color):
            let middle = -0.5 * s
            var shape = Path()
            for corner in 0..<10 {
                let angle = Double(corner) * Double.pi / 5 - Double.pi / 2
                let reach = (corner % 2 == 0 ? 0.48 : 0.2) * s
                let spot = CGPoint(x: reach * CGFloat(cos(angle)), y: middle + reach * CGFloat(sin(angle)))
                if corner == 0 {
                    shape.move(to: spot)
                } else {
                    shape.addLine(to: spot)
                }
            }
            shape.closeSubpath()
            let shade = Gradient(colors: [Color.white, color])
            context.fill(shape, with: .radialGradient(shade, center: CGPoint(x: -0.1 * s, y: middle - 0.12 * s), startRadius: 0, endRadius: 0.5 * s))
            context.stroke(shape, with: .color(Color.white.opacity(0.7)), lineWidth: max(0.5, s * 0.03))

        case .heart(let color):
            var shape = Path()
            shape.move(to: CGPoint(x: 0, y: -0.08 * s))
            shape.addCurve(to: CGPoint(x: 0, y: -0.68 * s), control1: CGPoint(x: -0.75 * s, y: -0.5 * s), control2: CGPoint(x: -0.36 * s, y: -1.1 * s))
            shape.addCurve(to: CGPoint(x: 0, y: -0.08 * s), control1: CGPoint(x: 0.36 * s, y: -1.1 * s), control2: CGPoint(x: 0.75 * s, y: -0.5 * s))
            let shade = Gradient(colors: [Color.white, color, color])
            context.fill(shape, with: .radialGradient(shade, center: CGPoint(x: -0.16 * s, y: -0.72 * s), startRadius: 0, endRadius: 0.6 * s))
            context.stroke(shape, with: .color(Color.white.opacity(0.6)), lineWidth: max(0.5, s * 0.03))

        case .gem(let color):
            var shape = Path()
            shape.move(to: CGPoint(x: 0, y: -0.95 * s))
            shape.addLine(to: CGPoint(x: 0.38 * s, y: -0.58 * s))
            shape.addLine(to: CGPoint(x: 0, y: -0.05 * s))
            shape.addLine(to: CGPoint(x: -0.38 * s, y: -0.58 * s))
            shape.closeSubpath()
            context.fill(shape, with: .color(color))
            var facet = Path()
            facet.move(to: CGPoint(x: 0, y: -0.95 * s))
            facet.addLine(to: CGPoint(x: 0.38 * s, y: -0.58 * s))
            facet.addLine(to: CGPoint(x: 0, y: -0.48 * s))
            facet.addLine(to: CGPoint(x: -0.38 * s, y: -0.58 * s))
            facet.closeSubpath()
            context.fill(facet, with: .color(Color.white.opacity(0.5)))
            var shadowSide = Path()
            shadowSide.move(to: CGPoint(x: 0, y: -0.48 * s))
            shadowSide.addLine(to: CGPoint(x: 0.38 * s, y: -0.58 * s))
            shadowSide.addLine(to: CGPoint(x: 0, y: -0.05 * s))
            shadowSide.closeSubpath()
            context.fill(shadowSide, with: .color(Color.black.opacity(0.22)))
            context.stroke(shape, with: .color(Color.white.opacity(0.75)), lineWidth: max(0.5, s * 0.035))

        case .bubble(let color):
            let middle = -0.4 * s
            let shade = Gradient(colors: [Color.white, color, color.opacity(0.8)])
            context.fill(disc(0, middle, 0.3 * s), with: .radialGradient(shade, center: CGPoint(x: -0.1 * s, y: middle - 0.12 * s), startRadius: 0, endRadius: 0.36 * s))
            context.stroke(disc(0, middle, 0.3 * s), with: .color(Color.white.opacity(0.6)), lineWidth: max(0.5, s * 0.03))

        case .crystal(let light, let dark):
            var shape = Path()
            shape.move(to: CGPoint(x: 0, y: -1.15 * s))
            shape.addLine(to: CGPoint(x: 0.19 * s, y: -0.3 * s))
            shape.addLine(to: CGPoint.zero)
            shape.addLine(to: CGPoint(x: -0.19 * s, y: -0.3 * s))
            shape.closeSubpath()
            let shade = Gradient(colors: [light, dark])
            context.fill(shape, with: .linearGradient(shade, startPoint: CGPoint(x: 0, y: -1.15 * s), endPoint: CGPoint.zero))
            var bright = Path()
            bright.move(to: CGPoint(x: 0, y: -1.15 * s))
            bright.addLine(to: CGPoint.zero)
            bright.addLine(to: CGPoint(x: -0.19 * s, y: -0.3 * s))
            bright.closeSubpath()
            context.fill(bright, with: .color(Color.white.opacity(0.4)))
            context.stroke(shape, with: .color(Color.white.opacity(0.7)), lineWidth: max(0.5, s * 0.03))

        case .flame:
            var shape = Path()
            shape.move(to: CGPoint(x: 0, y: 0.05 * s))
            shape.addQuadCurve(to: CGPoint(x: 0, y: -1.05 * s), control: CGPoint(x: -0.7 * s, y: -0.3 * s))
            shape.addQuadCurve(to: CGPoint(x: 0, y: 0.05 * s), control: CGPoint(x: 0.7 * s, y: -0.3 * s))
            let fire = Gradient(colors: [Color(hex: 0xFFE46B), Color(hex: 0xFF7A1A), Color(hex: 0xD92B12)])
            context.fill(shape, with: .linearGradient(fire, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: -1.05 * s)))
            var heart = Path()
            heart.move(to: CGPoint(x: 0, y: 0))
            heart.addQuadCurve(to: CGPoint(x: 0, y: -0.6 * s), control: CGPoint(x: -0.36 * s, y: -0.2 * s))
            heart.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 0.36 * s, y: -0.2 * s))
            context.fill(heart, with: .color(Color(hex: 0xFFF6C2, opacity: 0.9)))

        case .flag(let color):
            var shape = Path()
            shape.move(to: CGPoint(x: -0.3 * s, y: 0))
            shape.addLine(to: CGPoint(x: 0.3 * s, y: 0))
            shape.addLine(to: CGPoint(x: 0, y: -0.85 * s))
            shape.closeSubpath()
            context.fill(shape, with: .color(color))
            var bright = Path()
            bright.move(to: CGPoint(x: -0.3 * s, y: 0))
            bright.addLine(to: CGPoint(x: 0, y: 0))
            bright.addLine(to: CGPoint(x: 0, y: -0.85 * s))
            bright.closeSubpath()
            context.fill(bright, with: .color(Color.white.opacity(0.3)))

        case .snow:
            let middle = -0.5 * s
            for spoke in 0..<3 {
                let angle = Double(spoke) * Double.pi / 3
                let dx = 0.44 * s * CGFloat(cos(angle))
                let dy = 0.44 * s * CGFloat(sin(angle))
                var line = Path()
                line.move(to: CGPoint(x: -dx, y: middle - dy))
                line.addLine(to: CGPoint(x: dx, y: middle + dy))
                context.stroke(line, with: .color(Color.white), style: StrokeStyle(lineWidth: max(1, s * 0.1), lineCap: .round))
            }
            context.fill(disc(0, middle, 0.12 * s), with: .color(Color(hex: 0xBFE9FF)))
        }
    }
}

/// A themed board's rim and what grows on it. Drawn in a square a fifth wider than
/// the board, so the leaves and flames can hang over the edge.
struct BoardDecor: View {
    /// How far the drawing reaches past each edge, as a share of the board's side.
    static let margin: CGFloat = 0.1

    let side: CGFloat
    let style: DecorStyle

    var body: some View {
        let look = style
        Canvas { context, size in
            BoardDecor.draw(in: &context, size: size, style: look)
        }
        .frame(width: side * 1.2, height: side * 1.2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    nonisolated private static func place(
        _ item: DecorItem,
        at t: Double,
        lean: Double,
        size: CGFloat,
        rect: CGRect,
        radius: CGFloat,
        in context: inout GraphicsContext
    ) {
        let spot = DecorArt.rim(t, rect: rect, radius: radius)
        let out = rect.width * 0.01
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.5), radius: size * 0.1, x: 0, y: size * 0.06))
            layer.translateBy(x: spot.point.x + spot.nx * out, y: spot.point.y + spot.ny * out)
            layer.rotate(by: .radians(atan2(Double(spot.ny), Double(spot.nx)) + Double.pi / 2 + lean))
            DecorArt.draw(item, in: &layer, size: size)
        }
    }

    nonisolated private static func draw(in context: inout GraphicsContext, size: CGSize, style: DecorStyle) {
        let board = size.width / 1.2
        let pad = (size.width - board) / 2
        let rect = CGRect(x: pad, y: pad, width: board, height: board)
        let radius = board * 0.07
        let outline = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)

        // The rim: a dark edge, the material over it, and a thin line of light.
        context.stroke(outline, with: .color(style.rimDark), lineWidth: board * 0.036)
        let material = Gradient(colors: [style.rimLight, style.rimDark, style.rimLight])
        context.stroke(
            outline,
            with: .linearGradient(material, startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)),
            lineWidth: board * 0.022
        )
        context.stroke(outline, with: .color(Color.white.opacity(0.35)), lineWidth: max(1, board * 0.004))

        // The strand: two lines winding over and under each other along the rim.
        if let strand = style.strand {
            for pass in 0..<2 {
                var path = Path()
                let samples = 280
                for index in 0...samples {
                    let t = Double(index) / Double(samples)
                    let spot = DecorArt.rim(t, rect: rect, radius: radius)
                    let wave = board * 0.014 * CGFloat(sin(t * 2 * Double.pi * 14 + Double(pass) * Double.pi))
                    let here = CGPoint(x: spot.point.x + spot.nx * wave, y: spot.point.y + spot.ny * wave)
                    if index == 0 {
                        path.move(to: here)
                    } else {
                        path.addLine(to: here)
                    }
                }
                context.stroke(path, with: .color(Color.black.opacity(0.5)), style: StrokeStyle(lineWidth: board * 0.017, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(strand), style: StrokeStyle(lineWidth: board * 0.009, lineCap: .round, lineJoin: .round))
            }
        }

        // What is strung along it: the same every time for the same theme.
        guard !style.items.isEmpty else { return }
        let count = 26
        for index in 0..<count {
            let t = (Double(index) + 0.15 + 0.5 * DecorArt.noise(Double(index) * 7.13 + 1.7)) / Double(count)
            let lean = (DecorArt.noise(Double(index) * 11.3 + 0.4) - 0.5) * 1.2
            let itemSize = board * CGFloat(0.05 + 0.03 * DecorArt.noise(Double(index) * 3.7 + 2.2))
            place(style.items[index % style.items.count], at: t, lean: lean, size: itemSize, rect: rect, radius: radius, in: &context)
        }

        // A bigger cluster on every corner.
        let straight = Double(board - 2 * radius)
        let arc = Double.pi * Double(radius) / 2
        let piece = straight + arc
        for corner in 0..<4 {
            let t = (Double(corner) * piece + straight + arc / 2) / (4 * piece)
            place(style.items[0], at: t, lean: -0.75, size: board * 0.085, rect: rect, radius: radius, in: &context)
            place(style.items[0], at: t, lean: 0.75, size: board * 0.085, rect: rect, radius: radius, in: &context)
            place(style.corner, at: t, lean: 0, size: board * 0.105, rect: rect, radius: radius, in: &context)
        }
    }
}
