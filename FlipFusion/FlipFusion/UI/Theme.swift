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

/// The game's colours. The numbers written here are the Neon look from the mockup;
/// the theme in use (`Skin.current`) recolours the background, board, cards and tiles.
enum Theme {
    /// Splits a hex colour into hue, saturation and brightness (each 0 to 1).
    private static func hsb(_ hex: UInt32) -> (h: Double, s: Double, b: Double) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        let high = max(r, g, b)
        let low = min(r, g, b)
        let spread = high - low
        var hue = 0.0
        if spread > 0 {
            if high == r {
                hue = ((g - b) / spread).truncatingRemainder(dividingBy: 6)
            } else if high == g {
                hue = (b - r) / spread + 2
            } else {
                hue = (r - g) / spread + 4
            }
            hue /= 6
            if hue < 0 {
                hue += 1
            }
        }
        return (hue, high > 0 ? spread / high : 0, high)
    }

    /// A background, board or card colour, recoloured for a theme.
    static func chrome(_ hex: UInt32, opacity: Double = 1, skin: Skin = Skin.current) -> Color {
        guard let hue = skin.chromeHue else {
            return Color(hex: hex, opacity: opacity)
        }
        let parts = hsb(hex)
        return Color(
            hue: hue,
            saturation: parts.s,
            brightness: min(1, parts.b * skin.chromeBrightness),
            opacity: opacity
        )
    }

    /// A tile colour, recoloured for a theme.
    private static func tint(_ hex: UInt32, _ value: Int, _ skin: Skin) -> Color {
        let parts = hsb(hex)
        switch skin.tiles {
        case .original:
            return Color(hex: hex)
        case .shifted(let turn):
            return Color(hue: (parts.h + turn).truncatingRemainder(dividingBy: 1), saturation: parts.s, brightness: parts.b)
        case .band(let from, let to):
            // 2 is level 1, 4 is level 2, and so on up to 2048 at level 11.
            let level = min(11.0, max(1.0, log2(Double(max(2, value)))))
            let hue = (from + (to - from) * (level - 1) / 10).truncatingRemainder(dividingBy: 1)
            // Every other tile is a little paler, so neighbours in the band tell apart.
            let isEven = Int(level) % 2 == 0
            return Color(hue: hue, saturation: parts.s * (isEven ? 0.7 : 1), brightness: parts.b)
        case .pastel:
            return Color(hue: parts.h, saturation: parts.s * 0.62, brightness: min(1, parts.b * 1.08))
        case .icy:
            return Color(hue: parts.h, saturation: parts.s * 0.42, brightness: min(1, parts.b * 1.12))
        }
    }

    private static func style(_ top: UInt32, _ bottom: UInt32, _ value: Int, _ skin: Skin = Skin.current) -> TileStyle {
        TileStyle(top: tint(top, value, skin), bottom: tint(bottom, value, skin))
    }

    /// Four colours that show what a theme looks like: its background and three tiles.
    static func preview(_ skin: Skin) -> [Color] {
        [
            chrome(0x1D2F8F, skin: skin),
            tint(0xFF9484, 2, skin),
            tint(0x66BEFF, 8, skin),
            tint(0xFF8AD8, 32, skin),
        ]
    }

    // Background
    static var backgroundTop: Color { chrome(0x0D1445) }
    static var backgroundBottom: Color { chrome(0x070A26) }
    static var backgroundGlow: Color { chrome(0x1D2F8F) }

    // Glass cards and the board
    static var glassFill: Color { chrome(0x101A52, opacity: 0.78) }
    static var glassStroke: Color { chrome(0x2B3C9A) }
    static var boardFill: Color { chrome(0x0E1750, opacity: 0.9) }
    static var boardStroke: Color { chrome(0x3550C8) }
    static var boardGlow: Color { chrome(0x3D5BFF) }
    static var cellFill: Color { chrome(0x0B1342) }
    static var cellStroke: Color { chrome(0x1F2C78) }

    // Text
    static let label = Color(hex: 0xAEB9F0)
    static let tagline = Color(hex: 0xC9D2F5)
    static let counter = Color(hex: 0xFFD23F)
    static let crown = Color(hex: 0xFFC93C)
    static let timerLow = Color(hex: 0xFF6B6B)

    // Pill
    static var pillTop: Color { chrome(0x4332C8) }
    static var pillBottom: Color { chrome(0x2A1E8C) }
    static var pillStroke: Color { chrome(0x7C6BFF) }

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

    static func tile(_ value: Int, skin: Skin = Skin.current) -> TileStyle {
        switch value {
        case 2: return style(0xFF9484, 0xE8504F, value, skin)
        case 4: return style(0x86F2BC, 0x2FBF7F, value, skin)
        case 8: return style(0x66BEFF, 0x2B6FF0, value, skin)
        case 16: return style(0xBE94FF, 0x7B3FF2, value, skin)
        case 32: return style(0xFF8AD8, 0xE0409F, value, skin)
        case 64: return style(0xFFB067, 0xF0701F, value, skin)
        case 128: return style(0xFFE26A, 0xF0B41F, value, skin)
        case 256: return style(0x6AF0E6, 0x1FB5B0, value, skin)
        case 512: return style(0x8C98FF, 0x4A4FE0, value, skin)
        case 1024: return style(0xF27CFF, 0xB62FE0, value, skin)
        default: return style(0xFFE9A0, 0xE0A020, value, skin)
        }
    }
}
