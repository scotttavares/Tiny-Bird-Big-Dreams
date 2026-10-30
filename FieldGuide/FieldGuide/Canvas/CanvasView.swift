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
    /// Items laid over the drawing; kept the topmost subview.
    private let overlay = PageItemsLayerView(frame: PageGeometry.rect, overInk: true)
    /// Touch and hold an item to start arranging it, and keep dragging to move it.
    private let itemHold = UILongPressGestureRecognizer()
    private let itemHoldDelegate = ItemHoldDelegate()
    private let shortcutDelegate = ShortcutGestureDelegate()
    private let fingerTap = FingerTapRecognizer()
    /// Strokes on the page when the current touches began, to spot a dot a tap left behind.
    private var strokesAtFirstTouch = 0
    /// A two-finger tap waiting to see if it's the first of a double-tap.
    private var pendingUndo: Task<Void, Never>?
    private var heldItem: (item: PageItem, touch: CGPoint)?
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
        addSubview(overlay)
        itemHold.minimumPressDuration = 0.45
        itemHold.allowableMovement = 10
        itemHold.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        itemHold.cancelsTouchesInView = false
        itemHoldDelegate.canvas = self
        itemHold.delegate = itemHoldDelegate
        itemHold.addTarget(self, action: #selector(itemHoldChanged(_:)))
        addGestureRecognizer(itemHold)
        addShortcutGestures()
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
        if subviews.last !== overlay {
            bringSubviewToFront(overlay)
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

    /// Three fingers belong to redo and page turns here, not the system's editing shortcuts.
    override var editingInteractionConfiguration: UIEditingInteractionConfiguration { .none }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        fingerTap.view?.removeGestureRecognizer(fingerTap)
        window?.addGestureRecognizer(fingerTap)
    }

    /// Two-finger tap undoes, three-finger tap redoes, a two-finger double-tap shows the whole
    /// page, and a three-finger swipe turns the page.
    private func addShortcutGestures() {
        fingerTap.cancelsTouchesInView = false
        fingerTap.delaysTouchesEnded = false
        fingerTap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        fingerTap.delegate = shortcutDelegate
        fingerTap.addTarget(self, action: #selector(fingersTapped))
        fingerTap.accepts = { [weak self] touch in
            guard let self, self.window?.rootViewController?.presentedViewController == nil else { return false }
            return self.bounds.contains(touch.location(in: self))
        }
        fingerTap.onFirstTouch = { [weak self] in
            guard let self else { return }
            self.strokesAtFirstTouch = self.drawing.strokes.count
            self.store?.isMultiFingerTouch = false
        }
        fingerTap.onSecondFinger = { [weak self] dropStroke in
            guard let self else { return }
            self.store?.isMultiFingerTouch = true
            if dropStroke { self.dropCurrentStroke() }
        }
        let nextPage = UISwipeGestureRecognizer(target: self, action: #selector(swipedToNextPage))
        nextPage.numberOfTouchesRequired = 3
        nextPage.direction = .left
        let previousPage = UISwipeGestureRecognizer(target: self, action: #selector(swipedToPreviousPage))
        previousPage.numberOfTouchesRequired = 3
        previousPage.direction = .right
        for gesture in [nextPage, previousPage] {
            gesture.cancelsTouchesInView = false
            gesture.delegate = shortcutDelegate
            addGestureRecognizer(gesture)
        }
    }

    /// Drops the dot the finger started drawing.
    private func dropCurrentStroke() {
        drawingGestureRecognizer.isEnabled = false
        drawingGestureRecognizer.isEnabled = true
    }

    @objc private func fingersTapped() {
        guard let store, !store.isArranging, !store.isReadOnly else { return }
        if drawing.strokes.count > strokesAtFirstTouch { store.undo() }
        switch fingerTap.fingers {
        case 2 where pendingUndo != nil:
            pendingUndo?.cancel()
            pendingUndo = nil
            store.showWholePage()
        case 2:
            pendingUndo = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, !Task.isCancelled else { return }
                self.pendingUndo = nil
                self.store?.undo()
            }
        case 3:
            store.redo()
        default:
            break
        }
    }

    @objc private func swipedToNextPage() { store?.onTurnPage?(1) }
    @objc private func swipedToPreviousPage() { store?.onTurnPage?(-1) }

    /// The item a hold at the recognizer's touch would pick up, if any.
    func itemUnderHold() -> PageItem? {
        guard let store, !store.isArranging else { return nil }
        return store.item(at: itemHold.location(in: overlay))
    }

    @objc private func itemHoldChanged(_ recognizer: UILongPressGestureRecognizer) {
        guard let store else { return }
        // The overlay's coordinates are page coordinates, at any zoom.
        let point = recognizer.location(in: overlay)
        switch recognizer.state {
        case .began:
            guard let item = store.item(at: point) else { return }
            heldItem = (item, point)
            dropCurrentStroke()
            store.beginArranging(selecting: item.id)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .changed:
            guard var (item, touch) = heldItem else { return }
            let page = PageGeometry.size
            item.center = CGPoint(x: min(max(item.center.x + point.x - touch.x, 0), page.width),
                                  y: min(max(item.center.y + point.y - touch.y, 0), page.height))
            touch = point
            heldItem = (item, touch)
            store.update(item)
        case .ended, .cancelled, .failed:
            if heldItem != nil { store.commitItems() }
            heldItem = nil
        default:
            break
        }
    }

    func updateItems(_ items: [PageItem]) {
        underlay.itemsView.items = items
        overlay.items = items
    }

    func refreshUnderlayResolution() {
        let scale = traitCollection.displayScale * min(max(zoomScale, 0.25), 4)
        if abs(underlay.contentScaleFactor - scale) > 0.01 {
            underlay.contentScaleFactor = scale
            underlay.setNeedsDisplay()
            underlay.itemsView.contentScaleFactor = scale
            underlay.itemsView.setNeedsDisplay()
            overlay.contentScaleFactor = scale
            overlay.setNeedsDisplay()
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
        overlay.transform = underlay.transform
        overlay.center = underlay.center
    }

    private func clampedOffset(_ point: CGPoint) -> CGPoint {
        let minX = -contentInset.left
        let minY = -contentInset.top
        let maxX = max(minX, contentSize.width + contentInset.right - bounds.width)
        let maxY = max(minY, contentSize.height + contentInset.bottom - bounds.height)
        return CGPoint(x: min(max(point.x, minX), maxX), y: min(max(point.y, minY), maxY))
    }
}

/// Lets the multi-finger shortcuts run alongside PencilKit's drawing and zooming gestures.
@MainActor
private final class ShortcutGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

/// Lets a hold run alongside drawing, and only start on an item.
@MainActor
private final class ItemHoldDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var canvas: FieldCanvasView?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        canvas?.itemUnderHold() != nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

/// Paper pattern, the optional 30% tracing image and the page's items, in page coordinates.
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
    /// Stickers, photos and tape above the paper and tracing image, under the ink.
    let itemsView = PageItemsLayerView(frame: .zero, overInk: false)

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
        itemsView.frame = bounds
        itemsView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(itemsView)
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
