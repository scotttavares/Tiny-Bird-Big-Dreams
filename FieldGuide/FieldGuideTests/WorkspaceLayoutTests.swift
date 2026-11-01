import CoreGraphics
import Testing
@testable import FieldGuide

@Suite("WorkspaceLayout")
struct WorkspaceLayoutTests {
    private let size = CGSize(width: 1000, height: 820)

    @Test func bookKeepsEverythingOffTheHinge() {
        let inputs = PostureInputs(activeDivision: CGRect(x: 494, y: 0, width: 12, height: 820), containerSize: size)
        let hinge = PostureMapper.hingeRect(for: .book, inputs: inputs)
        let frames = WorkspaceLayout.frames(posture: .book, size: size, hinge: hinge, headerHeight: 52, toolHeight: 60)

        #expect(frames.header.maxX <= hinge.minX)
        #expect(frames.reference.maxX <= hinge.minX)
        #expect(frames.canvas.minX >= hinge.maxX)
        #expect(frames.tools.minX >= hinge.maxX)
        #expect(frames.canvas.maxY <= frames.tools.minY)
        #expect(frames.tools.maxY <= size.height)
        #expect(frames.showsReference && frames.showsGutter)
    }

    @Test func laptopPutsReferenceAboveAndCanvasBelow() {
        let inputs = PostureInputs(activeDivision: CGRect(x: 0, y: 404, width: 1000, height: 12), containerSize: size)
        let hinge = PostureMapper.hingeRect(for: .laptop, inputs: inputs)
        let frames = WorkspaceLayout.frames(posture: .laptop, size: size, hinge: hinge, headerHeight: 52, toolHeight: 60)

        #expect(frames.reference.maxY <= hinge.minY)
        #expect(frames.header.maxY <= hinge.minY)
        #expect(frames.canvas.minY >= hinge.maxY)
        #expect(frames.tools.minY >= frames.canvas.maxY)
        #expect(frames.tools.maxY <= size.height)
    }

    @Test func closedIsSinglePageWithTools() {
        let phone = CGSize(width: 390, height: 780)
        let frames = WorkspaceLayout.frames(posture: .closed, size: phone, hinge: .null, headerHeight: 52, toolHeight: 60)
        #expect(!frames.showsReference)
        #expect(frames.showsTools)
        #expect(frames.canvas.width > phone.width * 0.9)
        #expect(frames.canvas.minY >= frames.header.maxY)
        #expect(frames.canvas.maxY <= frames.tools.minY)
    }

    @Test func tentHidesToolsAndEnlargesCanvas() {
        let frames = WorkspaceLayout.frames(posture: .tent, size: size, hinge: .null, headerHeight: 52, toolHeight: 60)
        #expect(!frames.showsTools)
        #expect(frames.tools.minY >= size.height)
        #expect(frames.canvas.height > size.height * 0.8)
    }

    @Test(arguments: Posture.allCases)
    func framesAreNeverNegative(posture: Posture) {
        let tiny = CGSize(width: 40, height: 40)
        let frames = WorkspaceLayout.frames(posture: posture, size: tiny, hinge: CGRect(x: 20, y: 0, width: 24, height: 40),
                                            headerHeight: 52, toolHeight: 60)
        for rect in [frames.header, frames.reference, frames.canvas, frames.tools] {
            #expect(rect.width >= 0)
            #expect(rect.height >= 0)
        }
    }
}
