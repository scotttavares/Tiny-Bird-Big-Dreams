import PencilKit
import SwiftUI

/// The page workspace. One set of panes (header, reference, gutter, canvas, tools) whose
/// frames come from `WorkspaceLayout` for the current posture.
///
/// State preservation across folds:
/// - Every pane stays in the view tree in every posture, so the canvas `UIView` is never
///   recreated; only its frame animates.
/// - Posture changes that arrive mid-stroke are held until the stroke ends, so the stroke
///   is never cut by a relayout.
/// - Drawing, undo, tool, zoom and scroll live in `CanvasStore`, above all of this.
struct WorkspaceView: View {
    let model: AppModel
    let postureProvider: any PostureProvider

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var headerHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var toolHeight: CGFloat = 60

    /// The posture currently on screen. Lags the provider while a stroke is in progress.
    @State private var shown: ShownPosture?
    /// "Return to draw" was tapped while the device itself reports tent.
    @State private var tentDismissed = false
    /// Folded shut, the outer screen shows the notebook's cover until it's opened.
    @State private var coverOpen = ProcessInfo.processInfo.arguments.contains("-FGCoverOpen")

    var body: some View {
        GeometryReader { proxy in
            let current = effective(size: proxy.size)
            let frames = WorkspaceLayout.frames(
                posture: current.posture,
                size: proxy.size,
                hinge: current.hinge,
                headerHeight: headerHeight,
                toolHeight: toolHeight
            )

            ZStack(alignment: .topLeading) {
                ReferenceSlot(model: model)
                    .placed(in: frames.reference, visible: frames.showsReference)

                HingeGutter(axis: current.posture == .laptop ? .horizontal : .vertical)
                    .placed(in: frames.gutter, visible: frames.showsGutter)

                CanvasPane(model: model, reduceMotion: reduceMotion)
                    .placed(in: frames.canvas, visible: true)

                ToolStrip(store: model.canvas, style: current.posture == .closed ? .compact : .full)
                    .placed(in: frames.tools, visible: frames.showsTools)

                WorkspaceHeader(
                    model: model,
                    postureProvider: postureProvider,
                    posture: current.posture,
                    onReturnToDraw: returnToDraw
                )
                .placed(in: frames.header, visible: true)

                if current.posture == .closed && !coverOpen {
                    CoverScreen(model: model) { coverOpen = true }
                        .padding(4)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .animation(Theme.postureAnimation(reduceMotion: reduceMotion), value: current)
            .onChange(of: current.posture, initial: true) { old, posture in
                model.canvas.isReadOnly = posture == .tent
                // Folding the phone shut closes the book again.
                if posture == .closed && old != .closed { coverOpen = false }
            }
        }
        .background(Theme.chrome.ignoresSafeArea())
        .readsPosture(into: postureProvider)
        .onChange(of: postureProvider.posture, initial: true) { _, posture in
            if posture != .tent { tentDismissed = false }
            applyPostureIfIdle()
        }
        .onChange(of: postureProvider.hingeRect) { _, _ in
            applyPostureIfIdle()
        }
        .onChange(of: model.canvas.isDrawing) { _, isDrawing in
            if !isDrawing { applyPostureIfIdle() }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: model.pageTurnCount)
    }

    // MARK: Posture

    private struct ShownPosture: Equatable {
        var posture: Posture
        var hinge: CGRect
    }

    private func applyPostureIfIdle() {
        guard !model.canvas.isDrawing else { return }
        let next = ShownPosture(posture: postureProvider.posture, hinge: postureProvider.hingeRect)
        guard next != shown else { return }
        shown = next
    }

    private func effective(size: CGSize) -> ShownPosture {
        let base = shown ?? ShownPosture(posture: postureProvider.posture, hinge: postureProvider.hingeRect)
        guard base.posture == .tent, tentDismissed else { return base }
        let fallback: Posture = PostureMapper.isSpreadSized(size) ? .book : .closed
        var inputs = postureProvider.inputs
        inputs.containerSize = size
        return ShownPosture(posture: fallback, hinge: PostureMapper.hingeRect(for: fallback, inputs: inputs))
    }

    private func returnToDraw() {
        if postureProvider.override == .tent {
            postureProvider.override = nil
        } else {
            tentDismissed = true
        }
    }
}

/// The canvas on its paper. Pages turn like paper: drag a page's outer edge (or tap it, or use the
/// header arrows) and the sheet curls over with UIKit's page curl, showing the next page underneath.
///
/// The curl is drawn over the live canvas from snapshots, so the `PKCanvasView` itself never
/// moves; the page change is applied underneath once the sheet has landed.
struct CanvasPane: View {
    let model: AppModel
    let reduceMotion: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var fade: Double = 1
    /// The next page change comes from a finished curl, so it needs no extra animation.
    @State private var turnedByCurl = false
    @ScaledMetric(relativeTo: .body) private var edgeWidth: CGFloat = 36

    var body: some View {
        GeometryReader { proxy in
            let page = Self.pageRect(in: proxy.size)
            ZStack(alignment: .topLeading) {
                CanvasView(store: model.canvas)
                    .background(Theme.chrome)
                    .clipShape(.rect(cornerRadius: 6))
                    .opacity(fade)

                if !model.canvas.isReadOnly && !reduceMotion {
                    dogEar(pointsRight: true, page: page, visible: model.nextPage != nil)
                    dogEar(pointsRight: false, page: page, visible: model.previousPage != nil)
                }

                PageCurlOverlay(model: model, pageSize: page.size, edgeWidth: edgeWidth, isEnabled: !reduceMotion,
                                appearance: colorScheme == .dark ? .dark : .light) {
                    turnedByCurl = true
                }
                .frame(width: page.width, height: page.height)
                .offset(x: page.minX, y: page.minY)
                .accessibilityHidden(true)
            }
        }
        .onChange(of: model.pageTurnCount) { _, _ in
            if turnedByCurl {
                turnedByCurl = false
            } else {
                fade = 0.35
                withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.3)) { fade = 1 }
            }
        }
        .accessibilityAction(named: "Next page") { model.turnPage(by: 1) }
        .accessibilityAction(named: "Previous page") { model.turnPage(by: -1) }
    }

