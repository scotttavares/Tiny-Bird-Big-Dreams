import Foundation

/// A theme: its own colours, its own moving backdrop, its own tile shape and its own
/// sparks. A theme is bought with gems or unlocked by doing something in play. The
/// colours are worked out in `Theme`, the backdrop is drawn by `SceneView` and the
/// tile shape by `TileOutline`.
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
        /// Unlocked by reaching this level in one game.
        case level(Int)
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
        /// The rainbow, washed almost to white, like ice.
        case icy
    }

    /// What moves behind the game.
    enum Backdrop: Equatable, Sendable {
        /// A glowing floor of lines rolling toward you.
        case grid
        /// A striped setting sun.
        case sun
        /// Bubbles rising.
        case bubbles
        /// Hearts floating up.
        case hearts
        /// Sparks rising from a glow at the bottom.
        case embers
        /// Snow falling.
        case snow
        /// Gold dust and diamonds falling.
        case coins
        /// Coloured lights sweeping about.
        case lights
        /// Twinkling stars and shooting stars.
        case stars
    }

    /// The outline of every tile.
    enum TileShape: Equatable, Sendable {
        /// A square with rounded corners.
        case rounded
        /// A round, glassy bubble.
        case bubble
        /// A very soft square with a stripe of gloss.
        case jelly
        /// A square with its corners cut off, like a cut stone.
        case gem
        /// A cut stone with bigger cuts.
        case crystal
        /// A six-sided tile.
        case hex
        /// A ball lit from one side, like a planet.
        case orb
    }

    let id: String
    let name: String
    /// A few words that sell the theme on its card.
    let blurb: String
    let unlock: Unlock
    /// The colour (0 to 1 round the colour wheel) of the background, board and
    /// cards. nil keeps the original blue.
    let chromeHue: Double?
    /// Makes the background, board and cards brighter (above 1) or darker.
    let chromeBrightness: Double
    let tiles: TileLook
    let backdrop: Backdrop
    let shape: TileShape
    /// The symbol that flies out of a merge.
    let spark: String

    static let all: [Skin] = [
        Skin(id: "neon", name: "Neon", blurb: "The classic glow", unlock: .free,
             chromeHue: nil, chromeBrightness: 1, tiles: .original,
             backdrop: .grid, shape: .rounded, spark: "sparkle"),
        Skin(id: "sunset", name: "Sunset", blurb: "A striped sun going down", unlock: .gems(15),
             chromeHue: 0.92, chromeBrightness: 1.05, tiles: .shifted(0.04),
             backdrop: .sun, shape: .rounded, spark: "sun.max.fill"),
        Skin(id: "ocean", name: "Ocean", blurb: "Bubble tiles under the sea", unlock: .gems(30),
             chromeHue: 0.53, chromeBrightness: 0.95, tiles: .band(from: 0.42, to: 0.66),
             backdrop: .bubbles, shape: .bubble, spark: "drop.fill"),
        Skin(id: "bubblegum", name: "Bubblegum", blurb: "Jelly tiles and floating hearts", unlock: .gems(50),
             chromeHue: 0.84, chromeBrightness: 1.25, tiles: .pastel,
             backdrop: .hearts, shape: .jelly, spark: "heart.fill"),
        Skin(id: "lava", name: "Lava", blurb: "Hot tiles and flying sparks", unlock: .gems(80),
             chromeHue: 0.02, chromeBrightness: 0.8, tiles: .band(from: 0.93, to: 1.13),
             backdrop: .embers, shape: .hex, spark: "flame.fill"),
        Skin(id: "frost", name: "Frost", blurb: "Ice crystals in falling snow", unlock: .gems(120),
             chromeHue: 0.58, chromeBrightness: 1.15, tiles: .icy,
             backdrop: .snow, shape: .crystal, spark: "snowflake"),
        Skin(id: "gold", name: "Gold Rush", blurb: "Cut gems in a shower of gold", unlock: .score(2000),
             chromeHue: 0.09, chromeBrightness: 0.9, tiles: .band(from: 0.02, to: 0.16),
             backdrop: .coins, shape: .gem, spark: "diamond.fill"),
        Skin(id: "party", name: "Party Lights", blurb: "Sweeping coloured lights", unlock: .level(7),
             chromeHue: 0.8, chromeBrightness: 0.75, tiles: .shifted(0.25),
             backdrop: .lights, shape: .jelly, spark: "sparkles"),
        Skin(id: "galaxy", name: "Galaxy", blurb: "Planet tiles and shooting stars", unlock: .megaCombo,
             chromeHue: 0.76, chromeBrightness: 0.7, tiles: .shifted(0.5),
             backdrop: .stars, shape: .orb, spark: "star.fill"),
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
        case .level(let level): return "Reach level \(level) in one game"
        }
    }

    /// The few words on the lock of a theme that has to be won.
    var lockLabel: String {
        switch unlock {
        case .free, .gems: return ""
        case .score(let score): return "Score \(score.formatted())"
        case .megaCombo: return "4-tile merge"
        case .level(let level): return "Level \(level)"
        }
    }
}
