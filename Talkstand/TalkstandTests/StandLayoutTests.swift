import CoreGraphics
import Testing
@testable import Talkstand

@Suite("StandLayout")
struct StandLayoutTests {
    private let inner = CGSize(width: 1000, height: 1420)

    @Test func horizontalFoldSplitsAtTheHinge() {
        let fold = CGRect(x: 0, y: 700, width: 1000, height: 20)
        let layout = StandLayout.make(size: inner, activeFold: fold)
        #expect(layout.mode == .stand)
        #expect(layout.script == CGRect(x: 0, y: 0, width: 1000, height: 700))
        #expect(layout.stage == CGRect(x: 0, y: 720, width: 1000, height: 700))
        #expect(layout.hinge == fold)
    }

    @Test func noFoldStacks() {
        let layout = StandLayout.make(size: CGSize(width: 400, height: 1000), activeFold: nil)
        #expect(layout.mode == .stacked)
        #expect(layout.script.height == 420)
        #expect(layout.stage.minY == 420)
        #expect(layout.stage.height == 580)
        #expect(layout.hinge.isNull)
    }

    @Test func verticalFoldStacks() {
        let fold = CGRect(x: 490, y: 0, width: 20, height: 1420)
        #expect(StandLayout.make(size: inner, activeFold: fold).mode == .stacked)
    }

    @Test func foldOutsideTheViewStacks() {
        let fold = CGRect(x: 0, y: 1500, width: 1000, height: 20)
        #expect(StandLayout.make(size: inner, activeFold: fold).mode == .stacked)
    }
}
