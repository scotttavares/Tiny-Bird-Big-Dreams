import SwiftUI

/// A notebook's cover, drawn in code: the design for its theme, its title, and the wear of a
/// book that has been carried around (rubbed edges, staples, scuffs, a crease).
/// The wear is seeded by the notebook, so it never moves.
///
/// Artwork is laid out on a 240 × 420 board and scaled to fill whatever shape it's shown in,
/// so the same cover works on the outer screen and as a small thumbnail.
struct NotebookCoverArt: View {
    let title: String
    let theme: NotebookTheme
    /// Stable seed for the wear (the notebook's id).
    let seed: String
    /// "№ 2" on the designs that carry a number.
    var number: Int = 1

    static let designSize = CGSize(width: 240, height: 420)

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let design = Self.designSize
            let scale = max(size.width / design.width, size.height / design.height)
            context.translateBy(x: (size.width - design.width * scale) / 2, y: (size.height - design.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            var art = CoverPainter(context: context, theme: theme, title: title, number: number, random: SeededRandom(string: seed))
            art.paint()
        }
        .accessibilityElement()
        .accessibilityLabel("\(title) cover, \(theme.name) design")
    }
}

/// Draws one cover into a `GraphicsContext` in design coordinates.
private struct CoverPainter {
    let context: GraphicsContext
    let theme: NotebookTheme
    let title: String
    let number: Int
    var random: SeededRandom

    private let width: CGFloat = 240
    private let height: CGFloat = 420
    private var board: CGRect { CGRect(x: 0, y: 0, width: width, height: height) }

    mutating func paint() {
        context.fill(Path(board), with: .color(theme.board))
        switch theme {
        case .journal: paintJournal()
        case .pines: paintPines()
        case .kraft: paintKraft()
        case .olive: paintOlive()
        case .weather: paintWeather()
        case .supply: paintSupply()
        case .trail: paintTrail()
        }
        paintWear()
    }

    // MARK: Designs

