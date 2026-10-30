import UIKit

/// Draws paper patterns. Shared by the live canvas underlay and the export renderer.
enum PaperRenderer {
    static let spacing: CGFloat = 32
    static let topMargin: CGFloat = 72

    static func draw(_ style: PaperStyle, in rect: CGRect, context: CGContext, paper: UIColor, rule: UIColor) {
        context.saveGState()
        defer { context.restoreGState() }

        context.setFillColor(paper.cgColor)
        context.fill(rect)

        switch style {
        case .blank:
            break
        case .dotted:
            context.setFillColor(rule.cgColor)
            let radius: CGFloat = 1.6
            var y = rect.minY + spacing
            while y < rect.maxY {
                var x = rect.minX + spacing
                while x < rect.maxX {
                    context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    x += spacing
                }
                y += spacing
            }
        case .grid:
            context.setStrokeColor(rule.withAlphaComponent(0.6).cgColor)
            context.setLineWidth(0.75)
            var x = rect.minX + spacing
            while x < rect.maxX {
                context.move(to: CGPoint(x: x, y: rect.minY))
                context.addLine(to: CGPoint(x: x, y: rect.maxY))
                x += spacing
            }
            var y = rect.minY + spacing
            while y < rect.maxY {
                context.move(to: CGPoint(x: rect.minX, y: y))
                context.addLine(to: CGPoint(x: rect.maxX, y: y))
                y += spacing
            }
            context.strokePath()
        case .lined:
            context.setStrokeColor(rule.cgColor)
            context.setLineWidth(1)
            var y = rect.minY + topMargin
            while y < rect.maxY {
                context.move(to: CGPoint(x: rect.minX, y: y))
                context.addLine(to: CGPoint(x: rect.maxX, y: y))
                y += spacing
            }
            context.strokePath()
            // Margin rule.
            context.setStrokeColor(UIColor(red: 0.75, green: 0.42, blue: 0.38, alpha: 0.5).cgColor)
            context.move(to: CGPoint(x: rect.minX + 64, y: rect.minY))
            context.addLine(to: CGPoint(x: rect.minX + 64, y: rect.maxY))
            context.strokePath()
        }
    }
}
