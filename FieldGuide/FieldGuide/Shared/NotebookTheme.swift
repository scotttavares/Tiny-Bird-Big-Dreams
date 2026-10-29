import SwiftUI

/// A notebook's cover design. Each is modelled on a real field notebook: the board colour,
/// the ink printed on it, and the type style of the title.
enum NotebookTheme: String, CaseIterable, Identifiable, Sendable {
    case pines
    case kraft
    case olive
    case weather
    case supply
    case trail

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pines: "Wild Pines"
        case .kraft: "Kraft Memo"
        case .olive: "Olive Drab"
        case .weather: "All Weather"
        case .supply: "Supply Co."
        case .trail: "Trailhead"
        }
    }

    /// The small print under the title.
    var subtitle: String {
        switch self {
        case .pines: "The official field guide to flora, fauna and adventure"
        case .kraft: "Pocket sketchbook · Graph paper · Durable materials"
        case .olive: "Field sketch book · Made by hand"
        case .weather: "Write in the rain"
        case .supply: "Tiny Bird Supply Co."
        case .trail: "Documenting your journey"
        }
    }

    var board: Color { Color(hex: boardHex) }
    var coverInk: Color { Color(hex: coverInkHex) }
    /// Secondary lines on the cover (contours, borders).
    var line: Color { Color(hex: lineHex) }

    /// The satin ribbon and other accents that match the cover.
    var accent: Color { Color(hex: accentHex) }

    var boardHex: UInt32 {
        switch self {
        case .pines: 0x2B3A6E
        case .kraft: 0xD4A243
        case .olive: 0x5C7033
        case .weather: 0xA5C189
        case .supply: 0x6A7860
        case .trail: 0x373E2E
        }
    }

    var coverInkHex: UInt32 {
        switch self {
        case .pines: 0xEF8F3C
        case .kraft: 0x1C1914
        case .olive: 0xECE8D6
        case .weather: 0x2C3824
        case .supply: 0x1B2018
        case .trail: 0xC1802A
        }
    }

    var lineHex: UInt32 {
        switch self {
        case .pines: 0x141C3C
        case .kraft: 0xA77B26
        case .olive: 0x3E4D21
        case .weather: 0x7D9866
        case .supply: 0x4D5945
        case .trail: 0x8A8252
        }
    }

    var accentHex: UInt32 {
        switch self {
        case .pines: 0xB3332B
        case .kraft: 0x28407A
        case .olive: 0x7F2A22
        case .weather: 0xC98F2A
        case .supply: 0x2C4A33
        case .trail: 0xC1802A
        }
    }

    /// Wire-bound designs have rings across the top instead of a stapled spine.
    var isSpiralBound: Bool { self == .weather || self == .supply }

    /// The title type: rounded and heavy, wide grotesque, stencil-like mono, or condensed.
    func titleFont(size: CGFloat) -> Font {
        switch self {
        case .pines, .trail: .system(size: size, weight: .black, design: .rounded)
        case .kraft: .system(size: size, weight: .heavy).width(.expanded)
        case .olive, .weather: .system(size: size, weight: .bold, design: .monospaced)
        case .supply: .system(size: size, weight: .bold).width(.condensed)
        }
    }

    /// A new notebook gets the next design in turn so the shelf stays varied.
    static func next(after count: Int) -> NotebookTheme {
        allCases[count % allCases.count]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// A small deterministic generator, so each notebook's cover wear stays where it is.
struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    init(string: String) {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in string.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        self.init(seed: hash)
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

    mutating func range(_ low: Double, _ high: Double) -> Double { low + unit() * (high - low) }
}