    private mutating func paintJournal() {
        // A cloth spine wrapped round the boards, and the elastic closure band.
        context.fill(Path(CGRect(x: 0, y: 0, width: 30, height: height)), with: .color(theme.line))
        var seam = Path(); seam.move(to: CGPoint(x: 30, y: 0)); seam.addLine(to: CGPoint(x: 30, y: height))
        context.stroke(seam, with: .color(.black.opacity(0.18)), lineWidth: 1)
        context.fill(Path(CGRect(x: 204, y: 0, width: 11, height: height)), with: .color(theme.accent))
        var sheen = Path(); sheen.move(to: CGPoint(x: 206.5, y: 0)); sheen.addLine(to: CGPoint(x: 206.5, y: height))
        context.stroke(sheen, with: .color(.white.opacity(0.12)), lineWidth: 1)

        let titleBottom = drawTitle(centerY: 92, maxWidth: 150, maxSize: 32, color: theme.coverInk)
        drawSubtitle(theme.subtitle.uppercased(), centerY: titleBottom + 20, size: 9, maxWidth: 150, color: theme.coverInk.opacity(0.85))

        // The leaf emblem, pressed into the board.
        var leaf = Path()
        leaf.move(to: CGPoint(x: 120, y: 296))
        leaf.addQuadCurve(to: CGPoint(x: 120, y: 200), control: CGPoint(x: 90, y: 248))
        leaf.addQuadCurve(to: CGPoint(x: 120, y: 296), control: CGPoint(x: 150, y: 248))
        context.fill(leaf, with: .color(theme.coverInk))
        var veins = Path()
        veins.move(to: CGPoint(x: 120, y: 214)); veins.addLine(to: CGPoint(x: 120, y: 290))
        for (i, y) in [228.0, 246, 264].enumerated() {
            let dx = 11 - CGFloat(i) * 1.5
            veins.move(to: CGPoint(x: 120, y: y + 8)); veins.addLine(to: CGPoint(x: 120 - dx, y: y))
            veins.move(to: CGPoint(x: 120, y: y + 8)); veins.addLine(to: CGPoint(x: 120 + dx, y: y))
        }
        context.stroke(veins, with: .color(theme.board), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        context.fill(Path(CGRect(x: 118.5, y: 294, width: 3, height: 16)), with: .color(theme.coverInk))

        drawText("№ \(number)", at: CGPoint(x: 117, y: 384), font: theme.titleFont(size: 12), color: theme.coverInk.opacity(0.85))
    }

    private mutating func paintPines() {
        // Topographic contours around a few hills.
        let lineShading = GraphicsContext.Shading.color(theme.line.opacity(0.75))
        for _ in 0..<3 {
            let center = CGPoint(x: random.range(20, 220), y: random.range(40, 380))
            let phase = random.range(0, 6.28)
            for ring in 1...7 {
                let radius = CGFloat(ring) * random.range(12, 16)
                context.stroke(blob(center: center, radius: radius, phase: phase), with: lineShading, lineWidth: 0.9)
            }
        }
        // Fold lines from being opened out like a map.
        var fold = Path()
        fold.move(to: CGPoint(x: 120, y: 0)); fold.addLine(to: CGPoint(x: 120, y: height))
        fold.move(to: CGPoint(x: 0, y: height / 2)); fold.addLine(to: CGPoint(x: width, y: height / 2))
        context.stroke(fold, with: .color(.white.opacity(0.14)), style: StrokeStyle(lineWidth: 1.2, dash: [7, 3, 2, 4]))

        drawText("№ \(number)", at: CGPoint(x: 120, y: 66), font: .system(size: 13, weight: .bold, design: .rounded), color: Color(hex: 0xF3EAD8))
        drawTitle(centerY: 128, maxWidth: 200, maxSize: 52, color: theme.coverInk)
        for (dx, dy) in [(-16.0, 0.0), (0, -4), (16, 0)] {
            context.fill(pine(x: 120 + dx, y: 300 + dy, scale: 0.95), with: .color(theme.coverInk))
        }
        drawSubtitle(theme.subtitle.uppercased(), centerY: 370, size: 9.5, maxWidth: 190, color: theme.coverInk)
    }

    private mutating func paintKraft() {
        context.stroke(Path(board.insetBy(dx: 5, dy: 5)), with: .color(theme.line.opacity(0.35)), lineWidth: 10)
        let titleBottom = drawTitle(centerY: 120, maxWidth: 190, maxSize: 44, color: theme.coverInk)
        drawSubtitle(theme.subtitle.uppercased(), centerY: titleBottom + 24, size: 9.5, maxWidth: 180, color: theme.coverInk)
    }

    private mutating func paintOlive() {
        context.stroke(Path(roundedRect: board.insetBy(dx: 6, dy: 6), cornerRadius: 10), with: .color(.white.opacity(0.35)), lineWidth: 3)
        let titleBottom = drawTitle(centerY: 132, maxWidth: 190, maxSize: 44, color: theme.coverInk)
        drawSubtitle("FIELD SKETCH BOOK · ISSUE NO. \(number)", centerY: titleBottom + 24, size: 9, maxWidth: 190, color: theme.coverInk.opacity(0.9))
        drawSubtitle("Durable materials · Made by hand", centerY: titleBottom + 40, size: 9, maxWidth: 190, color: theme.coverInk.opacity(0.9))
    }

    private mutating func paintWeather() {
        paintRings()
        drawText("ALL WEATHER", at: CGPoint(x: 120, y: 104), font: theme.titleFont(size: 22), color: theme.coverInk)
        drawTitle(centerY: 170, maxWidth: 180, maxSize: 36, color: theme.coverInk)
        for (label, y) in [("NAME:", 352.0), ("ID NO:", 378.0)] {
            drawText(label, at: CGPoint(x: 52, y: y), font: .system(size: 10, design: .monospaced), color: theme.coverInk)
            var rule = Path(); rule.move(to: CGPoint(x: 78, y: y + 4)); rule.addLine(to: CGPoint(x: 208, y: y + 4))
            context.stroke(rule, with: .color(theme.coverInk), style: StrokeStyle(lineWidth: 1, dash: [1.5, 2.5]))
        }
    }

    private mutating func paintSupply() {
        paintRings()
        // A checkerboard border, then a thin inner rule.
        let ink = GraphicsContext.Shading.color(theme.coverInk)
        let outer = CGRect(x: 18, y: 44, width: 204, height: 350), cell: CGFloat = 4
        var checks = Path()
        var x = outer.minX
        while x < outer.maxX {
            for (row, y) in [outer.minY, outer.maxY - 2 * cell].enumerated() {
                let alt = (Int((x - outer.minX) / cell) + row) % 2 == 0
                checks.addRect(CGRect(x: x, y: y + (alt ? 0 : cell), width: cell, height: cell))
            }
            x += cell
        }
        var y = outer.minY
        while y < outer.maxY {
            for (column, x) in [outer.minX, outer.maxX - 2 * cell].enumerated() {
                let alt = (Int((y - outer.minY) / cell) + column) % 2 == 0
                checks.addRect(CGRect(x: x + (alt ? 0 : cell), y: y, width: cell, height: cell))
            }
            y += cell
        }
        context.fill(checks, with: ink)
        context.stroke(Path(outer.insetBy(dx: 12, dy: 12)), with: ink, lineWidth: 1.2)

        let condensed = { (size: CGFloat) in Font.system(size: size, weight: .bold).width(.condensed) }
        drawText("DON’T TRUST YOUR", at: CGPoint(x: 120, y: 92), font: condensed(19), color: theme.coverInk)
        drawText("M E M O R Y", at: CGPoint(x: 120, y: 118), font: condensed(15), color: theme.coverInk)
        drawText("USE THIS BOOK", at: CGPoint(x: 120, y: 144), font: condensed(19), color: theme.coverInk)
        var mark = Path(); mark.move(to: CGPoint(x: 80, y: 168)); mark.addLine(to: CGPoint(x: 160, y: 168))
        context.stroke(mark, with: ink, lineWidth: 1.6)
        drawTitle(centerY: 214, maxWidth: 170, maxSize: 30, color: theme.coverInk)
        drawText("TINY BIRD SUPPLY CO.", at: CGPoint(x: 120, y: 336), font: condensed(11), color: theme.coverInk)
        drawText("FIELD BOOKS FOR EVERY TRAIL", at: CGPoint(x: 120, y: 350), font: condensed(9), color: theme.coverInk)
    }

    private mutating func paintTrail() {
        drawText("NO. \(number)", at: CGPoint(x: 120, y: 58), font: .system(size: 10, weight: .semibold).width(.expanded), color: theme.coverInk.opacity(0.8))
        // A pinecone built from overlapping scales.
        var cone = Path()
        cone.addRect(CGRect(x: 117, y: 138, width: 6, height: 10))
        for row in 0..<8 {
            let y = 150 + CGFloat(row) * 13
            let half = 10 + sin(CGFloat(row) / 7 * .pi) * 24
            let count = 2 + Int((half / 9).rounded())
            for j in 0..<count {
                let x = 120 - half + (CGFloat(j) + 0.5) * (half * 2 / CGFloat(count))
                cone.move(to: CGPoint(x: x - 7, y: y))
                cone.addQuadCurve(to: CGPoint(x: x + 7, y: y), control: CGPoint(x: x, y: y + 11))
                cone.addQuadCurve(to: CGPoint(x: x - 7, y: y), control: CGPoint(x: x, y: y + 4))
            }
        }
        context.fill(cone, with: .color(theme.coverInk))
        let titleBottom = drawTitle(centerY: 300, maxWidth: 190, maxSize: 38, color: Color(hex: 0xE3DDB4))
        drawSubtitle(theme.subtitle.uppercased(), centerY: titleBottom + 16, size: 9, maxWidth: 190, color: theme.coverInk)
        for dx in [-60.0, -45, 45, 60] {
            context.fill(pine(x: 120 + dx, y: 392, scale: 0.55), with: .color(Color(hex: 0x8A8252)))
        }
    }

    private func paintRings() {
        for i in 0..<15 {
            let x = 14 + CGFloat(i) * 14.5
            context.fill(Path(roundedRect: CGRect(x: x, y: 2, width: 5, height: 22), cornerRadius: 2.5), with: .color(Color(hex: 0x2A2A2A)))
            context.fill(Path(ellipseIn: CGRect(x: x - 0.1, y: 25.4, width: 5.2, height: 5.2)), with: .color(.black.opacity(0.75)))
        }
    }

    // MARK: Wear

    private mutating func paintWear() {
        let light = Color(hex: 0xFFFAF0)
        // Board grain.
        var darkGrain = Path(), lightGrain = Path()
        for i in 0..<900 {
            let dot = CGRect(x: random.range(0, Double(width)), y: random.range(0, Double(height)), width: 0.9, height: 0.9)
            if i % 2 == 0 { darkGrain.addEllipse(in: dot) } else { lightGrain.addEllipse(in: dot) }
        }
        context.fill(darkGrain, with: .color(.black.opacity(0.12)))
        context.fill(lightGrain, with: .color(.white.opacity(0.08)))

        if theme.hasStapledSpine {
            // A scored spine with three staples through the fold.
            var score = Path(); score.move(to: CGPoint(x: 11.5, y: 0)); score.addLine(to: CGPoint(x: 11.5, y: height))
            context.stroke(score, with: .color(.black.opacity(0.28)), lineWidth: 1.4)
            context.fill(Path(CGRect(x: 0, y: 0, width: 11, height: height)), with: .color(.black.opacity(0.08)))
            for y in [height * 0.2, height * 0.5, height * 0.8] {
                let staple = Path(roundedRect: CGRect(x: 3.5, y: y + random.range(-3, 3), width: 3, height: 26), cornerRadius: 1)
                context.fill(staple, with: .linearGradient(Gradient(colors: [Color(hex: 0x6B6F73), Color(hex: 0xE4E7EA), Color(hex: 0x7D8185)]),
                                                          startPoint: CGPoint(x: 3.5, y: y), endPoint: CGPoint(x: 6.5, y: y)))
            }
        }
        // Rubbed edges and corners.
        context.stroke(Path(roundedRect: board.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 6), with: .color(light.opacity(0.18)), lineWidth: 3)
        for corner in [CGPoint(x: 0, y: 0), CGPoint(x: width, y: 0), CGPoint(x: 0, y: height), CGPoint(x: width, y: height)] {
            let r = random.range(10, 20)
            context.fill(Path(ellipseIn: CGRect(x: corner.x - r, y: corner.y - r, width: 2 * r, height: 2 * r)), with: .color(light.opacity(0.16)))
        }
        // Scuffs.
        var scuffs = Path()
        for _ in 0..<Int(random.range(8, 18)) {
            let start = CGPoint(x: random.range(10, 230), y: random.range(10, 410))
            let angle = random.range(-0.6, 0.6) + (random.unit() < 0.5 ? 0 : .pi / 2), length = random.range(4, 20)
            scuffs.move(to: start)
            scuffs.addLine(to: CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length))
        }
        context.stroke(scuffs, with: .color(light.opacity(0.22)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        // A crease.
        let creaseStart = CGPoint(x: width, y: random.range(60, 360))
        var crease = Path(); crease.move(to: creaseStart)
        crease.addQuadCurve(to: CGPoint(x: creaseStart.x - random.range(60, 140), y: creaseStart.y + random.range(-40, 40)),
                            control: CGPoint(x: creaseStart.x - 50, y: creaseStart.y + random.range(-12, 12)))
        context.stroke(crease, with: .color(.black.opacity(0.2)), lineWidth: 1.1)
        context.stroke(crease.offsetBy(dx: 0.9, dy: 0.9), with: .color(light.opacity(0.3)), lineWidth: 0.8)
        // Light falling across the board, darker at the edges.
        context.fill(Path(board), with: .linearGradient(Gradient(stops: [
            .init(color: .white.opacity(0.14), location: 0), .init(color: .clear, location: 0.45), .init(color: .black.opacity(0.16), location: 1),
        ]), startPoint: .zero, endPoint: CGPoint(x: width, y: height)))
        context.fill(Path(board), with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.3)]),
                                                         center: CGPoint(x: width / 2, y: height * 0.45), startRadius: 120, endRadius: 300))
    }

    // MARK: Pieces

    /// Draws the notebook title, wrapped to at most three lines and sized to fit. Returns its bottom.
    @discardableResult
    private func drawTitle(centerY: CGFloat, maxWidth: CGFloat, maxSize: CGFloat, color: Color) -> CGFloat {
        let lines = Self.wrap(title.uppercased(), maxCharacters: 11)
        let probe = lines.map { context.resolve(Text($0).font(theme.titleFont(size: 100))).measure(in: CGSize(width: 10_000, height: 1_000)).width }
        let size = min(maxSize, maxWidth / max(probe.max() ?? 1, 1) * 100)
        let lineHeight = size * 1.02
        let top = centerY - lineHeight * CGFloat(lines.count - 1) / 2
        for (index, line) in lines.enumerated() {
            drawText(line, at: CGPoint(x: 120, y: top + CGFloat(index) * lineHeight), font: theme.titleFont(size: size), color: color)
        }
        return top + CGFloat(lines.count - 1) * lineHeight + size / 2
    }

    private func drawSubtitle(_ text: String, centerY: CGFloat, size: CGFloat, maxWidth: CGFloat, color: Color) {
        let lines = Self.wrap(text, maxCharacters: 34).prefix(2)
        for (index, line) in lines.enumerated() {
            let resolved = context.resolve(Text(line).font(.system(size: size, weight: .bold).width(.condensed)).foregroundStyle(color))
            let fitted = resolved.measure(in: CGSize(width: 10_000, height: 100)).width
            var ctx = context
            if fitted > maxWidth {
                ctx.translateBy(x: 120, y: centerY + CGFloat(index) * size * 1.15)
                ctx.scaleBy(x: maxWidth / fitted, y: 1)
                ctx.draw(resolved, at: .zero, anchor: .center)
            } else {
                ctx.draw(resolved, at: CGPoint(x: 120, y: centerY + CGFloat(index) * size * 1.15), anchor: .center)
            }
        }
    }

    private func drawText(_ text: String, at point: CGPoint, font: Font, color: Color) {
        context.draw(Text(text).font(font).foregroundStyle(color), at: point, anchor: .center)
    }

    private func pine(x: CGFloat, y: CGFloat, scale s: CGFloat) -> Path {
        let points: [(CGFloat, CGFloat)] = [(0, -22), (7, -9), (3, -9), (10, 2), (4, 2), (12, 14), (1.5, 14), (1.5, 22),
                                            (-1.5, 22), (-1.5, 14), (-12, 14), (-4, 2), (-10, 2), (-3, -9), (-7, -9)]
        var path = Path()
        path.addLines(points.map { CGPoint(x: x + $0.0 * s, y: y + $0.1 * s) })
        path.closeSubpath()
        return path
    }

    /// A wobbly closed contour around a centre.
    private mutating func blob(center: CGPoint, radius: CGFloat, phase: Double) -> Path {
        let count = 24
        let points: [CGPoint] = (0..<count).map { i in
            let angle = Double(i) / Double(count) * 2 * .pi
            let r = radius * (1 + 0.18 * sin(angle * 3 + phase) + random.range(-0.04, 0.04))
            return CGPoint(x: center.x + cos(angle) * r * 1.2, y: center.y + sin(angle) * r)
        }
        var path = Path()
        let mid = { (a: CGPoint, b: CGPoint) in CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(points[count - 1], points[0]))
        for i in 0..<count {
            path.addQuadCurve(to: mid(points[i], points[(i + 1) % count]), control: points[i])
        }
        path.closeSubpath()
        return path
    }

    /// Splits a title into lines of roughly `maxCharacters`, at most three.
    static func wrap(_ text: String, maxCharacters: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if current.isEmpty {
                current = String(word)
            } else if current.count + word.count + 1 <= maxCharacters {
                current += " " + word
            } else {
                lines.append(current)
                current = String(word)
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.isEmpty ? [""] : Array(lines.prefix(3))
    }
}
