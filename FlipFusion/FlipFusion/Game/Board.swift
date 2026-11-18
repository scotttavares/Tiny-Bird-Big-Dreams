import Foundation

/// A swipe direction.
enum Direction: Sendable, CaseIterable {
    case up, down, left, right
}

/// One numbered tile. Row 0 is the top row, column 0 is the left column.
struct Tile: Identifiable, Equatable, Codable, Sendable {
    let id: Int
    var value: Int
    var row: Int
    var col: Int
}

/// A board position.
struct Cell: Hashable, Sendable {
    var row: Int
    var col: Int
}

/// What one slide (or one gravity pass) did to the board.
struct StepResult: Equatable, Sendable {
    /// The tiles left on the board, at their new positions.
    var tiles: [Tile]
    /// Tiles that were merged away, placed where the tile that absorbed them ended up,
    /// so the screen can slide them in before they disappear.
    var ghosts: [Tile]
    /// Ids of the surviving tiles that doubled.
    var mergedIDs: Set<Int>
    /// Ids of the tiles that were merged away.
    var removedIDs: Set<Int>
    /// Points earned.
    var gained: Int
    /// False when nothing moved and nothing merged.
    var changed: Bool
}

/// Everything needed to save and restore a game.
struct GameState: Equatable, Codable, Sendable {
    var tiles: [Tile]
    var score: Int
    var movesUntilRotation: Int
    var nextID: Int
}
