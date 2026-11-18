import SpriteKit
import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// The candy-jelly palette. Each mood has a light (subsurface glow), base and deep (rim) tone.
enum MoodPalette {
    static func light(_ mood: Mood) -> UIColor {
        switch mood {
        case .happy: return UIColor(hex: 0xFFF3B0)
        case .grumpy: return UIColor(hex: 0xFFB8C6)
        case .nervous: return UIColor(hex: 0xCBFFF4)
        }
    }

    static func base(_ mood: Mood) -> UIColor {
        switch mood {
        case .happy: return UIColor(hex: 0xFFC83D)
        case .grumpy: return UIColor(hex: 0xF2546B)
        case .nervous: return UIColor(hex: 0x4FD5C1)
        }
    }

    static func deep(_ mood: Mood) -> UIColor {
        switch mood {
        case .happy: return UIColor(hex: 0xF0861C)
        case .grumpy: return UIColor(hex: 0xB0233F)
        case .nervous: return UIColor(hex: 0x17958A)
        }
    }

    static func color(_ mood: Mood) -> Color { Color(uiColor: base(mood)) }
    static func deepColor(_ mood: Mood) -> Color { Color(uiColor: deep(mood)) }
    static func lightColor(_ mood: Mood) -> Color { Color(uiColor: light(mood)) }

    static let ink = UIColor(hex: 0x3A2440)
    static let cream = UIColor(hex: 0xFFF7EC)
    static let creamEdge = UIColor(hex: 0xE8D2BC)
    static let bouncy = UIColor(hex: 0xFF8DB4)
    static let stone = UIColor(hex: 0xB9AEC8)
    static let stoneDeep = UIColor(hex: 0x7F7194)
}

/// Procedurally rendered, cached textures. Everything is drawn with Core Graphics so the
/// game ships no bitmap art besides the app icon.
@MainActor
enum Art {
    private static var cache: [String: SKTexture] = [:]
    /// Pixels per point for generated textures.
    private static let density: CGFloat = 3

    private static func cached(_ key: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let texture = cache[key] { return texture }
        let format = UIGraphicsImageRendererFormat()
        format.scale = density
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(context.cgContext, size)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        cache[key] = texture
        return texture
    }

