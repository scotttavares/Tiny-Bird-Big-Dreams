import CoreGraphics
import Testing
@testable import FieldGuide

@Suite("Page curl")
struct PageCurlTests {
    private let size = CGSize(width: 400, height: 550)

    @Test func heldWhereItWasPickedUpTheSheetLiesFlat() {
        let point = CGPoint(x: 380, y: 500)
        #expect(PageCurlGeometry(grab: point, finger: point, maxRadius: 48).isFlat)
    }

    @Test func theHeldPointLandsUnderTheFinger() {
        let grab = CGPoint(x: 390, y: 500), finger = CGPoint(x: 80, y: 430)
        let curl = PageCurlGeometry(grab: grab, finger: finger, maxRadius: 48)
        // Rolled over the cylinder, a point `u` past the roll lies at `πr - u`.
        #expect(abs(curl.side(grab) + curl.side(finger) - .pi * curl.radius) < 0.01)
    }

    @Test func theRollNeverOutgrowsItsMaximum() {
        let curl = PageCurlGeometry(grab: CGPoint(x: 400, y: 300), finger: CGPoint(x: -300, y: 300), maxRadius: 48)
        #expect(curl.radius <= 48)
    }

    @Test func aBoundSheetCannotBePulledPastItsWidth() {
        let grab = CGPoint(x: 400, y: 500)
        let held = PageCurlGeometry.constrain(CGPoint(x: -900, y: 900), grab: grab, size: size)
        #expect(hypot(held.x, held.y - grab.y) <= grab.x + 0.01)
    }
}
