import PencilKit
import UIKit

/// A page flattened into plain values for rendering, independent of SwiftData.
struct ExportPage {
    var title: String
    var fieldDate: Date
    var locationName: String
    var tags: [String]
    var drawing: PKDrawing
    var paperStyle: PaperStyle
    var referenceImage: UIImage?
    var referenceNotes: String?
}

/// Renders pages, spreads and notebooks to PNG and PDF.
@MainActor
enum ExportService {
    /// Width of one page in exported images, in points (rendered at 2×).
    static let pageWidth: CGFloat = 800
    static let margin: CGFloat = 40
    static let captionHeight: CGFloat = 72
    static let gutter: CGFloat = 32

    private static var pageAspect: CGFloat { PageGeometry.size.height / PageGeometry.size.width }

    // MARK: PNG

    /// The sketch page alone, with a caption.
    static func pagePNG(_ page: ExportPage, scale: CGFloat = 2) -> Data {
        let size = singleSize
        return render(size: size, scale: scale) { context in
            drawBackground(in: CGRect(origin: .zero, size: size), context: context)
            drawCaption(for: page, in: CGRect(x: margin, y: margin / 2, width: size.width - 2 * margin, height: captionHeight))
            drawSketch(page, in: CGRect(x: margin, y: captionHeight + margin / 2, width: pageWidth, height: pageWidth * pageAspect), context: context)
        }
    }

    /// Reference on the left, sketch on the right, like the open book.
    static func spreadPNG(_ page: ExportPage, scale: CGFloat = 2) -> Data {
        let size = spreadSize
        return render(size: size, scale: scale) { context in
            drawSpread(page, in: CGRect(origin: .zero, size: size), context: context)
        }
    }

    static var singleSize: CGSize {
        CGSize(width: pageWidth + 2 * margin, height: captionHeight + pageWidth * pageAspect + margin * 1.5)
    }

    static var spreadSize: CGSize {
        CGSize(width: 2 * pageWidth + gutter + 2 * margin, height: captionHeight + pageWidth * pageAspect + margin * 1.5)
    }

    // MARK: PDF

    /// A cover page followed by one spread per page.
    static func notebookPDF(title: String, pages: [ExportPage]) -> Data {
        let bounds = CGRect(origin: .zero, size: spreadSize)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "Field Guide",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        return renderer.pdfData { context in
            context.beginPage()
            drawCover(title: title, pageCount: pages.count, in: bounds, context: context.cgContext)
            for page in pages {
                context.beginPage()
                drawSpread(page, in: bounds, context: context.cgContext)
            }
        }
    }

    // MARK: Files

