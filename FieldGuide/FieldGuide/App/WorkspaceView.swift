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
/// header arrows) and the sheet curls over by its corner, showing the next page underneath.
///
/// The curl is drawn over the live canvas from snapshots, so the `PKCanvasView` itself never
/// moves; the page change is applied underneath once the sheet has landed.
struct CanvasPane: View {
    let model: AppModel
    let reduceMotion: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var fade: Double = 1
    @State private var turn: PageTurn?
    @State private var foldX: CGFloat = 1
    @State private var foldY: CGFloat = 1
    /// The next page change comes from a finished curl, so it needs no extra animation.
    @State private var turnedByCurl = false
    @ScaledMetric(relativeTo: .body) private var edgeWidth: CGFloat = 30

    var body: some View {
        GeometryReader { proxy in
            let page = Self.pageRect(in: proxy.size)
            ZStack(alignment: .topLeading) {
                CanvasView(store: model.canvas)
                    .background(Theme.chrome)
                    .clipShape(.rect(cornerRadius: 6))
                    .opacity(fade)

                if let turn {
                    PageCurlView(front: turn.front, under: turn.under, back: turn.back, paper: Theme.paper,
                                 cornerY: turn.cornerY, foldX: foldX, foldY: foldY)
                        .frame(width: page.width, height: page.height)
                        .offset(x: page.minX, y: page.minY)
                }

                if !model.canvas.isReadOnly {
                    edgeHandle(offset: -1, page: page)
                    edgeHandle(offset: 1, page: page)
                }
            }
            .onAppear {
                model.pageTurnHandler = { offset in
                    startTurn(offset: offset, grabY: 0.85, pageSize: page.size, automatic: true)
                }
            }
            .onChange(of: proxy.size) { _, size in
                let page = Self.pageRect(in: size)
                model.pageTurnHandler = { offset in
                    startTurn(offset: offset, grabY: 0.85, pageSize: page.size, automatic: true)
                }
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
        .onDisappear { model.pageTurnHandler = nil }
    }

    /// Where the page sits inside the pane (the canvas fits the whole page, centred).
    static func pageRect(in size: CGSize) -> CGRect {
        let page = PageGeometry.size
        let scale = min(size.width / page.width, size.height / page.height)
        let fitted = CGSize(width: page.width * scale, height: page.height * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2, width: fitted.width, height: fitted.height)
    }

    // MARK: Page edges

    /// A strip along the page's outer edge (right for next, left for previous) with a folded-corner hint.
    @ViewBuilder
    private func edgeHandle(offset: Int, page: CGRect) -> some View {
        let available = offset > 0 ? model.nextPage != nil : model.previousPage != nil
        if available && !reduceMotion {
            let x = offset > 0 ? page.maxX - edgeWidth : page.minX
            DogEar(pointsRight: offset > 0)
                .fill(Theme.paperEdge)
                .shadow(color: .black.opacity(0.18), radius: 1.5, x: offset > 0 ? -1 : 1, y: -1)
                .frame(width: 22, height: 22)
                .frame(width: edgeWidth, height: page.height * 0.55, alignment: offset > 0 ? .bottomTrailing : .bottomLeading)
                .contentShape(.rect)
                .offset(x: x, y: page.maxY - page.height * 0.55)
                .gesture(edgeDrag(offset: offset, page: page))
                .accessibilityElement()
                .accessibilityLabel(offset > 0 ? "Turn to the next page" : "Turn back a page")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { model.turnPage(by: offset) }
        }
    }

    private func edgeDrag(offset: Int, page: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if turn == nil {
                    let grabY = (page.height * 0.45 + value.startLocation.y) / page.height
                    guard startTurn(offset: offset, grabY: grabY, pageSize: page.size, automatic: false) else { return }
                }
                follow(translation: value.translation, pageSize: page.size)
            }
            .onEnded { value in
                guard let turn, !turn.isSettling else { return }
                let moved = hypot(value.translation.width, value.translation.height) > 6
                let flick = value.predictedEndTranslation.width - value.translation.width
                let progress = (1 - foldX) / 2   // 0: lying flat on the right, 1: turned over to the left
                let commit: Bool
                if !moved {
                    commit = true   // a tap on the edge turns the page
                } else if abs(flick) > page.width * 0.4 {
                    commit = turn.isForward ? flick < 0 : flick > 0
                } else {
                    commit = turn.isForward ? progress > 0.4 : progress < 0.6
                }
                finish(commit: commit)
            }
    }

    // MARK: Turning

    /// Prepares a turn to the neighbouring page. Returns false if there's nothing to turn to.
    @discardableResult
    private func startTurn(offset: Int, grabY: CGFloat, pageSize: CGSize, automatic: Bool) -> Bool {
        guard turn == nil, !reduceMotion, !model.canvas.isDrawing, pageSize.width > 1,
              let current = model.currentPage,
              let target = offset > 0 ? model.nextPage : model.previousPage else { return false }
        let appearance: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let render = { (drawing: PKDrawingSnapshot, faint: Bool) -> Image in
            Image(uiImage: PageRenderer.sketchImage(drawing: drawing.drawing, paperStyle: drawing.paper, width: pageSize.width,
                                                    appearance: appearance, inkOpacity: faint ? 0.12 : 1, showsRules: !faint))
        }
        let here = PKDrawingSnapshot(drawing: model.canvas.drawing, paper: current.paperStyle)
        let there = PKDrawingSnapshot(drawing: CanvasStore.decode(target.drawingData), paper: target.paperStyle)
        let forward = offset > 0
        // Going forward the current sheet peels away to the left; going back the previous sheet
        // swings back over from the left.
        let leaf = forward ? here : there
        let cornerY: CGFloat = grabY < 0.45 ? 0 : 1
        turn = PageTurn(offset: offset, isForward: forward, cornerY: cornerY,
                        front: render(leaf, false), under: render(forward ? there : here, false), back: render(leaf, true))
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            foldX = forward ? 1 : -1
            foldY = cornerY
        }
        if automatic {
            // Let the flat sheet draw once before it starts to move.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(30))
                finish(commit: true)
            }
        }
        return true
    }

    /// The corner follows the finger, held to what a bound sheet of paper can do.
    private func follow(translation: CGSize, pageSize: CGSize) {
        guard let turn, !turn.isSettling else { return }
        let w = pageSize.width, h = pageSize.height
        let startX: CGFloat = turn.isForward ? w : -w
        let dx = translation.width * (turn.isForward ? 1 : 2)
        let progress = max(0, min(1, (w - (startX + dx)) / (2 * w)))
        let lift = (turn.cornerY == 0 ? 1 : -1) * sin(.pi * progress) * h * 0.08
        let point = CGPoint(x: startX + dx, y: turn.cornerY * h + translation.height + lift)
        let held = PageCurlGeometry.constrain(point, cornerY: turn.cornerY * h, size: pageSize)
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            foldX = held.x / w
            foldY = held.y / h
        }
    }

    /// Lets the page fall to one side: over to the next page (commit) or back where it was.
    private func finish(commit: Bool) {
        guard var settling = turn else { return }
        settling.isSettling = true
        turn = settling
        let current = settling
        let lands = commit == current.isForward
        let distance = abs((lands ? -1 : 1) - foldX) / 2
        withAnimation(.timingCurve(0.3, 0.1, 0.25, 1, duration: 0.25 + 0.45 * distance)) {
            foldX = lands ? -1 : 1
            foldY = current.cornerY
        } completion: {
            if commit {
                turnedByCurl = true
                let target = current.offset > 0 ? model.nextPage : model.previousPage
                if let target { model.open(target, direction: current.offset) }
            }
            turn = nil
        }
    }
}

/// A page-turn in progress: snapshots of the sheet being turned (front and back) and of the
/// page it uncovers.
private struct PageTurn {
    let offset: Int
    let isForward: Bool
    /// 0 when the top corner is held, 1 for the bottom corner.
    let cornerY: CGFloat
    let front: Image
    let under: Image
    let back: Image
    var isSettling = false
}

private struct PKDrawingSnapshot {
    let drawing: PKDrawing
    let paper: PaperStyle
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
