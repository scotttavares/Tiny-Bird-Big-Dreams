import Testing
import UIKit
@testable import FieldGuide

/// WCAG 2.x contrast checks for the palette and UI colors (target 4.5:1).
@MainActor
@Suite("Color contrast")
struct ContrastTests {
    private static var light: UITraitCollection { UITraitCollection(userInterfaceStyle: .light) }
    private static var dark: UITraitCollection { UITraitCollection(userInterfaceStyle: .dark) }

    private func named(_ name: String, _ traits: UITraitCollection) throws -> UIColor {
        try #require(UIColor(named: name)).resolvedColor(with: traits)
    }

    static func relativeLuminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    static func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test(arguments: InkSwatch.palette)
    func inkOnLightPaper(swatch: InkSwatch) throws {
        let paper = try named("PaperColor", Self.light)
        #expect(Self.contrast(swatch.uiColor, paper) >= 4.5, "\(swatch.name)")
    }

    @Test func textOnPaperInBothAppearances() throws {
        for traits in [Self.light, Self.dark] {
            let text = try named("InkTextColor", traits)
            #expect(Self.contrast(text, try named("PaperColor", traits)) >= 4.5)
            #expect(Self.contrast(text, try named("ChromeColor", traits)) >= 4.5)
            #expect(Self.contrast(text, try named("PaperEdgeColor", traits)) >= 4.5)
        }
    }

    @Test func onAccentInBothAppearances() throws {
        for traits in [Self.light, Self.dark] {
            #expect(Self.contrast(try named("OnAccentColor", traits), try named("AccentColor", traits)) >= 4.5)
        }
    }
}
