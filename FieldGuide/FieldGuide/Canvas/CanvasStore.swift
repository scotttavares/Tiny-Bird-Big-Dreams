import Observation
import PencilKit
import SwiftUI
import UIKit

/// Owns everything about the canvas that must survive layout changes: the drawing, its
/// undo history, the selected tool, zoom and scroll position. The `PKCanvasView` is a view
/// of this state; posture changes move and resize that view but never replace this object.
@MainActor
@Observable
final class CanvasStore {
    enum ToolKind: String, CaseIterable, Identifiable, Sendable {
        case pen, pencil, marker, chalk, eraser

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pen: "Pen"
            case .pencil: "Pencil"
            case .marker: "Marker"
            case .chalk: "Chalk"
            case .eraser: "Eraser"
            }
        }

        var symbol: String {
            switch self {
            case .pen: "pencil.tip"
            case .pencil: "pencil"
            case .marker: "highlighter"
            case .chalk: "scribble.variable"
            case .eraser: "eraser"
            }
        }

        var inkType: PKInkingTool.InkType? {
            switch self {
            case .pen: .pen
            case .pencil: .pencil
            case .marker: .marker
            // Crayon ink: grainy, dusty edges, like chalk on a board.
            case .chalk: .crayon
            case .eraser: nil
            }
        }
    }

    // MARK: Tool state

    var toolKind: ToolKind = .pen {
        didSet { applyTool() }
    }
    /// The selected ink. Starts on the first palette swatch.
    var inkColor: UIColor = InkSwatch.palette[0].uiColor {
        didSet { applyTool() }
    }
    /// Stroke width as a 0…1 fraction of the current ink's valid range.
    var widthFraction: Double = 0.25 {
        didSet { applyTool() }
    }
    var paperStyle: PaperStyle = .dotted {
        didSet {
            canvasView?.paperStyle = paperStyle
            if paperStyle != oldValue, !isLoading { onPaperStyleChange?(paperStyle) }
        }
    }
    /// Tracing mode: the reference image shows at 30% under the canvas.
    var isTracing = false {
        didSet { canvasView?.updateTracing(image: referenceImage, visible: isTracing) }
    }
    var referenceImage: UIImage? {
        didSet { canvasView?.updateTracing(image: referenceImage, visible: isTracing) }
    }
    /// Read-only presentation (tent posture).
    var isReadOnly = false {
        didSet { canvasView?.isUserInteractionEnabled = !isReadOnly }
    }

    // MARK: Drawing state

    private(set) var drawing = PKDrawing()
    private(set) var canUndo = false
    private(set) var canRedo = false
    /// True between a stroke's first touch and its end. Posture changes wait for it.
    private(set) var isDrawing = false
    /// Changes that haven't been handed to `onPersist` yet.
    private(set) var hasUnsavedChanges = false
    private(set) var pageID: UUID?

    /// Zoom relative to "whole page fits", and the visible centre as a fraction of the page.
    /// Kept here so a new frame (posture change) can restore the same view of the page.
    /// Not observed: they change every scroll frame and only the canvas view reads them.
    @ObservationIgnored var zoomFactor: CGFloat = 1
    @ObservationIgnored var normalizedCenter = CGPoint(x: 0.5, y: 0.5)

    let undoManager = UndoManager()

    /// Called with the drawing to persist (debounced after strokes, immediately on `flush`).
    @ObservationIgnored var onPersist: ((UUID, PKDrawing) -> Void)?
    @ObservationIgnored var onPaperStyleChange: ((PaperStyle) -> Void)?
    @ObservationIgnored weak var canvasView: FieldCanvasView?

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private let autosaveDelay: Duration

    init(autosaveDelay: Duration = .milliseconds(600)) {
        self.autosaveDelay = autosaveDelay
    }

    // MARK: Loading pages

    /// Shows another page. Saves the current one first; resets undo and the view of the page.
    func load(pageID: UUID, drawingData: Data, paperStyle: PaperStyle, referenceImage: UIImage?) {
        flush()
        isLoading = true
        defer { isLoading = false }

        self.pageID = pageID
        drawing = Self.decode(drawingData)
        undoManager.removeAllActions()
        zoomFactor = 1
        normalizedCenter = CGPoint(x: 0.5, y: 0.5)
        self.paperStyle = paperStyle
        self.referenceImage = referenceImage
        hasUnsavedChanges = false
        canvasView?.drawing = drawing
        canvasView?.restoreViewport()
        refreshUndoState()
    }

    // MARK: Canvas callbacks

    func attach(_ view: FieldCanvasView) {
        canvasView = view
        view.store = self
        if view.drawing != drawing {
            isLoading = true
            view.drawing = drawing
            isLoading = false
        }
        view.paperStyle = paperStyle
        view.updateTracing(image: referenceImage, visible: isTracing)
        view.isUserInteractionEnabled = !isReadOnly
        applyTool()
    }

    func drawingDidChange(_ newDrawing: PKDrawing) {
        guard !isLoading else { return }
        drawing = newDrawing
        hasUnsavedChanges = true
        refreshUndoState()
        // Eraser and undo don't produce begin/end events; save them on the same debounce.
        if !isDrawing { scheduleSave() }
    }

    func strokeBegan() {
        isDrawing = true
        saveTask?.cancel()
    }

    func strokeEnded() {
        isDrawing = false
        scheduleSave()
    }

    // MARK: Undo

    func undo() {
        guard undoManager.canUndo else { return }
        undoManager.undo()
        syncFromView()
    }

    func redo() {
        guard undoManager.canRedo else { return }
        undoManager.redo()
        syncFromView()
    }

    private func syncFromView() {
        if let canvasView, canvasView.drawing != drawing {
            drawingDidChange(canvasView.drawing)
        }
        refreshUndoState()
    }

    func refreshUndoState() {
        canUndo = undoManager.canUndo
        canRedo = undoManager.canRedo
    }

    // MARK: Autosave

    private func scheduleSave() {
        saveTask?.cancel()
        let delay = autosaveDelay
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    /// Persists immediately if anything changed. Called on page change and scene phase change.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        save()
    }

    private func save() {
        guard hasUnsavedChanges, let pageID else { return }
        hasUnsavedChanges = false
        onPersist?(pageID, drawing)
    }

    // MARK: Tools

    var currentTool: PKTool {
        guard let inkType = toolKind.inkType else {
            return PKEraserTool(.vector)
        }
        return PKInkingTool(inkType, color: inkColor, width: Self.width(for: inkType, fraction: widthFraction))
    }

    static func width(for inkType: PKInkingTool.InkType, fraction: Double) -> CGFloat {
        let range = inkType.validWidthRange
        let clamped = min(max(fraction, 0), 1)
        return range.lowerBound + (range.upperBound - range.lowerBound) * CGFloat(clamped)
    }

    private func applyTool() {
        canvasView?.tool = currentTool
    }

    // MARK: Persistence helpers

    static func encode(_ drawing: PKDrawing) -> Data {
        drawing.strokes.isEmpty ? Data() : drawing.dataRepresentation()
    }

    static func decode(_ data: Data) -> PKDrawing {
        guard !data.isEmpty, let drawing = try? PKDrawing(data: data) else { return PKDrawing() }
        return drawing
    }
}
