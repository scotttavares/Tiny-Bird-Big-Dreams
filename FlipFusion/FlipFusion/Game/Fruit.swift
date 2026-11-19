import Foundation

/// The Fruit Salad game shows a fruit on each tile in place of its number. Two of
/// the same fruit merge into the next one along, exactly as two equal numbers do.
enum Fruit {
    /// The fruit for 2, 4, 8 and so on up to 2,048, which is a star.
    static let faces = ["\u{1F352}", "\u{1F353}", "\u{1F34A}", "\u{1F34B}", "\u{1F34F}", "\u{1F347}", "\u{1F349}", "\u{1F34D}", "\u{1F965}", "\u{1F351}", "\u{2B50}"]

    /// The fruit a tile of this value shows. Anything past the last fruit is a star.
    static func face(for value: Int) -> String {
        let place = max(0, max(2, value).trailingZeroBitCount - 1)
        return faces[min(place, faces.count - 1)]
    }
}
