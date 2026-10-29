import CoreGraphics
import Testing
@testable import FieldGuide

@Suite("Page curl and covers")
struct PageCurlTests {
    private let size = CGSize(width: 400, height: 550)

    @Test func lyingFlatNothingLifts() {
        let corner = CGPoint(x: 400, y: 550)
        let curl = PageCurlGeometry(size: size, corner: corner, fold: corner)
        #expect(curl.lift < 0.001)
    }

    @Test func flatAndLiftedPartsMakeTheWholeSheet() {
        let curl = PageCurlGeometry(size: size, corner: CGPoint(x: 400, y: 550), fold: CGPoint(x: 150, y: 420))
        let flat = PageCurlGeometry.area(curl.flat), lifted = PageCurlGeometry.area(curl.lifted)
        #expect(lifted > 0 && flat > 0)
        #expect(abs(flat + lifted - size.width * size.height) < 1)
        // Folding over moves paper, it doesn't make or lose any.
        #expect(abs(PageCurlGeometry.area(curl.flap) - lifted) < 1)
    }

    @Test func theCornerLandsWhereItIsPulled() {
        let corner = CGPoint(x: 400, y: 550), fold = CGPoint(x: 120, y: 380)
        let curl = PageCurlGeometry(size: size, corner: corner, fold: fold)
        let landed = curl.reflect(corner)
        #expect(abs(landed.x - fold.x) < 0.01 && abs(landed.y - fold.y) < 0.01)
    }

    @Test func aBoundSheetCannotBePulledPastItsWidth() {
        let held = PageCurlGeometry.constrain(CGPoint(x: -900, y: 900), cornerY: 550, size: size)
        #expect(hypot(held.x, held.y - 550) <= 400.01)
    }

    @Test func newNotebooksCycleThroughCovers() {
        #expect(NotebookTheme.next(after: 0) == .pines)
        #expect(NotebookTheme.next(after: 1) == .kraft)
        #expect(NotebookTheme.next(after: NotebookTheme.allCases.count) == .pines)
    }
}
