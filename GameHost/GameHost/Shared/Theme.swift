import SwiftUI
import UIKit

/// The warm, wooden-scorepad look: cream paper, walnut ink, amber for the player whose turn it is.
enum Theme {
    static let paper = Color(light: 0xF6EFE3, dark: 0x1E1A16)
    static let card = Color(light: 0xFFFBF4, dark: 0x2A251F)
    static let ink = Color(light: 0x3A2A1A, dark: 0xF3E9DA)
    static let inkSecondary = Color(light: 0x6E5A44, dark: 0xC9B9A3)
    static let accent = Color(light: 0xA45F0F, dark: 0xEF9F27)
    static let onAccent = Color(light: 0xFFF8EE, dark: 0x2A1803)
    static let hairline = Color(light: 0xE2D5C2, dark: 0x3D352C)

    static func fill(_ color: PlayerColor) -> Color {
        switch color {
        case .amber: Color(light: 0xFAEEDA, dark: 0x4A3108)
        case .teal: Color(light: 0xE1F5EE, dark: 0x0B3D31)
        case .violet: Color(light: 0xEEEDFE, dark: 0x2E2869)
        case .rose: Color(light: 0xFBEAF0, dark: 0x5A1E33)
        case .blue: Color(light: 0xE6F1FB, dark: 0x0E3A66)
        case .olive: Color(light: 0xEEF3DE, dark: 0x2E4310)
        }
    }

    static func text(_ color: PlayerColor) -> Color {
        switch color {
        case .amber: Color(light: 0x633806, dark: 0xFAE1B8)
        case .teal: Color(light: 0x085041, dark: 0xBDEBDA)
        case .violet: Color(light: 0x3C3489, dark: 0xDCD9FB)
        case .rose: Color(light: 0x72243E, dark: 0xF7D2DF)
        case .blue: Color(light: 0x0C447C, dark: 0xCDE2F7)
        case .olive: Color(light: 0x3B5410, dark: 0xD8E7B4)
        }
    }
}

extension Color {
    /// A color that follows light and dark mode, from two 0xRRGGBB values.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
