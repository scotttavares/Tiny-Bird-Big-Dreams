import SwiftUI

/// The page workspace. One set of panes (header, reference, gutter, canvas, tools) whose
/// frames come from `WorkspaceLayout` for the current posture.
struct WorkspaceView: View {
    let model: AppModel
    let postureProvider: any PostureProvider

    @ScaledMetric(relativeTo: .body) private var headerHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var toolHeight: CGFloat = 60

    var body: some View {
        GeometryReader { proxy in
            let posture = postureProvider.posture
            let frames = WorkspaceLayout.frames(
                posture: posture,
                size: proxy.size,
                hinge: postureProvider.hingeRect,
                headerHeight: headerHeight,
                toolHeight: toolHeight
            )

            ZStack(alignment: .topLeading) {
                ReferenceSlot(model: model)
                    .placed(in: frames.reference, visible: frames.showsReference)

                HingeGutter(axis: posture == .laptop ? .horizontal : .vertical)
                    .placed(in: frames.gutter, visible: frames.showsGutter)

                CanvasPane(model: model)
                    .placed(in: frames.canvas, visible: true)

                ToolStrip(store: model.canvas, style: posture == .closed ? .compact : .full)
                    .placed(in: frames.tools, visible: frames.showsTools)

                WorkspaceHeader(model: model, postureProvider: postureProvider, posture: posture)
                    .placed(in: frames.header, visible: true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .background(Theme.chrome.ignoresSafeArea())
        .readsPosture(into: postureProvider)
    }
}

/// The canvas on its paper, with the page-edge shadow.
struct CanvasPane: View {
    let model: AppModel

    var body: some View {
        CanvasView(store: model.canvas)
            .background(Theme.chrome)
            .clipShape(.rect(cornerRadius: 6))
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