    /// Writes export data to a uniquely named temporary file for sharing.
    static func temporaryFile(data: Data, name: String, fileExtension: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(sanitized(name)).\(fileExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func sanitized(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:").union(.newlines)
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Field Guide" : cleaned
    }

    // MARK: Drawing

    private static func render(size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            draw(context.cgContext)
        }
    }

    private static func drawSpread(_ page: ExportPage, in bounds: CGRect, context: CGContext) {
        drawBackground(in: bounds, context: context)
        drawCaption(for: page, in: CGRect(x: margin, y: margin / 2, width: bounds.width - 2 * margin, height: captionHeight))
        let pageHeight = pageWidth * pageAspect
        let left = CGRect(x: margin, y: captionHeight + margin / 2, width: pageWidth, height: pageHeight)
        let right = CGRect(x: left.maxX + gutter, y: left.minY, width: pageWidth, height: pageHeight)
        drawReference(page, in: left, context: context)
        drawGutter(between: left, and: right, context: context)
        drawSketch(page, in: right, context: context)
    }

    private static func drawBackground(in rect: CGRect, context: CGContext) {
        context.setFillColor(UIColor(red: 0.91, green: 0.88, blue: 0.82, alpha: 1).cgColor)
        context.fill(rect)
    }

    private static func drawSketch(_ page: ExportPage, in rect: CGRect, context: CGContext) {
        let image = PageRenderer.sketchImage(drawing: page.drawing, paperStyle: page.paperStyle, width: rect.width, scale: 2)
        drawPageShadow(rect, context: context)
        image.draw(in: rect)
    }

    private static func drawReference(_ page: ExportPage, in rect: CGRect, context: CGContext) {
        drawPageShadow(rect, context: context)
        context.setFillColor(Theme.exportPaperUIColor.cgColor)
        context.fill(rect)

        if let image = page.referenceImage {
            let fitted = aspectFit(image.size, in: rect.insetBy(dx: 24, dy: 24))
            image.draw(in: fitted)
        } else if let notes = page.referenceNotes, !notes.isEmpty {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 6
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(descriptor: UIFont.preferredFont(forTextStyle: .body).fontDescriptor.withDesign(.serif)
                    ?? UIFont.preferredFont(forTextStyle: .body).fontDescriptor, size: 26),
                .foregroundColor: UIColor(red: 0.17, green: 0.16, blue: 0.16, alpha: 1),
                .paragraphStyle: style,
            ]
            NSAttributedString(string: notes, attributes: attributes)
                .draw(with: rect.insetBy(dx: 48, dy: 48), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
        } else {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .medium),
                .foregroundColor: UIColor(red: 0.45, green: 0.42, blue: 0.38, alpha: 1),
            ]
            let text = NSAttributedString(string: "No reference", attributes: attributes)
            let size = text.size()
            text.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
        }
    }

    private static func drawGutter(between left: CGRect, and right: CGRect, context: CGContext) {
        let gutterRect = CGRect(x: left.maxX, y: left.minY, width: right.minX - left.maxX, height: left.height)
        let colors = [UIColor.black.withAlphaComponent(0).cgColor,
                      UIColor.black.withAlphaComponent(0.16).cgColor,
                      UIColor.black.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) else { return }
        context.saveGState()
        context.clip(to: gutterRect)
        context.drawLinearGradient(gradient, start: CGPoint(x: gutterRect.minX, y: 0), end: CGPoint(x: gutterRect.maxX, y: 0), options: [])
        context.restoreGState()
    }

    private static func drawPageShadow(_ rect: CGRect, context: CGContext) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 3), blur: 10, color: UIColor.black.withAlphaComponent(0.18).cgColor)
        context.setFillColor(Theme.exportPaperUIColor.cgColor)
        context.fill(rect)
        context.restoreGState()
    }

    private static func drawCaption(for page: ExportPage, in rect: CGRect) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: UIColor(red: 0.17, green: 0.16, blue: 0.16, alpha: 1),
        ]
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor(red: 0.35, green: 0.33, blue: 0.30, alpha: 1),
        ]
        NSAttributedString(string: page.title, attributes: titleAttributes)
            .draw(with: CGRect(x: rect.minX, y: rect.minY + 6, width: rect.width, height: 36),
                  options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
        NSAttributedString(string: captionDetail(for: page), attributes: detailAttributes)
            .draw(with: CGRect(x: rect.minX, y: rect.minY + 42, width: rect.width, height: 26),
                  options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    static func captionDetail(for page: ExportPage) -> String {
        var parts = [page.fieldDate.formatted(date: .long, time: .shortened)]
        if !page.locationName.isEmpty { parts.append(page.locationName) }
        if !page.tags.isEmpty { parts.append(page.tags.map { "#\($0)" }.joined(separator: " ")) }
        return parts.joined(separator: "  ·  ")
    }

    private static func drawCover(title: String, pageCount: Int, in bounds: CGRect, context: CGContext) {
        drawBackground(in: bounds, context: context)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(descriptor: UIFont.systemFont(ofSize: 64, weight: .bold).fontDescriptor.withDesign(.serif)
                ?? UIFont.systemFont(ofSize: 64, weight: .bold).fontDescriptor, size: 64),
            .foregroundColor: UIColor(red: 0.17, green: 0.16, blue: 0.16, alpha: 1),
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24),
            .foregroundColor: UIColor(red: 0.35, green: 0.33, blue: 0.30, alpha: 1),
        ]
        let titleText = NSAttributedString(string: title, attributes: titleAttributes)
        let subtitle = NSAttributedString(
            string: "Field Guide · \(pageCount) \(pageCount == 1 ? "page" : "pages") · \(Date.now.formatted(date: .long, time: .omitted))",
            attributes: subtitleAttributes
        )
        let titleSize = titleText.size()
        titleText.draw(at: CGPoint(x: bounds.midX - titleSize.width / 2, y: bounds.midY - titleSize.height))
        let subtitleSize = subtitle.size()
        subtitle.draw(at: CGPoint(x: bounds.midX - subtitleSize.width / 2, y: bounds.midY + 16))
    }

    static func aspectFit(_ size: CGSize, in rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let factor = min(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * factor, height: size.height * factor)
        return CGRect(x: rect.midX - fitted.width / 2, y: rect.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
    }
}

extension ExportPage {
    /// Builds an export snapshot. Pass the live drawing for the open page so unsaved strokes are included.
    @MainActor
    init(page: Page, imageStore: ImageStore, liveDrawing: PKDrawing? = nil) {
        self.init(
            title: page.title,
            fieldDate: page.fieldDate,
            locationName: page.locationName,
            tags: page.tags,
            drawing: liveDrawing ?? CanvasStore.decode(page.drawingData),
            paperStyle: page.paperStyle,
            referenceImage: page.reference?.kind == .notes ? nil : imageStore.image(at: page.reference?.relativeImagePath),
            referenceNotes: page.reference?.kind == .notes ? page.reference?.notes : nil
        )
    }
}
