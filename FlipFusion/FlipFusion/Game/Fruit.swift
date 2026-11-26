import Foundation

/// Pictures that stand in for a tile's number. The Fruit Salad game shows a fruit
/// on each tile; every world of the adventure after the first shows its own set.
/// Two of the same picture merge into the next one along, exactly as two equal
/// numbers do.
enum Fruit {
    /// The fruit for 2, 4, 8 and so on up to 2,048, which is a star.
    static let faces = ["\u{1F352}", "\u{1F353}", "\u{1F34A}", "\u{1F34B}", "\u{1F34F}", "\u{1F347}", "\u{1F349}", "\u{1F34D}", "\u{1F965}", "\u{1F351}", "\u{2B50}"]

    /// Each world's own pictures, under the id of the world's theme, for 2 up to 2,048.
    static let themed: [String: [String]] = [
        "sunset": ["🐚", "🌴", "🍹", "🏄", "🌺", "🦩", "🐬", "🍍", "⛵", "🌅", "⭐"],
        "ocean": ["🐟", "🐠", "🦀", "🐡", "🦑", "🐙", "🐢", "🐬", "🦈", "🐳", "🔱"],
        "bubblegum": ["🍬", "🍭", "🍩", "🧁", "🍪", "🍫", "🍰", "🍦", "🎂", "🍮", "👑"],
        "rainforest": ["🍃", "🌿", "🐸", "🦜", "🐍", "🦋", "🐒", "🐆", "🦍", "🐘", "🌳"],
        "lava": ["🔥", "🧨", "💣", "🦎", "🌋", "⚡", "👹", "🐉", "💥", "🐲", "👑"],
        "jurassic": ["🥚", "🦴", "🌿", "🦎", "🐊", "🦕", "🦖", "🌋", "🐾", "💀", "🏆"],
        "frost": ["🧊", "⛄", "🐧", "🧤", "🧣", "🎿", "🐺", "🦌", "🐻", "🗻", "💎"],
        "gold": ["🪙", "💰", "🔑", "💍", "🏺", "🥇", "🏆", "👑", "💎", "🌟", "⭐"],
        "party": ["🎈", "🎉", "🎁", "🎂", "🎵", "🎤", "🥳", "🍾", "🎆", "🪩", "🌟"],
        "galaxy": ["⭐", "🌙", "🌍", "🪐", "🚀", "🛸", "👽", "🌠", "🌌", "🌞", "🌟"],
    ]

    /// The picture a tile of this value shows: a world's own when `theme` names one,
    /// otherwise a fruit. Anything past the last picture shows the last.
    static func face(for value: Int, theme: String? = nil) -> String {
        let set = theme.flatMap { themed[$0] } ?? faces
        let place = max(0, max(2, value).trailingZeroBitCount - 1)
        return set[min(place, set.count - 1)]
    }
}
