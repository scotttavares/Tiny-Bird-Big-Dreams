import Foundation

/// A theme: its own colours, its own moving backdrop, its own tile shape and its own
/// sparks. A theme is won by reaching its world on the adventure map. The
/// colours are worked out in `Theme`, the backdrop is drawn by `SceneView` and the
/// tile shape by `TileOutline`.
struct Skin: Identifiable, Equatable, Sendable {
    /// How a theme is come by.
    enum Unlock: Equatable, Sendable {
        /// Everyone has it from the start.
        case free
        /// Won by reaching this world of the adventure map (2 is the second world).
        /// This is the only way a theme is come by now; the ways below are no
        /// longer given to any theme.
        case world(Int)
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
        /// Fireflies drifting through the trees.
        case fireflies
        /// Glowing ash drifting up from a far volcano.
        case ash
    }

    /// The outline of every tile.
    enum TileShape: Equatable, Sendable {
        /// A square with rounded corners.
        case rounded
        /// A dark rounded square lit by a glowing tube round its edge.
        case neon
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
    /// The theme's own board shapes (places in `GameEngine.layouts`). With the theme
    /// on, levels 2 and 3 are played on them, and the Shape Shift game deals them too.
    let boards: [Int]

    /// Every theme but the free one brings its own boards and bigger effects.
    var isPremium: Bool { unlock != .free }

    static let all: [Skin] = [
        Skin(id: "neon", name: "Neon", blurb: "80s arcade nights", unlock: .free,
             chromeHue: nil, chromeBrightness: 1, tiles: .original,
             backdrop: .grid, shape: .neon, spark: "sparkle", boards: []),
        Skin(id: "sunset", name: "Sunset", blurb: "A striped sun going down", unlock: .world(2),
             chromeHue: 0.92, chromeBrightness: 1.05, tiles: .shifted(0.04),
             backdrop: .sun, shape: .rounded, spark: "sun.max.fill", boards: [15, 16]),
        Skin(id: "ocean", name: "Ocean", blurb: "Fish, bubbles and a shark that scatters your tiles", unlock: .world(3),
             chromeHue: 0.53, chromeBrightness: 0.95, tiles: .band(from: 0.42, to: 0.66),
             backdrop: .bubbles, shape: .bubble, spark: "drop.fill", boards: [17, 18]),
        Skin(id: "bubblegum", name: "Bubblegum", blurb: "Jelly tiles and floating hearts", unlock: .world(4),
             chromeHue: 0.84, chromeBrightness: 1.25, tiles: .pastel,
             backdrop: .hearts, shape: .jelly, spark: "heart.fill", boards: [19, 20]),
        Skin(id: "rainforest", name: "Rainforest", blurb: "Fireflies, a downpour and a monkey in the crates", unlock: .world(5),
             chromeHue: 0.4, chromeBrightness: 0.85, tiles: .band(from: 0.2, to: 0.46),
             backdrop: .fireflies, shape: .rounded, spark: "leaf.fill", boards: [31, 32]),
        Skin(id: "lava", name: "Lava", blurb: "Hot tiles and flying sparks", unlock: .world(6),
             chromeHue: 0.02, chromeBrightness: 0.8, tiles: .band(from: 0.93, to: 1.13),
             backdrop: .embers, shape: .hex, spark: "flame.fill", boards: [21, 22]),
        Skin(id: "jurassic", name: "Jurassic", blurb: "A lost valley, falling stars and a T-rex in the crates", unlock: .world(7),
             chromeHue: 0.07, chromeBrightness: 0.8, tiles: .band(from: 0.04, to: 0.3),
             backdrop: .ash, shape: .gem, spark: "pawprint.fill", boards: [33, 34]),
        Skin(id: "frost", name: "Frost", blurb: "Ice crystals in falling snow", unlock: .world(8),
             chromeHue: 0.58, chromeBrightness: 1.15, tiles: .icy,
             backdrop: .snow, shape: .crystal, spark: "snowflake", boards: [23, 24]),
        Skin(id: "gold", name: "Gold Rush", blurb: "Cut gems in a shower of gold", unlock: .world(9),
             chromeHue: 0.09, chromeBrightness: 0.9, tiles: .band(from: 0.02, to: 0.16),
             backdrop: .coins, shape: .gem, spark: "diamond.fill", boards: [25, 26]),
        Skin(id: "party", name: "Party Lights", blurb: "Sweeping coloured lights", unlock: .world(10),
             chromeHue: 0.8, chromeBrightness: 0.75, tiles: .shifted(0.25),
             backdrop: .lights, shape: .jelly, spark: "sparkles", boards: [27, 28]),
        Skin(id: "galaxy", name: "Galaxy", blurb: "Planet tiles and shooting stars", unlock: .world(11),
             chromeHue: 0.76, chromeBrightness: 0.7, tiles: .shifted(0.5),
             backdrop: .stars, shape: .orb, spark: "star.fill", boards: [29, 30]),
    ]

    /// The look the game was first drawn in: glossy tiles on plain navy. The opening
    /// animation always uses it. It is not a theme the player can pick.
    static let classic = Skin(
        id: "classic", name: "Classic", blurb: "", unlock: .free,
        chromeHue: nil, chromeBrightness: 1, tiles: .original,
        backdrop: .grid, shape: .rounded, spark: "circle.fill", boards: []
    )

    /// What a stone block is made of in a theme.
    enum StoneLook: Equatable, Sendable {
        case rock, sandstone, coral, candy, magma, ice, nugget, mirror, moon
    }

    var stone: StoneLook {
        switch id {
        case "sunset": return .sandstone
        case "ocean": return .coral
        case "bubblegum": return .candy
        case "lava": return .magma
        case "frost": return .ice
        case "gold": return .nugget
        case "party": return .mirror
        case "galaxy": return .moon
        case "jurassic": return .sandstone
        default: return .rock
        }
    }

    /// The word sprayed across the card when a game ends.
    var overWord: String {
        switch id {
        case "sunset": return "Sundown!"
        case "ocean": return "Wipeout!"
        case "bubblegum": return "Pop!"
        case "lava": return "Burned!"
        case "frost": return "Frozen!"
        case "gold": return "Busted!"
        case "party": return "Lights out!"
        case "galaxy": return "Lost in space!"
        case "rainforest": return "Lost in the jungle!"
        case "jurassic": return "Extinct!"
        default: return "Game over, dude!"
        }
    }

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
        case .world(let world): return "Reach world \(world) on the map"
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
        case .world(let world): return "World \(world)"
        case .score(let score): return "Score \(score.formatted())"
        case .megaCombo: return "4-tile merge"
        case .level(let level): return "Level \(level)"
        }
    }
}
