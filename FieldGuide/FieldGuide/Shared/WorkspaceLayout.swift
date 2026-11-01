import CoreGraphics

/// Where each part of the workspace goes for a posture. Pure geometry, unit-tested.
///
/// Every posture uses the same set of panes. Only their frames change, so SwiftUI keeps each
/// view's identity (the canvas above all) and animates the frames between postures.
struct WorkspaceFrames: Equatable, Sendable {
    var header: CGRect
    var reference: CGRect
    var gutter: CGRect
    var canvas: CGRect
    var tools: CGRect

    var showsReference: Bool
    var showsGutter: Bool
    var showsTools: Bool
}

enum WorkspaceLayout {
    static let margin: CGFloat = 12

    static func frames(
        posture: Posture,
        size: CGSize,
        hinge: CGRect,
        headerHeight: CGFloat,
        toolHeight: CGFloat
    ) -> WorkspaceFrames {
        let m = margin
        let width = max(size.width, 0)
        let height = max(size.height, 0)

        switch posture {
        case .book:
            // Left page: header + reference. Right page: canvas + tools. Nothing crosses the hinge.
            let leftWidth = max(hinge.minX, 0)
            let rightX = min(hinge.maxX, width)
            let rightWidth = max(width - rightX, 0)
            let header = CGRect(x: m, y: m, width: max(leftWidth - 2 * m, 0), height: headerHeight)
            let reference = CGRect(x: m, y: header.maxY + m, width: header.width, height: max(height - header.maxY - 2 * m, 0))
            let tools = CGRect(x: rightX + m, y: max(height - toolHeight - m, 0), width: max(rightWidth - 2 * m, 0), height: toolHeight)
            let canvas = CGRect(x: rightX + m, y: m, width: tools.width, height: max(tools.minY - 2 * m, 0))
            return WorkspaceFrames(header: header, reference: reference, gutter: hinge, canvas: canvas, tools: tools,
                                   showsReference: true, showsGutter: true, showsTools: true)

        case .laptop:
            // Top half: header + reference. Bottom half: canvas + tools.
            let topHeight = max(hinge.minY, 0)
            let bottomY = min(hinge.maxY, height)
            let header = CGRect(x: m, y: m, width: max(width - 2 * m, 0), height: headerHeight)
            let reference = CGRect(x: m, y: header.maxY + m, width: header.width, height: max(topHeight - header.maxY - 2 * m, 0))
            let tools = CGRect(x: m, y: max(height - toolHeight - m, bottomY), width: header.width, height: toolHeight)
            let canvas = CGRect(x: m, y: bottomY + m, width: header.width, height: max(tools.minY - bottomY - 2 * m, 0))
            return WorkspaceFrames(header: header, reference: reference, gutter: hinge, canvas: canvas, tools: tools,
                                   showsReference: true, showsGutter: true, showsTools: true)

        case .closed:
            // Single page: header, canvas, compact tools. The reference pane folds into the header.
            let header = CGRect(x: m, y: m, width: max(width - 2 * m, 0), height: headerHeight)
            let tools = CGRect(x: m, y: max(height - toolHeight - m, 0), width: header.width, height: toolHeight)
            let canvas = CGRect(x: m / 2, y: header.maxY + m / 2, width: max(width - m, 0), height: max(tools.minY - header.maxY - m, 0))
            let reference = CGRect(x: header.minX, y: header.minY, width: 0, height: header.height)
            return WorkspaceFrames(header: header, reference: reference, gutter: CGRect(x: width / 2, y: 0, width: 0, height: height),
                                   canvas: canvas, tools: tools,
                                   showsReference: false, showsGutter: false, showsTools: true)

        case .tent:
            // The page, large and read-only. Tools slide off the bottom edge.
            let header = CGRect(x: m, y: m, width: max(width - 2 * m, 0), height: headerHeight)
            let canvas = CGRect(x: 2 * m, y: header.maxY + m, width: max(width - 4 * m, 0), height: max(height - header.maxY - 3 * m, 0))
            let tools = CGRect(x: m, y: height + m, width: header.width, height: toolHeight)
            let reference = CGRect(x: header.minX, y: header.minY, width: 0, height: header.height)
            return WorkspaceFrames(header: header, reference: reference, gutter: CGRect(x: width / 2, y: 0, width: 0, height: height),
                                   canvas: canvas, tools: tools,
                                   showsReference: false, showsGutter: false, showsTools: false)
        }
    }
}
