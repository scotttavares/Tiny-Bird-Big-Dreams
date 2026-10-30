import PencilKit
import Testing
import UIKit
@testable import FieldGuide

@MainActor
struct UndoHistoryTests {
    private func drawing(strokes: Int) -> PKDrawing {
        let point = PKStrokePoint(location: CGPoint(x: 10, y: 10), timeOffset: 0, size: CGSize(width: 4, height: 4),
                                  opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        let path = PKStrokePath(controlPoints: [point, point], creationDate: .now)
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: path)
        return PKDrawing(strokes: Array(repeating: stroke, count: strokes))
    }

    @Test func undoAndRedoStepThroughTheDrawing() {
        let store = CanvasStore()
        store.drawingDidChange(drawing(strokes: 1))
        store.drawingDidChange(drawing(strokes: 2))
        #expect(store.canUndo)

        #expect(store.undo())
        #expect(store.drawing.strokes.count == 1)
        #expect(store.canRedo)

        #expect(store.redo())
        #expect(store.drawing.strokes.count == 2)
        #expect(!store.canRedo)
    }

    @Test func thereIsNothingToUndoOnAFreshPage() {
        let store = CanvasStore()
        #expect(!store.undo())
        #expect(!store.redo())
    }

    @Test func aNewStrokeClearsRedo() {
        let store = CanvasStore()
        store.drawingDidChange(drawing(strokes: 1))
        store.undo()
        store.drawingDidChange(drawing(strokes: 2))
        #expect(!store.canRedo)
    }

    @Test func aDiscardedChangeCannotBeRedone() {
        let store = CanvasStore()
        store.drawingDidChange(drawing(strokes: 1))
        store.discardLastChange()
        #expect(store.drawing.strokes.isEmpty)
        #expect(!store.canRedo)
    }

    @Test func theSameDrawingAddsNoHistory() {
        let store = CanvasStore()
        store.drawingDidChange(store.drawing)
        #expect(!store.canUndo)
    }

    @Test func aCancelledFingerCountsAsLifted() {
        var tap = FingerTap()
        _ = tap.press(2, at: 0)
        #expect(tap.lift(1, at: 0.05) == nil)
        #expect(tap.lift(1, at: 0.1) == 2)
    }
}
