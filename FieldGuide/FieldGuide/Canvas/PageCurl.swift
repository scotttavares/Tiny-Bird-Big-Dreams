import SwiftUI

/// The geometry of a page being turned by its corner. Pure, unit-tested.
///
/// The sheet spans `0…width × 0…height` with its bound edge (the spine) at `x = 0`. Pulling the
/// corner `C` to the point `F` folds the sheet along the perpendicular bisector of `C`–`F`: the part
/// past the fold lifts off (revealing the page beneath) and lands mirrored on top as the flap,
/// which shows the back of the sheet.
struct PageCurlGeometry: Equatable, Sendable {
    let size: CGSize
    let corner: CGPoint
    let fold: CGPoint

    /// The part of the sheet still lying flat.
    var flat: [CGPoint] { Self.clip(sheet) { -side($0) } }
    /// The part that has lifted off, in its original position (what it no longer covers).
    var lifted: [CGPoint] { Self.clip(sheet) { side($0) } }
    /// The lifted part after folding over: where the back of the sheet now lies.
    var flap: [CGPoint] { lifted.map(reflect) }

    /// Unit normal of the fold line, pointing toward the corner being pulled.
    var normal: CGVector {
        let dx = corner.x - fold.x, dy = corner.y - fold.y, length = max(hypot(dx, dy), 0.0001)
        return CGVector(dx: dx / length, dy: dy / length)
    }

    /// The fold line's midpoint.
    var crease: CGPoint { CGPoint(x: (corner.x + fold.x) / 2, y: (corner.y + fold.y) / 2) }

    /// How far the corner has travelled, 0 (flat) to 1 (a full sheet width).
    var lift: CGFloat { min(1, hypot(corner.x - fold.x, corner.y - fold.y) / max(size.width, 1)) }

    /// Reflection across the fold line, as an affine transform (draws the sheet's back in place).
    var reflection: CGAffineTransform {
        let n = normal, k = 2 * (crease.x * n.dx + crease.y * n.dy)
        return CGAffineTransform(a: 1 - 2 * n.dx * n.dx, b: -2 * n.dx * n.dy, c: -2 * n.dx * n.dy, d: 1 - 2 * n.dy * n.dy,
                                 tx: k * n.dx, ty: k * n.dy)
    }

    func reflect(_ point: CGPoint) -> CGPoint { point.applying(reflection) }

    /// Signed distance from the fold line; positive on the corner's side.
    func side(_ point: CGPoint) -> CGFloat {
        (point.x - crease.x) * normal.dx + (point.y - crease.y) * normal.dy
    }

    private var sheet: [CGPoint] {
        [.zero, CGPoint(x: size.width, y: 0), CGPoint(x: size.width, y: size.height), CGPoint(x: 0, y: size.height)]
    }

    /// Keeps the part of a polygon where `f(point) >= 0` (one Sutherland–Hodgman pass).
    static func clip(_ polygon: [CGPoint], keeping f: (CGPoint) -> CGFloat) -> [CGPoint] {
        guard polygon.count >= 3 else { return [] }
        var out: [CGPoint] = []
        for i in polygon.indices {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count], fa = f(a), fb = f(b)
            if fa >= 0 { out.append(a) }
            if (fa >= 0) != (fb >= 0) {
                let t = fa / (fa - fb)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return out
    }

    /// Keeps the corner where the paper allows: the sheet is bound at the spine, so a corner can't
    /// travel further from it than the sheet's width (or its diagonal, from the other spine end).
    static func constrain(_ point: CGPoint, cornerY: CGFloat, size: CGSize) -> CGPoint {
        var p = point
        let near = CGPoint(x: 0, y: cornerY), far = CGPoint(x: 0, y: size.height - cornerY)
        for (anchor, radius) in [(near, size.width), (far, hypot(size.width, size.height)), (near, size.width)] {
            let dx = p.x - anchor.x, dy = p.y - anchor.y, d = hypot(dx, dy)
            if d > radius { p = CGPoint(x: anchor.x + dx * radius / d, y: anchor.y + dy * radius / d) }
        }
        return p
    }

    /// Area of a polygon (for tests and sanity checks).
    static func area(_ polygon: [CGPoint]) -> CGFloat {
        guard polygon.count >= 3 else { return 0 }
        var sum: CGFloat = 0
        for i in polygon.indices {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }
}

/// Draws a turning page: the page underneath in the lifted sheet's shadow, the part still flat,
/// and the curled-over flap showing the back of the sheet, with a crease, a soft highlight
/// where the paper rolls, and the flap's shadow.
///
/// `foldX`/`foldY` are animatable, so a released page glides on to its resting place.
struct PageCurlView: View, Animatable {
    let front: Image
    let under: Image
    let back: Image
    let paper: Color
    let cornerY: CGFloat
    var foldX: CGFloat
    var foldY: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(foldX, foldY) }
        set { foldX = newValue.first; foldY = newValue.second }
    }

