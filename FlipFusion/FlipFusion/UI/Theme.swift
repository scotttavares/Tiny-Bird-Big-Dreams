import SwiftUI

extension Color {
    /// A colour from a hex number such as 0xFF8A7A.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// The Neon look from the mockup. Future themes would be another set of these values.
enum Theme {
    // Background
    static let backgroundTop = Color(hex: 0x0D1445)
    static let backgroundBottom = Color(hex: 0x070A26)
    static let backgroundGlow = Color(hex: 0x1D2F8F)

    // Glass cards and the board
    static let glassFill = Color(hex: 0x101A52, opacity: 0.78)
    static let glassStroke = Color(hex: 0x2B3C9A)
    static let boardFill = Color(hex: 0x0E1750, opacity: 0.9)
    static let boardStroke = Color(hex: 0x3550C8)
    static let boardGlow = Color(hex: 0x3D5BFF)
    static let cellFill = Color(hex: 0x0B1342)
    static let cellStroke = Color(hex: 0x1F2C78)

    // Text
    static let label = Color(hex: 0xAEB9F0)
    static let tagline = Color(hex: 0xC9D2F5)
    static let counter = Color(hex: 0xFFD23F)
    static let crown = Color(hex: 0xFFC93C)

    // Pill
    static let pillTop = Color(hex: 0x4332C8)
    static let pillBottom = Color(hex: 0x2A1E8C)
    static let pillStroke = Color(hex: 0x7C6BFF)

    // Rotation arrow
    static let arrowLight = Color(hex: 0xC08CFF)
    static let arrowDark = Color(hex: 0x6C4BFF)

    // Logo
    static let flip = [Color(hex: 0x8FF0FF), Color(hex: 0x3FA9FF)]
    static let fusion = [Color(hex: 0xFF7AD9), Color(hex: 0xA56BFF)]

    // Page dots
    static let dotOn = Color(hex: 0x39C6F4)
    static let dotOff = Color(hex: 0x3A4480)

    struct TileStyle {
        let top: Color
        let bottom: Color
    }

    static func tile(_ value: Int) -> TileStyle {
        switch value {
        case 2: return TileStyle(top: Color(hex: 0xFF9484), bottom: Color(hex: 0xE8504F))
        case 4: return TileStyle(top: Color(hex: 0x86F2BC), bottom: Color(hex: 0x2FBF7F))
        case 8: return TileStyle(top: Color(hex: 0x66BEFF), bottom: Color(hex: 0x2B6FF0))
        case 16: return TileStyle(top: Color(hex: 0xBE94FF), bottom: Color(hex: 0x7B3FF2))
        case 32: return TileStyle(top: Color(hex: 0xFF8AD8), bottom: Color(hex: 0xE0409F))
        case 64: return TileStyle(top: Color(hex: 0xFFB067), bottom: Color(hex: 0xF0701F))
        case 128: return TileStyle(top: Color(hex: 0xFFE26A), bottom: Color(hex: 0xF0B41F))
        case 256: return TileStyle(top: Color(hex: 0x6AF0E6), bottom: Color(hex: 0x1FB5B0))
        case 512: return TileStyle(top: Color(hex: 0x8C98FF), bottom: Color(hex: 0x4A4FE0))
        case 1024: return TileStyle(top: Color(hex: 0xF27CFF), bottom: Color(hex: 0xB62FE0))
        default: return TileStyle(top: Color(hex: 0xFFE9A0), bottom: Color(hex: 0xE0A020))
        }
    }
}
