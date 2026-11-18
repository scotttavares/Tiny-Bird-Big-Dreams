import Foundation

/// A theme: a set of colours for the whole game. A theme is bought with gems or
/// unlocked by doing something in play. The colours themselves are worked out in
/// `Theme` from the numbers here.
struct Skin: Identifiable, Equatable, Sendable {
    /// How a theme is come by.
    enum Unlock: Equatable, Sendable {
        /// Everyone has it from the start.
        case free
        /// Bought with this many gems.
        case gems(Int)
        /// Unlocked by reaching this score in one game.
        case score(Int)
        /// Unlocked by merging four tiles at once.
        case megaCombo
    }

    /// How the tiles are coloured.
    enum TileLook: Equatable, Sendable {
        /// The original rainbow.
        case original
        /// The rainbow, turned round the colour wheel by this fraction of a turn.
        case shifted(Double)
        /// Every tile from one stretch of the colour wheel, small tiles at `from`.
        case band(from: Double, to: Double)
        /// The rainbow, paler and brighter.
        case pastel
    }

    let id: String
    let name: String
    let unlock: Unlock
    /// The colour (0 to 1 round the colour wheel) of the background, board and
    /// cards. nil keeps the original blue.
    let chromeHue: Double?
    /// Makes the background, board and cards brighter (above 1) or darker.
    let chromeBrightness: Double
    let tiles: TileLook

    static let all: [Skin] = [
        Skin(id: "neon", name: "Neon", unlock: .free, chromeHue: nil, chromeBrightness: 1, tiles: .original),
        Skin(id: "sunset", name: "Sunset", unlock: .gems(15), chromeHue: 0.92, chromeBrightness: 1.05, tiles: .shifted(0.04)),
        Skin(id: "ocean", name: "Ocean", unlock: .gems(30), chromeHue: 0.53, chromeBrightness: 0.95, tiles: .band(from: 0.42, to: 0.66)),
        Skin(id: "bubblegum", name: "Bubblegum", unlock: .gems(50), chromeHue: 0.84, chromeBrightness: 1.25, tiles: .pastel),
        Skin(id: "gold", name: "Gold Rush", unlock: .score(2000), chromeHue: 0.09, chromeBrightness: 0.9, tiles: .band(from: 0.02, to: 0.16)),
        Skin(id: "galaxy", name: "Galaxy", unlock: .megaCombo, chromeHue: 0.76, chromeBrightness: 0.7, tiles: .shifted(0.5)),
    ]

    static func named(_ id: String) -> Skin {
        all.first { $0.id == id } ?? all[0]
    }

    /// Where the theme in use is remembered.
    static let key = "ff.skin"

    /// The theme in use. Only ever changed on the main thread, by the theme list in
    /// the menu, which then redraws the screen.
    nonisolated(unsafe) static var current: Skin = named(UserDefaults.standard.string(forKey: key) ?? "")

    /// A short line saying how to get the theme.
    var howToGet: String {
        switch unlock {
        case .free: return "Yours from the start"
        case .gems(let price): return "\(price) gems"
        case .score(let score): return "Score \(score.formatted()) in one game"
        case .megaCombo: return "Merge four tiles at once"
        }
    }
}
