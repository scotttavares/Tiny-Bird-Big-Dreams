import PencilKit
import SwiftData
import UIKit

/// Sample notebook for screenshots and first-run previews (`-FGSeedDemo`).
@MainActor
enum DemoContent {
    static func seed(into context: ModelContext, imageStore: ImageStore) {
        let existing = (try? context.fetchCount(FetchDescriptor<Notebook>())) ?? 0
        guard existing == 0 else { return }

        let notebook = Notebook(title: "Spring Walk", createdAt: .now.addingTimeInterval(-86_400 * 3))
        context.insert(notebook)

        let fern = notebook.addPage(now: .now.addingTimeInterval(-86_400 * 2))
        fern.title = "Lady fern, creek bank"
        fern.locationName = "Mill Creek Trail"
        fern.tags = ["fern", "riparian"]
        fern.paperStyle = .dotted
        fern.drawingData = CanvasStore.encode(leafSketch())
        if let path = try? imageStore.save(specimenPhoto()) {
            let asset = ReferenceAsset(kind: .library, relativeImagePath: path)
            context.insert(asset)
            fern.reference = asset
        }
        fern.thumbnailData = PageRenderer.thumbnailData(drawing: leafSketch(), paperStyle: .dotted)

        let wren = notebook.addPage(now: .now.addingTimeInterval(-86_400))
        wren.title = "Wren song notes"
        wren.locationName = "Orchard hedge"
        wren.tags = ["bird", "song"]
        wren.paperStyle = .lined
        let notes = ReferenceAsset(kind: .notes, notes: """
        Carolina wren, 7:40 am
        • Loud "teakettle-teakettle" from the hedge
        • Cocked tail, pale eyebrow stripe
        • Answered by a second bird to the east
        """)
        context.insert(notes)
        wren.reference = notes
        wren.drawingData = CanvasStore.encode(birdSketch())
        wren.thumbnailData = PageRenderer.thumbnailData(drawing: birdSketch(), paperStyle: .lined)

        let blank = notebook.addPage(now: .now)
        blank.title = "Grid study"
        blank.paperStyle = .grid
        blank.tags = ["practice"]

        // Open on the illustrated fern page: bootstrap reopens the most recently edited page.
        fern.updatedAt = .now.addingTimeInterval(1)
        notebook.updatedAt = .now.addingTimeInterval(1)

        try? context.save()
    }

    // MARK: Generated content

    private static func stroke(_ points: [CGPoint], color: UIColor, width: CGFloat, ink: PKInkingTool.InkType = .pen) -> PKStroke {
        let strokePoints = points.enumerated().map { index, point in
            PKStrokePoint(
                location: point,
                timeOffset: TimeInterval(index) * 0.01,
                size: CGSize(width: width, height: width),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let path = PKStrokePath(controlPoints: strokePoints, creationDate: .now)
        return PKStroke(ink: PKInk(ink, color: color), path: path)
    }

    static func leafSketch() -> PKDrawing {
        let ink = InkSwatch.palette[5].uiColor
        let sepia = InkSwatch.palette[2].uiColor
        var strokes: [PKStroke] = []
        // Rachis.
        strokes.append(stroke(stride(from: CGFloat(0), through: 1.0, by: 0.02).map { t in
            CGPoint(x: 400 + 40 * sin(t * 2.4), y: 980 - 820 * t)
        }, color: sepia, width: 5))
        // Pinnae.
        for i in 0..<14 {
            let t = CGFloat(i) / 14
            let base = CGPoint(x: 400 + 40 * sin(t * 2.4), y: 960 - 820 * t)
            let length = 230 * (1 - t * 0.85)
            for side: CGFloat in [-1, 1] {
                strokes.append(stroke(stride(from: CGFloat(0), through: 1.0, by: 0.05).map { s in
                    CGPoint(x: base.x + side * length * s, y: base.y - 60 * s + 18 * sin(s * .pi))
                }, color: ink, width: 3))
            }
        }
        return PKDrawing(strokes: strokes)
    }

    static func birdSketch() -> PKDrawing {
        let ink = InkSwatch.palette[0].uiColor
        let rust = InkSwatch.palette[3].uiColor
        var strokes: [PKStroke] = []
        // Body.
        strokes.append(stroke(stride(from: CGFloat(0), through: 2 * .pi, by: 0.08).map { a in
            CGPoint(x: 400 + 190 * cos(a), y: 560 + 120 * sin(a))
        }, color: ink, width: 4, ink: .pencil))
        // Head.
        strokes.append(stroke(stride(from: CGFloat(0), through: 2 * .pi, by: 0.1).map { a in
            CGPoint(x: 590 + 75 * cos(a), y: 430 + 70 * sin(a))
        }, color: ink, width: 4, ink: .pencil))
        // Beak.
        strokes.append(stroke([CGPoint(x: 660, y: 420), CGPoint(x: 730, y: 432), CGPoint(x: 662, y: 446)], color: ink, width: 3))
        // Cocked tail.
        strokes.append(stroke([CGPoint(x: 230, y: 540), CGPoint(x: 150, y: 380), CGPoint(x: 190, y: 360), CGPoint(x: 260, y: 510)], color: rust, width: 4))
        // Eye stripe.
        strokes.append(stroke(stride(from: CGFloat(0), through: 1.0, by: 0.1).map { t in
            CGPoint(x: 545 + 90 * t, y: 405 - 12 * sin(t * .pi))
        }, color: rust, width: 3))
        return PKDrawing(strokes: strokes)
    }

    /// A procedural "photo" so screenshots have a reference image without bundled assets.
    static func specimenPhoto() -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let colors = [UIColor(red: 0.42, green: 0.52, blue: 0.36, alpha: 1).cgColor,
                          UIColor(red: 0.20, green: 0.30, blue: 0.20, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            cg.setStrokeColor(UIColor(red: 0.72, green: 0.85, blue: 0.55, alpha: 1).cgColor)
            cg.setLineCap(.round)
            cg.setLineWidth(10)
            cg.move(to: CGPoint(x: 450, y: 1150))
            cg.addQuadCurve(to: CGPoint(x: 470, y: 80), control: CGPoint(x: 560, y: 600))
            cg.strokePath()
            cg.setLineWidth(6)
            for i in 0..<16 {
                let t = CGFloat(i) / 16
                let y = 1080 - 960 * t
                let x = 450 + 60 * sin(t * 2.4)
                let length = 330 * (1 - t * 0.8)
                cg.move(to: CGPoint(x: x, y: y))
                cg.addLine(to: CGPoint(x: x - length, y: y - 80))
                cg.move(to: CGPoint(x: x, y: y))
                cg.addLine(to: CGPoint(x: x + length, y: y - 80))
            }
            cg.strokePath()
        }
    }
}
