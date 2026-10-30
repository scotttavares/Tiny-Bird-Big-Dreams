import CoreGraphics
import Foundation
import PencilKit
import Testing
import UIKit
@testable import FieldGuide

@MainActor
@Suite("ExportService")
struct ExportServiceTests {
    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    private func samplePage(reference: UIImage? = nil, notes: String? = nil) -> ExportPage {
        ExportPage(
            title: "Lady fern",
            fieldDate: Date(timeIntervalSince1970: 1_700_000_000),
            locationName: "Mill Creek",
            tags: ["fern", "riparian"],
            drawing: DrawingPersistenceTests.sampleDrawing(),
            paperStyle: .grid,
            referenceImage: reference,
            referenceNotes: notes
        )
    }

    private func solidImage(_ size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func pixelSize(of data: Data) throws -> CGSize {
        let image = try #require(UIImage(data: data))
        return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    @Test func pagePNGIsAValidPNGOfTheExpectedSize() throws {
        let data = ExportService.pagePNG(samplePage(), scale: 2)
        #expect(Array(data.prefix(8)) == Self.pngSignature)
        let size = try pixelSize(of: data)
        #expect(size.width == ExportService.singleSize.width * 2)
        #expect(size.height == ExportService.singleSize.height * 2)
    }

    @Test func spreadPNGIsTwoPagesWide() throws {
        let data = ExportService.spreadPNG(samplePage(reference: solidImage(CGSize(width: 300, height: 200))), scale: 1)
        #expect(Array(data.prefix(8)) == Self.pngSignature)
        let size = try pixelSize(of: data)
        #expect(size.width == ExportService.spreadSize.width)
        #expect(size.width > 2 * ExportService.pageWidth)
        #expect(size.height == ExportService.singleSize.height)
    }

    @Test func spreadRendersReferencePixelsOnTheLeftPage() throws {
        let data = ExportService.spreadPNG(samplePage(reference: solidImage(CGSize(width: 400, height: 400))), scale: 1)
        let image = try #require(UIImage(data: data)?.cgImage)
        // Centre of the left page should be the green reference, not paper.
        let pageHeight: CGFloat = ExportService.pageWidth * PageGeometry.size.height / PageGeometry.size.width
        let x: CGFloat = ExportService.margin + ExportService.pageWidth / 2
        let top: CGFloat = ExportService.captionHeight + ExportService.margin / 2
        let point = CGPoint(x: x, y: top + pageHeight / 2)
        let color = try #require(pixel(in: image, at: point))
        #expect(color.green > color.red)
        #expect(color.green > color.blue)
    }

    @Test func spreadWithNotesAndEmptyReferenceStillRenders() {
        #expect(!ExportService.spreadPNG(samplePage(notes: "Pale eyebrow stripe"), scale: 1).isEmpty)
        #expect(!ExportService.spreadPNG(samplePage(), scale: 1).isEmpty)
    }

    @Test func notebookPDFHasCoverPlusOnePagePerSpread() throws {
        let pages = [samplePage(), samplePage(notes: "Notes"), samplePage(reference: solidImage(CGSize(width: 50, height: 80)))]
        let data = ExportService.notebookPDF(title: "Spring Walk", pages: pages)
        #expect(data.starts(with: Array("%PDF".utf8)))
        let provider = try #require(CGDataProvider(data: data as CFData))
        let document = try #require(CGPDFDocument(provider))
        #expect(document.numberOfPages == pages.count + 1)
    }

    @Test func emptyNotebookPDFHasOnlyTheCover() throws {
        let data = ExportService.notebookPDF(title: "Empty", pages: [])
        let provider = try #require(CGDataProvider(data: data as CFData))
        let document = try #require(CGPDFDocument(provider))
        #expect(document.numberOfPages == 1)
    }

    @Test func temporaryFileNamesAreSanitized() throws {
        let url = try ExportService.temporaryFile(data: Data([1, 2, 3]), name: "Fern / creek: bank?", fileExtension: "png")
        #expect(url.lastPathComponent == "Fern - creek- bank-.png")
        #expect(try Data(contentsOf: url) == Data([1, 2, 3]))
        #expect(ExportService.sanitized("   ") == "Field Guide")
    }

    @Test func captionIncludesPlaceAndTags() {
        let detail = ExportService.captionDetail(for: samplePage())
        #expect(detail.contains("Mill Creek"))
        #expect(detail.contains("#fern #riparian"))
    }

    @Test func aspectFitCentersAndPreservesRatio() {
        let fitted = ExportService.aspectFit(CGSize(width: 200, height: 100), in: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(fitted == CGRect(x: 0, y: 25, width: 100, height: 50))
    }

    // MARK: Helpers

    private func pixel(in image: CGImage, at point: CGPoint) -> (red: Double, green: Double, blue: Double)? {
        var bytes = [UInt8](repeating: 0, count: 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            // Draw the image offset so the requested pixel lands at (0, 0). CG's origin is bottom-left.
            let flippedY = CGFloat(image.height) - point.y - 1
            context.draw(image, in: CGRect(x: -point.x, y: -flippedY, width: CGFloat(image.width), height: CGFloat(image.height)))
            return true
        }
        guard drawn else { return nil }
        return (Double(bytes[0]) / 255, Double(bytes[1]) / 255, Double(bytes[2]) / 255)
    }
}