    var body: some View {
        Canvas { context, size in
            let corner = CGPoint(x: size.width, y: cornerY * size.height)
            let fold = CGPoint(x: foldX * size.width, y: foldY * size.height)
            let curl = PageCurlGeometry(size: size, corner: corner, fold: fold)
            let rect = CGRect(origin: .zero, size: size)
            let n = curl.normal, m = curl.crease
            let polygon = { (points: [CGPoint]) -> Path in
                var path = Path()
                if let first = points.first {
                    path.move(to: first)
                    path.addLines(Array(points.dropFirst()))
                    path.closeSubpath()
                }
                return path
            }

            guard curl.lift > 0.002 else {
                context.draw(front, in: rect)
                return
            }
            let lifted = polygon(curl.lifted), flat = polygon(curl.flat), flap = polygon(curl.flap)
            var extent: CGFloat = 1
            for point in curl.lifted { extent = max(extent, curl.side(point)) }

            // The page underneath, darkened where the lifted sheet shades it.
            context.drawLayer { layer in
                layer.clip(to: lifted)
                layer.draw(under, in: rect)
                let reach = min(extent, 18 + hypot(fold.x - corner.x, fold.y - corner.y) * 0.35)
                layer.fill(lifted, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .black.opacity(0.42 + 0.1 * curl.lift), location: 0),
                        .init(color: .black.opacity(0.16), location: 0.35),
                        .init(color: .clear, location: 1),
                    ]),
                    startPoint: m, endPoint: CGPoint(x: m.x + n.dx * reach, y: m.y + n.dy * reach)))
            }
            // The part still lying flat, a touch darker where it starts to rise into the fold.
            context.drawLayer { layer in
                layer.clip(to: flat)
                layer.draw(front, in: rect)
                layer.fill(flat, with: .linearGradient(Gradient(colors: [.black.opacity(0.12), .clear]),
                                                       startPoint: m, endPoint: CGPoint(x: m.x - n.dx * 26, y: m.y - n.dy * 26)))
            }
            // The flap's shadow on the flat page, then the back of the sheet.
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.22 + 0.18 * curl.lift), radius: 6 + 14 * curl.lift, x: -3 * curl.lift, y: 2 * curl.lift))
                layer.fill(flap, with: .color(paper))
            }
            context.drawLayer { layer in
                layer.clip(to: flap)
                layer.concatenate(curl.reflection)
                layer.draw(back, in: rect)
            }
            // Curvature: a dark crease, a highlight where the paper rolls, shade toward the corner.
            context.fill(flap, with: .linearGradient(
                Gradient(stops: [
                    .init(color: .black.opacity(0.3), location: 0),
                    .init(color: .black.opacity(0.1), location: 0.06),
                    .init(color: .white.opacity(0.28), location: 0.22),
                    .init(color: .white.opacity(0.06), location: 0.5),
                    .init(color: .black.opacity(0.12), location: 1),
                ]),
                startPoint: m, endPoint: CGPoint(x: m.x - n.dx * extent, y: m.y - n.dy * extent)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
