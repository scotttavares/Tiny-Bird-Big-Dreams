import Foundation

/// A swipe direction.
enum Direction: Sendable, CaseIterable {
    case up, down, left, right
}

/// What is special about a tile. A special tile is an ordinary number tile that also
/// does something when it merges.
enum TileKind: String, Codable, Sendable {
    case normal
    /// Adds time to the clock when it merges.
    case time
    /// Clears the tiles around it when it merges.
    case bomb
    /// A stone block: it slides and falls like any tile but never merges. Only a
    /// bomb's blast or the Sweep booster gets rid of it.
    case stone
}

/// One numbered tile. Row 0 is the top row, column 0 is the left column.
struct Tile: Identifiable, Equatable, Codable, Sendable {
    let id: Int
    var value: Int
    var row: Int
    var col: Int
    var kind: TileKind = .normal

    enum CodingKeys: String, CodingKey {
        case id, value, row, col, kind
    }
}

extension Tile {
    /// Games saved before special tiles existed have no `kind`.
    init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(Int.self, forKey: .id)
        value = try box.decode(Int.self, forKey: .value)
        row = try box.decode(Int.self, forKey: .row)
        col = try box.decode(Int.self, forKey: .col)
        kind = try box.decodeIfPresent(TileKind.self, forKey: .kind) ?? .normal
    }
}

/// Something a special tile did during a slide, at the cell where it merged.
struct TileEffect: Equatable, Sendable {
    var kind: TileKind
    var row: Int
    var col: Int
}

/// A board position.
struct Cell: Hashable, Sendable {
    var row: Int
    var col: Int
}

/// What kind of obstacle a blocked cell is. No tile can enter any of them.
enum BlockKind: String, Codable, Sendable {
    /// A solid block standing on the board.
    case wall
    /// A gap cut out of the board.
    case hole
    /// A wooden crate: a merge beside it, or a bomb's blast, smashes it.
    case crate
}

/// One cell of the board that tiles cannot enter. Blocks turn with the board.
struct Block: Hashable, Codable, Sendable {
    var row: Int
    var col: Int
    var kind: BlockKind

    var cell: Cell { Cell(row: row, col: col) }
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
    /// What the special tiles that merged in this step did.
    var effects: [TileEffect] = []
    /// Super combos: the id of each surviving tile that three or four tiles merged
    /// into, and how many.
    var supers: [Int: Int] = [:]
}

/// Everything needed to save and restore a game.
struct GameState: Equatable, Codable, Sendable {
    var tiles: [Tile]
    var score: Int
    var movesUntilRotation: Int
    var nextID: Int
    /// The obstacles on the board, where they are now (they turn with the board).
    var blocks: [Block] = []
    /// Which of `GameEngine.layouts` the board was last shaped to. 0 is the open board.
    var shapeID: Int = 0
    /// Shape Shift game only: moves left before the board changes shape.
    var movesUntilShift: Int = GameEngine.movesPerShift

    enum CodingKeys: String, CodingKey {
        case tiles, score, movesUntilRotation, nextID, blocks, shapeID, movesUntilShift
    }
}

extension GameState {
    /// Games saved before board shapes existed have no blocks.
    init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        tiles = try box.decode([Tile].self, forKey: .tiles)
        score = try box.decode(Int.self, forKey: .score)
        movesUntilRotation = try box.decode(Int.self, forKey: .movesUntilRotation)
        nextID = try box.decode(Int.self, forKey: .nextID)
        blocks = try box.decodeIfPresent([Block].self, forKey: .blocks) ?? []
        shapeID = try box.decodeIfPresent(Int.self, forKey: .shapeID) ?? 0
        movesUntilShift = try box.decodeIfPresent(Int.self, forKey: .movesUntilShift) ?? GameEngine.movesPerShift
    }
}