    /// A glossy jelly ball: radial body gradient, inner rim, subsurface glow and specular highlight.
    static func jelly(_ mood: Mood, radius: CGFloat) -> SKTexture {
        let r = radius.rounded()
        let size = CGSize(width: r * 2, height: r * 2)
        return cached("jelly-\(mood.rawValue)-\(r)", size: size) { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            let space = CGColorSpaceCreateDeviceRGB()
            ctx.saveGState()
            ctx.addEllipse(in: rect)
            ctx.clip()
            // Body: lit from the top left.
            let colors = [MoodPalette.light(mood).cgColor, MoodPalette.base(mood).cgColor, MoodPalette.deep(mood).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.45, 1]) {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: r * 0.72, y: r * 0.62), startRadius: 0,
                    endCenter: CGPoint(x: r, y: r), endRadius: r * 1.05,
                    options: [.drawsAfterEndLocation]
                )
            }
            // Subsurface glow pooling at the bottom, like light passing through jelly.
            let glow = [MoodPalette.light(mood).withAlphaComponent(0.55).cgColor, MoodPalette.light(mood).withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: glow, locations: [0, 1]) {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: r * 1.1, y: r * 1.62), startRadius: 0,
                    endCenter: CGPoint(x: r * 1.1, y: r * 1.62), endRadius: r * 0.7,
                    options: []
                )
            }
            // Inner rim.
            ctx.setStrokeColor(MoodPalette.deep(mood).withAlphaComponent(0.45).cgColor)
            ctx.setLineWidth(r * 0.1)
            ctx.strokeEllipse(in: rect.insetBy(dx: r * 0.03, dy: r * 0.03))
            ctx.restoreGState()
            // Specular highlights.
            ctx.saveGState()
            ctx.translateBy(x: r * 0.62, y: r * 0.5)
            ctx.rotate(by: -0.45)
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            ctx.fillEllipse(in: CGRect(x: -r * 0.3, y: -r * 0.15, width: r * 0.6, height: r * 0.3))
            ctx.restoreGState()
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
            ctx.fillEllipse(in: CGRect(x: r * 1.18, y: r * 0.42, width: r * 0.14, height: r * 0.14))
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.25).cgColor)
            ctx.fillEllipse(in: CGRect(x: r * 1.2, y: r * 1.45, width: r * 0.35, height: r * 0.16))
        }
    }

    /// A matte pebble with a glowing mood core.
    static func stone(_ mood: Mood, radius: CGFloat) -> SKTexture {
        let r = radius.rounded()
        let size = CGSize(width: r * 2, height: r * 2)
        return cached("stone-\(mood.rawValue)-\(r)", size: size) { ctx, size in
            let space = CGColorSpaceCreateDeviceRGB()
            let rect = CGRect(origin: .zero, size: size)
            ctx.saveGState()
            ctx.addEllipse(in: rect)
            ctx.clip()
            let colors = [UIColor(hex: 0xE6DEF0).cgColor, MoodPalette.stone.cgColor, MoodPalette.stoneDeep.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.55, 1]) {
                ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: r * 0.7, y: r * 0.6), startRadius: 0,
                                       endCenter: CGPoint(x: r, y: r), endRadius: r * 1.05, options: [.drawsAfterEndLocation])
            }
            ctx.restoreGState()
            let core = [MoodPalette.light(mood).cgColor, MoodPalette.base(mood).cgColor, MoodPalette.base(mood).withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: core, locations: [0, 0.5, 1]) {
                ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: r, y: r), startRadius: 0,
                                       endCenter: CGPoint(x: r, y: r), endRadius: r * 0.62, options: [])
            }
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            ctx.fillEllipse(in: CGRect(x: r * 0.45, y: r * 0.35, width: r * 0.42, height: r * 0.22))
        }
    }

    /// Soft contact shadow.
    static func shadow() -> SKTexture {
        cached("shadow", size: CGSize(width: 64, height: 24)) { ctx, size in
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor(hex: 0x3A2440, alpha: 0.35).cgColor, UIColor(hex: 0x3A2440, alpha: 0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
            ctx.scaleBy(x: 1, y: size.height / size.width)
            let c = CGPoint(x: size.width / 2, y: size.width / 2)
            ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: size.width / 2, options: [])
        }
    }

    /// The dreamy backdrop: a warm golden-hour gradient with a soft sun glow.
    static func backdrop(size: CGSize) -> SKTexture {
        cached("backdrop-\(Int(size.width))x\(Int(size.height))", size: size) { ctx, size in
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor(hex: 0xC9B8FF).cgColor, UIColor(hex: 0xFFC7D9).cgColor, UIColor(hex: 0xFFE7C2).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.55, 1]) {
                ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let sun = [UIColor(hex: 0xFFFFFF, alpha: 0.55).cgColor, UIColor(hex: 0xFFFFFF, alpha: 0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: sun, locations: [0, 1]) {
                let c = CGPoint(x: size.width * 0.78, y: size.height * 0.16)
                ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: size.width * 0.6, options: [])
            }
        }
    }

    /// A soft round light used for bokeh and sparkles.
    static func softDot() -> SKTexture {
        cached("softdot", size: CGSize(width: 32, height: 32)) { ctx, size in
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: size.width / 2, options: [])
        }
    }

    /// A small heart, for cheer-ups.
    static func heart() -> SKTexture {
        cached("heart", size: CGSize(width: 24, height: 22)) { ctx, _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 12, y: 21))
            path.addCurve(to: CGPoint(x: 1, y: 7), controlPoint1: CGPoint(x: 6, y: 16), controlPoint2: CGPoint(x: 1, y: 12))
            path.addArc(withCenter: CGPoint(x: 6.5, y: 6.5), radius: 5.5, startAngle: .pi, endAngle: 0, clockwise: true)
            path.addArc(withCenter: CGPoint(x: 17.5, y: 6.5), radius: 5.5, startAngle: .pi, endAngle: 0, clockwise: true)
            path.addCurve(to: CGPoint(x: 12, y: 21), controlPoint1: CGPoint(x: 23, y: 12), controlPoint2: CGPoint(x: 18, y: 16))
            path.close()
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }
    }
}
