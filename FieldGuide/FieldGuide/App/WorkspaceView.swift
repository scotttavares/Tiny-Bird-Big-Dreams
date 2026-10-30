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
    @State private var isShowingStickers = false
    /// Closed by a swipe on the top bar, in any posture.
    @State private var isClosed = false
    /// Both sides of a tent in use, for showing a page or playing the drawing game.
    @State private var stage: TentStage?

    private func frames(for current: ShownPosture, size: CGSize) -> WorkspaceFrames {
        var frames = WorkspaceLayout.frames(
            posture: current.posture,
            size: size,
            hinge: current.hinge,
            headerHeight: headerHeight,
            toolHeight: toolHeight
        )
        if stage != nil, current.posture == .tent {
            // This half holds the canvas above the controls; the other half faces the audience.
            let top = size.height / 2 + 8
            frames.canvas = CGRect(x: 12, y: top, width: size.width - 24, height: max(size.height - top - 76, 0))
        }
        return frames
    }

    var body: some View {
        GeometryReader { proxy in
            let current = effective(size: proxy.size)
            let frames = frames(for: current, size: proxy.size)

            ZStack(alignment: .topLeading) {
                LeftPage(model: model)
                    .placed(in: frames.reference, visible: frames.showsReference)

                HingeGutter(axis: current.posture == .laptop ? .horizontal : .vertical)
                    .placed(in: frames.gutter, visible: frames.showsGutter)

                CanvasPane(model: model, reduceMotion: reduceMotion)
                    .placed(in: frames.canvas, visible: true)

                ToolStrip(store: model.canvas, style: current.posture == .closed ? .compact : .full) {
                    isShowingStickers = true
                }
                .placed(in: frames.tools, visible: frames.showsTools)

                WorkspaceHeader(
                    model: model,
                    postureProvider: postureProvider,
                    posture: current.posture,
                    onReturnToDraw: returnToDraw,
                    onCloseNotebook: closeNotebook,
                    onStage: { stage = $0 }
                )
                .placed(in: frames.header, visible: stage == nil)

                if let stage, current.posture == .tent {
                    TentStageView(model: model, stage: stage) { self.stage = nil }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .zIndex(1)
                }

                if isClosed || (current.posture == .closed && !coverOpen) {
                    CoverScreen(model: model) {
                        coverOpen = true
                        isClosed = false
                    }
                        .padding(4)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .animation(Theme.postureAnimation(reduceMotion: reduceMotion), value: current)
            .onChange(of: stage) { _, stage in
                model.canvas.isReadOnly = current.posture == .tent && stage != .game
            }
            .onChange(of: current.posture, initial: true) { old, posture in
                if posture != .tent { stage = nil }
                model.canvas.isReadOnly = posture == .tent && stage != .game
                // Folding the phone shut closes the book again.
                if posture == .closed && old != .closed {
                    coverOpen = false
                    savedByClosing()
                }
                // Unfolding opens it to the page, however it was closed.
                if posture != old { isClosed = false }
            }
        }
        .background(Theme.chrome.ignoresSafeArea())
        .sheet(isPresented: $isShowingStickers) {
            StickerPicker(model: model)
        }
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

    // MARK: Closing

    private func closeNotebook() {
        withAnimation(.smooth(duration: 0.3)) { isClosed = true }
        savedByClosing()
    }

    private func savedByClosing() {
        model.flushAll()
        BookSound.playClose()
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

/// The canvas on its paper. Pages turn like paper: hold a page anywhere along its outer edge and
/// drag (or tap the edge, or use the header arrows), and the sheet rolls over from where it's held.
///
/// The turn is drawn over the live canvas from snapshots, so the `PKCanvasView` itself never
/// moves; the page change is applied underneath once the sheet has landed.
struct CanvasPane: View {
    let model: AppModel
    let reduceMotion: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var fade: Double = 1
    @State private var turn: PageTurn?
    @State private var motion = PageTurnMotion()
    /// The next page change comes from a finished turn, so it needs no extra animation.
    @State private var turnedByCurl = false

    private static let pageSpace = "page"

    var body: some View {
        GeometryReader { proxy in
            let page = Self.pageRect(in: proxy.size)
            ZStack(alignment: .topLeading) {
                CanvasView(store: model.canvas)
                    .background(Theme.chrome)
                    .clipShape(.rect(cornerRadius: 6))
                    .opacity(fade)

                pageLayer(size: page.size)
                    .frame(width: page.width, height: page.height, alignment: .topLeading)
                    .offset(x: page.minX, y: page.minY)
            }
            .dropDestination(for: String.self) { tokens, location in
                guard let token = tokens.first else { return false }
                let scale = PageGeometry.size.width / max(page.width, 1)
                let point = CGPoint(x: (location.x - page.minX) * scale, y: (location.y - page.minY) * scale)
                if token == ReferenceSlot.dragToken {
                    model.stickReferencePhoto(at: point)
                } else if let id = LastPageSpread.itemID(from: token) {
                    model.copyPreviousItem(id, at: point)
                } else {
                    return false
                }
                return true
            }
            .onAppear { installTurnHandler(pageSize: page.size) }
            .onChange(of: proxy.size) { _, size in
                installTurnHandler(pageSize: Self.pageRect(in: size).size)
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
        .onDisappear {
            model.pageTurnHandler = nil
            motion.stop()
            turn = nil
        }
    }

    /// Where the page sits inside the pane (the canvas fits the whole page, centred).
    static func pageRect(in size: CGSize) -> CGRect {
        WorkspaceCanvasGeometry.pageRect(in: size)
    }

    // MARK: Page layer

    /// Everything that sits on the page: the corner hints, a page mid-turn, and the edge grips.
    @ViewBuilder
    private func pageLayer(size: CGSize) -> some View {
        let isArranging = model.canvas.isArranging
        let canTurn = !reduceMotion && !model.canvas.isReadOnly && !isArranging
        let grip = max(44, size.width * 0.15)
        ZStack(alignment: .topLeading) {
            if canTurn && turn == nil {
                dogEar(pointsRight: true, size: size, visible: model.nextPage != nil)
                dogEar(pointsRight: false, size: size, visible: model.previousPage != nil)
            }
            if let turn {
                PageCurlView(turn: turn, motion: motion)
            }
            if canTurn {
                edgeGrip(offset: 1, width: grip, size: size)
                edgeGrip(offset: -1, width: grip, size: size)
            }
            if !isArranging && !model.canvas.isReadOnly {
                PageUndoButtons(store: model.canvas)
                    .padding(8)
                    .frame(width: size.width, height: size.height, alignment: .topTrailing)
            }
            if isArranging && !model.canvas.isReadOnly {
                PageItemsEditor(model: model, size: size)
            }
            if let note = model.canvas.shortcutNote {
                Text(note)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: .capsule)
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .padding(.top, 10)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            if model.canvas.isReadOnly {
                // Presenting: swipe through the pages like a slideshow.
                Color.clear
                    .contentShape(.rect)
                    .gesture(presentSwipe)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .coordinateSpace(.named(Self.pageSpace))
    }

    /// A folded-down corner at the bottom of an outer edge: the hint that the page can be turned.
    @ViewBuilder
    private func dogEar(pointsRight: Bool, size: CGSize, visible: Bool) -> some View {
        if visible {
            DogEar(pointsRight: pointsRight)
                .fill(Theme.paperEdge)
                .shadow(color: .black.opacity(0.18), radius: 1.5, x: pointsRight ? -1 : 1, y: -1)
                .frame(width: 22, height: 22)
                .offset(x: pointsRight ? size.width - 22 : 0, y: size.height - 22)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// A strip along the whole height of an outer edge (right for next, left for previous) where
    /// the page can be picked up.
    @ViewBuilder
    private func edgeGrip(offset: Int, width: CGFloat, size: CGSize) -> some View {
        let available = offset > 0 ? model.nextPage != nil : model.previousPage != nil
        if available {
            Color.clear
                .contentShape(.rect)
                .frame(width: width, height: size.height)
                .offset(x: offset > 0 ? size.width - width : 0)
                .gesture(edgeDrag(offset: offset, size: size))
                .accessibilityElement()
                .accessibilityLabel(offset > 0 ? "Turn to the next page" : "Turn back a page")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { model.turnPage(by: offset) }
        }
    }

    private var presentSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let across = value.translation.width
                guard turn == nil, abs(across) > 50, abs(across) > abs(value.translation.height) else { return }
                model.turnPage(by: across < 0 ? 1 : -1)
            }
    }

    private func edgeDrag(offset: Int, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.pageSpace))
            .onChanged { value in
                if turn == nil {
                    guard begin(offset: offset, touch: value.startLocation, size: size) else { return }
                }
                guard let turn, !turn.isSettling, turn.offset == offset else { return }
                motion.follow(value.location)
            }
            .onEnded { value in
                guard let turn, !turn.isSettling, turn.offset == offset else { return }
                let moved = hypot(value.translation.width, value.translation.height) > 6
                let landsOver = turn.isForward ? value.predictedEndLocation.x < size.width / 2
                                               : value.predictedEndLocation.x > size.width / 2
                // A tap on the edge turns the page; a drag turns it if it's thrown or carried past halfway.
                // Two fingers tapping here are an undo.
                let tapped = !moved && !model.canvas.isMultiFingerTouch
                settle(commit: tapped || (moved && landsOver), velocity: CGVector(dx: value.velocity.width, dy: value.velocity.height))
            }
    }

    // MARK: Turning

    /// The header arrows turn the page with a flick from the bottom corner.
    private func installTurnHandler(pageSize: CGSize) {
        model.pageTurnHandler = { (offset: Int) -> Bool in
            let corner = CGPoint(x: offset > 0 ? pageSize.width : 0, y: pageSize.height * 0.85)
            guard begin(offset: offset, touch: corner, size: pageSize) else { return false }
            settle(commit: true, velocity: CGVector(dx: offset > 0 ? -1800 : 1800, dy: -120))
            return true
        }
    }

    /// Picks up the page: snapshots the sheet that will move and the page under it. Returns false
    /// if there's nothing to turn to.
    @discardableResult
    private func begin(offset: Int, touch: CGPoint, size: CGSize) -> Bool {
        guard turn == nil, !reduceMotion, !model.canvas.isDrawing, size.width > 1,
              let current = model.currentPage,
              let target = offset > 0 ? model.nextPage : model.previousPage else { return false }
        let appearance: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let render = { (drawing: PKDrawing, paper: PaperStyle, tint: PaperTint, items: [PageItem]) -> UIImage in
            PageRenderer.sketchImage(drawing: drawing, paperStyle: paper, paperTint: tint, items: items,
                                     width: size.width, appearance: appearance)
        }
        let here = render(model.canvas.drawing, current.paperStyle, current.paperTint, model.canvas.items)
        let there = render(CanvasStore.decode(target.drawingData), target.paperStyle, target.paperTint, target.items)
        let forward = offset > 0
        let sheetTint = forward ? current.paperTint : target.paperTint
        let sheetPaper = sheetTint.paperColor(for: UITraitCollection(userInterfaceStyle: sheetTint.resolvedAppearance(appearance)))
        let y = min(max(touch.y, 0), size.height)
        // Going forward, the current sheet is picked up where the finger is. Going back, the
        // previous sheet lies turned over on the far side of the spine and comes back by its edge.
        let grab = forward ? CGPoint(x: min(max(touch.x, 1), size.width), y: y) : CGPoint(x: size.width, y: y)
        let next = PageTurn(offset: offset, target: target, isForward: forward, grab: grab, size: size,
                            sheet: forward ? here : there, under: forward ? there : here, paper: Color(uiColor: sheetPaper))
        turn = next
        motion.start(at: forward ? next.flatPoint : next.overPoint)
        return true
    }

    /// Lets go: the sheet carries on to land turned over (commit) or falls back where it was.
    private func settle(commit: Bool, velocity: CGVector) {
        guard var settling = turn else { return }
        settling.isSettling = true
        turn = settling
        let finished = settling
        let rest = commit == finished.isForward ? finished.overPoint : finished.flatPoint
        motion.release(to: rest, velocity: velocity) {
            if commit {
                turnedByCurl = true
                model.open(finished.target, direction: finished.offset)
            }
            turn = nil
        }
    }
}

enum WorkspaceCanvasGeometry {
    /// A whole page fitted and centred in `size`.
    static func pageRect(in size: CGSize) -> CGRect {
        let page = PageGeometry.size
        let scale = min(size.width / page.width, size.height / page.height)
        let fitted = CGSize(width: page.width * scale, height: page.height * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2, width: fitted.width, height: fitted.height)
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
