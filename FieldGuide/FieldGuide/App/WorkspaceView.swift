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
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .animation(Theme.postureAnimation(reduceMotion: reduceMotion), value: current)
            .onChange(of: current.posture, initial: true) { _, posture in
                model.canvas.isReadOnly = posture == .tent
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

/// The canvas on its paper, with a gentle page-turn when the page changes.
struct CanvasPane: View {
    let model: AppModel
    let reduceMotion: Bool

    @State private var turnAngle: Double = 0
    @State private var fade: Double = 1

    var body: some View {
        CanvasView(store: model.canvas)
            .background(Theme.chrome)
            .clipShape(.rect(cornerRadius: 6))
            .overlay {
                // Shading that sweeps across while the page settles: the "curl".
                LinearGradient(
                    colors: [.black.opacity(0.22), .clear],
                    startPoint: model.lastTurnDirection > 0 ? .leading : .trailing,
                    endPoint: model.lastTurnDirection > 0 ? .trailing : .leading
                )
                .opacity(abs(turnAngle) / 80)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .rotation3DEffect(
                .degrees(turnAngle),
                axis: (x: 0, y: 1, z: 0),
                anchor: model.lastTurnDirection > 0 ? .leading : .trailing,
                perspective: 0.5
            )
            .opacity(fade)
            .onChange(of: model.pageTurnCount) { _, _ in
                turnPage()
            }
    }

    private func turnPage() {
        if reduceMotion {
            fade = 0.3
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.25)) { fade = 1 }
            }
        } else {
            turnAngle = model.lastTurnDirection > 0 ? -70 : 70
            Task { @MainActor in
                withAnimation(.smooth(duration: 0.45)) { turnAngle = 0 }
            }
        }
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
