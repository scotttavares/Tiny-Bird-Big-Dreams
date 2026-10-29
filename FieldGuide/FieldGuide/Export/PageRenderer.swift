import PencilKit
import UIKit

/// Renders a page's sketch (paper + ink) to an image. Shared by thumbnails and exports.
///
/// Rendering always uses the light appearance so exported files look the same whatever
/// the device's appearance; PencilKit resolves dynamic ink colors from the current traits.
@MainActor
enum PageRenderer {
    /// - Parameter appearance: `.light` for exports; the page-turn uses the screen's own appearance
    ///   so the turning sheet matches the live page.
    static func sketchImage(
        drawing: PKDrawing,
        paperStyle: PaperStyle,
        width: CGFloat,
        scale: CGFloat = 2,
        appearance: UIUserInterfaceStyle = .light,
        inkOpacity: CGFloat = 1,
        showsRules: Bool = true
    ) -> UIImage {
        let pageSize = PageGeometry.size
        let factor = width / pageSize.width
        let size = CGSize(width: width, height: pageSize.height * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard

        let traits = UITraitCollection(userInterfaceStyle: appearance)
        var inkImage = UIImage()
        traits.performAsCurrent {
            inkImage = drawing.image(from: PageGeometry.rect, scale: factor * scale)
        }

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.saveGState()
            cg.scaleBy(x: factor, y: factor)
            PaperRenderer.draw(
                showsRules ? paperStyle : .blank,
                in: PageGeometry.rect,
                context: cg,
                paper: Theme.paperUIColor.resolvedColor(with: traits),
                rule: Theme.ruleUIColor.resolvedColor(with: traits)
            )
            cg.restoreGState()
            inkImage.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: inkOpacity)
        }
    }

    /// Small JPEG for the gallery grid.
    static func thumbnailData(drawing: PKDrawing, paperStyle: PaperStyle, width: CGFloat = 240) -> Data? {
        sketchImage(drawing: drawing, paperStyle: paperStyle, width: width, scale: 2)
            .jpegData(compressionQuality: 0.7)
    }
}
