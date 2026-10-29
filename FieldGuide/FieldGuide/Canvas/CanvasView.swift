import PencilKit
import SwiftUI
import UIKit

/// SwiftUI wrapper around the one `FieldCanvasView` a `CanvasStore` owns.
///
/// If SwiftUI ever rebuilds this representable, `makeUIView` hands back the store's existing
/// canvas instead of creating a new one, so the drawing, undo stack and any in-flight
/// stroke state stay with the same UIKit view.
struct CanvasView: UIViewRepresentable {
    let store: CanvasStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> FieldCanvasView {
        let view = store.canvasView ?? FieldCanvasView(frame: .zero)
        view.delegate = context.coordinator
        store.attach(view)
        return view
    }

    func updateUIView(_ view: FieldCanvasView, context: Context) {
        if context.coordinator.store !== store {
            context.coordinator.store = store
            store.attach(view)
        }
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var store: CanvasStore

        init(store: CanvasStore) {
            self.store = store
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            store.drawingDidChange(canvasView.drawing)
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            store.strokeBegan()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            store.strokeEnded()
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let canvas = scrollView as? FieldCanvasView else { return }
            canvas.didZoom()
            if !canvas.isApplyingViewport, canvas.fitScale > 0 {
                store.zoomFactor = canvas.zoomScale / canvas.fitScale
            }
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            (scrollView as? FieldCanvasView)?.refreshUnderlayResolution()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let canvas = scrollView as? FieldCanvasView, !canvas.isApplyingViewport else { return }
            store.normalizedCenter = canvas.currentNormalizedCenter
        }
    }
}

/// A `PKCanvasView` showing one fixed-size page, with paper and the tracing image beneath the ink.
final class FieldCanvasView: PKCanvasView {
    weak var store: CanvasStore?

    private let underlay = PaperUnderlayView(frame: PageGeometry.rect)
    private var lastBoundsSize: CGSize = .zero
    private(set) var isApplyingViewport = false

    var paperStyle: PaperStyle {
        get { underlay.style }
        set { underlay.style = newValue }
    }

    /// Light or dark paper also sets the canvas's appearance, so ink stays readable on it.
    var paperTint: PaperTint {
        get { underlay.tint }
        set {
            underlay.tint = newValue
            overrideUserInterfaceStyle = newValue.appearance
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        drawingPolicy = .anyInput
        backgroundColor = .clear
        isOpaque = false
        contentInsetAdjustmentBehavior = .never
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        bouncesZoom = true
        insertSubview(underlay, at: 0)
        accessibilityLabel = "Sketch canvas"
        accessibilityHint = "Draw with a finger or Apple Pencil. Pinch with two fingers to zoom."
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// PencilKit registers stroke undo with the responder's undo manager; route it to the store
    /// so undo history survives the view being re-parented.
    override var undoManager: UndoManager? {
        store?.undoManager ?? super.undoManager
    }

    /// The zoom at which the whole page fits the view.
    var fitScale: CGFloat {
        guard bounds.width > 0, bounds.height > 0 else { return 0 }
        return min(bounds.width / PageGeometry.size.width, bounds.height / PageGeometry.size.height)
    }

    var currentNormalizedCenter: CGPoint {
        guard contentSize.width > 0, contentSize.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(
            x: (contentOffset.x + bounds.width / 2) / contentSize.width,
            y: (contentOffset.y + bounds.height / 2) / contentSize.height
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastBoundsSize, bounds.width > 1, bounds.height > 1 {
            lastBoundsSize = bounds.size
            restoreViewport()
        }
        positionUnderlay()
        if subviews.first !== underlay {
            sendSubviewToBack(underlay)
        }
    }

    /// Re-applies the store's zoom and centre for the current bounds (after a resize or page change).
    func restoreViewport() {
        let fit = fitScale
        guard fit > 0 else { return }
        isApplyingViewport = true
        defer { isApplyingViewport = false }

        let factor = min(max(store?.zoomFactor ?? 1, 1), 6)
        minimumZoomScale = fit
        maximumZoomScale = fit * 6
        setZoomScale(fit * factor, animated: false)
        updateContentLayout()

        let center = store?.normalizedCenter ?? CGPoint(x: 0.5, y: 0.5)
        let target = CGPoint(
            x: center.x * contentSize.width - bounds.width / 2,
            y: center.y * contentSize.height - bounds.height / 2
        )
        contentOffset = clampedOffset(target)
        refreshUnderlayResolution()
    }

    func didZoom() {
        updateContentLayout()
        positionUnderlay()
    }

    func updateTracing(image: UIImage?, visible: Bool) {
        underlay.tracingImage = visible ? image : nil
    }

    func refreshUnderlayResolution() {
        let scale = traitCollection.displayScale * min(max(zoomScale, 0.25), 4)
        if abs(underlay.contentScaleFactor - scale) > 0.01 {
            underlay.contentScaleFactor = scale
            underlay.setNeedsDisplay()
        }
    }

    private func updateContentLayout() {
        let size = CGSize(width: PageGeometry.size.width * zoomScale, height: PageGeometry.size.height * zoomScale)
        if contentSize != size {
            contentSize = size
        }
        let insetX = max(0, (bounds.width - size.width) / 2)
        let insetY = max(0, (bounds.height - size.height) / 2)
        let insets = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        if contentInset != insets {
            contentInset = insets
        }
    }

    private func positionUnderlay() {
        underlay.transform = CGAffineTransform(scaleX: zoomScale, y: zoomScale)
        underlay.center = CGPoint(x: contentSize.width / 2, y: contentSize.height / 2)
    }

    private func clampedOffset(_ point: CGPoint) -> CGPoint {
        let minX = -contentInset.left
        let minY = -contentInset.top
        let maxX = max(minX, contentSize.width + contentInset.right - bounds.width)
        let maxY = max(minY, contentSize.height + contentInset.bottom - bounds.height)
        return CGPoint(x: min(max(point.x, minX), maxX), y: min(max(point.y, minY), maxY))
    }
}

/// Paper pattern plus the optional 30% tracing image, drawn in page coordinates.
final class PaperUnderlayView: UIView {
    var style: PaperStyle = .dotted {
        didSet { if style != oldValue { setNeedsDisplay() } }
    }

    var tint: PaperTint = .automatic {
        didSet { if tint != oldValue { setNeedsDisplay() } }
    }

    var tracingImage: UIImage? {
        didSet {
            tracingView.image = tracingImage
            tracingView.isHidden = tracingImage == nil
        }
    }

    private let tracingView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        tracingView.frame = bounds
        tracingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tracingView.contentMode = .scaleAspectFit
        tracingView.alpha = 0.3
        tracingView.isHidden = true
        tracingView.isAccessibilityElement = false
        addSubview(tracingView)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: PaperUnderlayView, _: UITraitCollection) in
            view.setNeedsDisplay()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        PaperRenderer.draw(
            style,
            in: bounds,
            context: context,
            paper: tint.paperColor(for: traitCollection),
            rule: tint.ruleColor(for: traitCollection)
        )
    }
}
