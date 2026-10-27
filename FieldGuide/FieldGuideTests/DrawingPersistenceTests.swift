import Foundation
import PencilKit
import SwiftData
import Testing
@testable import FieldGuide

@MainActor
@Suite("PKDrawing persistence")
struct DrawingPersistenceTests {
    static func sampleDrawing() -> PKDrawing {
        let points: [PKStrokePoint] = (0..<20).map { (index: Int) -> PKStrokePoint in
            let step = CGFloat(index)
            let location = CGPoint(x: 100 + step * 10, y: 200 + step * 5)
            return PKStrokePoint(
                location: location,
                timeOffset: TimeInterval(index) * 0.01,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let stroke = PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_000))
        )
        var shifted = stroke
        shifted.transform = CGAffineTransform(translationX: 0, y: 100)
        return PKDrawing(strokes: [stroke, shifted])
    }

    @Test func encodeDecodeRoundTrip() {
        let drawing = Self.sampleDrawing()
        let data = CanvasStore.encode(drawing)
        #expect(!data.isEmpty)

        let decoded = CanvasStore.decode(data)
        #expect(decoded.strokes.count == 2)
        #expect(decoded.bounds.integral == drawing.bounds.integral)
        #expect(decoded.strokes[0].path.count == drawing.strokes[0].path.count)
        #expect(decoded.dataRepresentation() == drawing.dataRepresentation())
    }

    @Test func emptyDrawingIsEmptyData() {
        #expect(CanvasStore.encode(PKDrawing()).isEmpty)
        #expect(CanvasStore.decode(Data()).strokes.isEmpty)
    }

    @Test func corruptDataDecodesToEmptyDrawing() {
        #expect(CanvasStore.decode(Data([0x00, 0x01, 0x02])).strokes.isEmpty)
    }

    @Test func roundTripThroughSwiftDataPage() throws {
        let container = try ModelContainer(
            for: Schema(FieldGuideSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let notebook = Notebook(title: "Test")
        context.insert(notebook)
        let page = notebook.addPage()
        page.drawingData = CanvasStore.encode(Self.sampleDrawing())
        try context.save()

        let pageID = page.id
        let descriptor = FetchDescriptor<Page>(predicate: #Predicate { $0.id == pageID })
        let fetched = try #require(try context.fetch(descriptor).first)
        let restored = CanvasStore.decode(fetched.drawingData)
        #expect(restored.strokes.count == 2)
        #expect(restored.dataRepresentation() == Self.sampleDrawing().dataRepresentation())
    }

    @Test func storeLoadsAndPersistsOnFlush() {
        let store = CanvasStore(autosaveDelay: .seconds(60))
        var persisted: [(UUID, PKDrawing)] = []
        store.onPersist = { id, drawing in persisted.append((id, drawing)) }

        let pageID = UUID()
        store.load(pageID: pageID, drawingData: Data(), paperStyle: .grid, referenceImage: nil)
        #expect(store.drawing.strokes.isEmpty)
        #expect(store.paperStyle == .grid)

        // Nothing changed yet: flushing writes nothing.
        store.flush()
        #expect(persisted.isEmpty)

        store.strokeBegan()
        store.drawingDidChange(Self.sampleDrawing())
        #expect(store.isDrawing)
        store.strokeEnded()
        store.flush()

        #expect(persisted.count == 1)
        #expect(persisted.first?.0 == pageID)
        #expect(persisted.first?.1.strokes.count == 2)
        #expect(!store.hasUnsavedChanges)
    }

    @Test func switchingPagesFlushesThePreviousPage() {
        let store = CanvasStore(autosaveDelay: .seconds(60))
        var persistedIDs: [UUID] = []
        store.onPersist = { id, _ in persistedIDs.append(id) }

        let first = UUID()
        let second = UUID()
        store.load(pageID: first, drawingData: Data(), paperStyle: .blank, referenceImage: nil)
        store.drawingDidChange(Self.sampleDrawing())
        store.load(pageID: second, drawingData: CanvasStore.encode(Self.sampleDrawing()), paperStyle: .blank, referenceImage: nil)

        #expect(persistedIDs == [first])
        #expect(store.pageID == second)
        #expect(store.drawing.strokes.count == 2)
        #expect(!store.canUndo)
    }

    @Test func autosaveDebounces() async throws {
        let store = CanvasStore(autosaveDelay: .milliseconds(50))
        var count = 0
        store.onPersist = { _, _ in count += 1 }
        store.load(pageID: UUID(), drawingData: Data(), paperStyle: .blank, referenceImage: nil)

        for _ in 0..<5 {
            store.drawingDidChange(Self.sampleDrawing())
        }
        try await Task.sleep(for: .milliseconds(400))
        #expect(count == 1)
    }

    @Test func toolWidthMapsIntoInkRange() {
        let range = PKInkingTool.InkType.marker.validWidthRange
        #expect(CanvasStore.width(for: .marker, fraction: 0) == range.lowerBound)
        #expect(CanvasStore.width(for: .marker, fraction: 1) == range.upperBound)
        #expect(CanvasStore.width(for: .marker, fraction: 5) == range.upperBound)
    }
}