    /// Where the page sits inside the pane (the canvas fits the whole page, centred).
    static func pageRect(in size: CGSize) -> CGRect {
        let page = PageGeometry.size
        let scale = min(size.width / page.width, size.height / page.height)
        let fitted = CGSize(width: page.width * scale, height: page.height * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2, width: fitted.width, height: fitted.height)
    }

    /// A folded-down corner at the bottom of an outer edge: the hint that the page can be turned.
    @ViewBuilder
    private func dogEar(pointsRight: Bool, page: CGRect, visible: Bool) -> some View {
        if visible {
            DogEar(pointsRight: pointsRight)
                .fill(Theme.paperEdge)
                .shadow(color: .black.opacity(0.18), radius: 1.5, x: pointsRight ? -1 : 1, y: -1)
                .frame(width: 22, height: 22)
                .offset(x: pointsRight ? page.maxX - 22 : page.minX, y: page.maxY - 22)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// A folded-down page corner: the hint that a page edge can be grabbed.
private struct DogEar: Shape {
    let pointsRight: Bool

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointsRight {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

/// The fold between the two pages: a soft valley shadow with a stitched spine.
struct HingeGutter: View {
    let axis: Axis

    var body: some View {
        let isVertical = axis == .vertical
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Theme.paperEdge.opacity(0.0), location: 0),
                    .init(color: Color.black.opacity(0.18), location: 0.5),
                    .init(color: Theme.paperEdge.opacity(0.0), location: 1),
                ],
                startPoint: isVertical ? .leading : .top,
                endPoint: isVertical ? .trailing : .bottom
            )
            StitchLine(isVertical: isVertical)
                .stroke(Theme.rule, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct StitchLine: Shape {
    let isVertical: Bool

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        if isVertical {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY + 16))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 16))
        } else {
            path.move(to: CGPoint(x: rect.minX + 16, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - 16, y: rect.midY))
        }
        return path
    }
}

extension View {
    /// Positions a pane by frame, keeping it in the hierarchy (and its identity) when hidden.
    func placed(in rect: CGRect, visible: Bool) -> some View {
        frame(width: max(rect.width, 0), height: max(rect.height, 0))
            .offset(x: rect.minX, y: rect.minY)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}
