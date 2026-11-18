import Foundation

/// The rules of Flip Fusion. Pure functions, no UI.
enum GameEngine {
    static let size = 4
    static let movesPerRotation = 2

    // MARK: Sliding

    /// Slides every tile as far as it goes in `dir`. Two equal tiles that meet merge into
    /// their sum, and a tile merges at most once per slide.
    static func slide(_ tiles: [Tile], _ dir: Direction) -> StepResult {
        var kept: [Tile] = []
        var ghosts: [Tile] = []
        var mergedIDs: Set<Int> = []
        var removedIDs: Set<Int> = []
        var gained = 0
        var changed = false
        var effects: [TileEffect] = []

        for line in 0..<size {
            // The tiles of this line, nearest the wall they are sliding toward first.
            let lineTiles = tiles
                .filter { lineIndex(of: $0, dir) == line }
                .sorted { distanceFromWall(of: $0, dir) < distanceFromWall(of: $1, dir) }

            var placed: [Tile] = []
            var lastCanMerge = false

            for tile in lineTiles {
                if lastCanMerge, let last = placed.last, last.value == tile.value {
                    var survivor = last
                    survivor.value *= 2
                    // A special tile does its thing when it merges; the result is ordinary.
                    for kind in [last.kind, tile.kind] where kind != .normal {
                        effects.append(TileEffect(kind: kind, row: survivor.row, col: survivor.col))
                    }
                    survivor.kind = .normal
                    placed[placed.count - 1] = survivor
                    mergedIDs.insert(survivor.id)
                    removedIDs.insert(tile.id)
                    gained += survivor.value
                    var ghost = tile
                    ghost.row = survivor.row
                    ghost.col = survivor.col
                    ghosts.append(ghost)
                    lastCanMerge = false
                    changed = true
                } else {
                    let cell = cellFor(line: line, distance: placed.count, dir)
                    var moved = tile
                    if moved.row != cell.row || moved.col != cell.col {
                        changed = true
                    }
                    moved.row = cell.row
                    moved.col = cell.col
                    placed.append(moved)
                    lastCanMerge = true
                }
            }
            kept.append(contentsOf: placed)
        }

        // Each bomb clears the eight cells around the cell it merged in. The cleared
        // tiles score their own value and are drawn until the slide ends.
        for effect in effects where effect.kind == .bomb {
            let blasted = kept.filter { tile in
                abs(tile.row - effect.row) <= 1 && abs(tile.col - effect.col) <= 1
                    && !(tile.row == effect.row && tile.col == effect.col)
            }
            for tile in blasted {
                gained += tile.value
                removedIDs.insert(tile.id)
                mergedIDs.remove(tile.id)
                ghosts.append(tile)
            }
            let blastedIDs = Set(blasted.map(\.id))
            kept.removeAll { blastedIDs.contains($0.id) }
        }

        return StepResult(
            tiles: kept,
            ghosts: ghosts,
            mergedIDs: mergedIDs,
            removedIDs: removedIDs,
            gained: gained,
            changed: changed,
            effects: effects
        )
    }

    private static func lineIndex(of tile: Tile, _ dir: Direction) -> Int {
        switch dir {
        case .left, .right: return tile.row
        case .up, .down: return tile.col
        }
    }

    private static func distanceFromWall(of tile: Tile, _ dir: Direction) -> Int {
        switch dir {
        case .left: return tile.col
        case .right: return size - 1 - tile.col
        case .up: return tile.row
        case .down: return size - 1 - tile.row
        }
    }

    private static func cellFor(line: Int, distance: Int, _ dir: Direction) -> Cell {
        switch dir {
        case .left: return Cell(row: line, col: distance)
        case .right: return Cell(row: line, col: size - 1 - distance)
        case .up: return Cell(row: distance, col: line)
        case .down: return Cell(row: size - 1 - distance, col: line)
        }
    }

    // MARK: Rotation and gravity

    /// Turns the board a quarter turn clockwise: the top-left cell becomes the top-right cell.
    static func rotateClockwise(_ tiles: [Tile]) -> [Tile] {
        tiles.map { tile in
            var turned = tile
            turned.row = tile.col
            turned.col = size - 1 - tile.row
            return turned
        }
    }

    /// Lets gravity pull the tiles down, pass after pass, until nothing more merges.
    /// Each returned pass changed the board. Merges in pass N score N times their value,
    /// so a chain reaction is worth more than the same merges made one at a time.
    static func settle(_ tiles: [Tile]) -> [StepResult] {
        var passes: [StepResult] = []
        var current = tiles
        // A pass can only repeat after a merge, and there are at most 15 merges on 16 cells.
        while passes.count < size * size {
            var pass = slide(current, .down)
            guard pass.changed else { break }
            pass.gained *= passes.count + 1
            passes.append(pass)
            current = pass.tiles
            if pass.mergedIDs.isEmpty { break }
        }
        return passes
    }

    // MARK: Spawning and game over

    static func emptyCells(_ tiles: [Tile]) -> [Cell] {
        let taken = Set(tiles.map { Cell(row: $0.row, col: $0.col) })
        var cells: [Cell] = []
        for row in 0..<size {
            for col in 0..<size {
                let cell = Cell(row: row, col: col)
                if !taken.contains(cell) {
                    cells.append(cell)
                }
            }
        }
        return cells
    }

    /// Out of every 100 new tiles, how many are clock tiles and how many are bombs.
    static let timeTilesPerHundred = 4
    static let bombTilesPerHundred = 5

    /// Adds a new tile (a 2 nine times in ten, otherwise a 4) in a random empty cell.
    /// Now and then it is a clock tile or a bomb. Returns nil when the board is full.
    @discardableResult
    static func spawn<R: RandomNumberGenerator>(in state: inout GameState, using rng: inout R) -> Tile? {
        let empty = emptyCells(state.tiles)
        guard let cell = empty.randomElement(using: &rng) else { return nil }
        let value = Int.random(in: 0..<10, using: &rng) == 0 ? 4 : 2
        let roll = Int.random(in: 0..<100, using: &rng)
        var kind = TileKind.normal
        if roll < timeTilesPerHundred {
            kind = .time
        } else if roll < timeTilesPerHundred + bombTilesPerHundred {
            kind = .bomb
        }
        let tile = Tile(id: state.nextID, value: value, row: cell.row, col: cell.col, kind: kind)
        state.nextID += 1
        state.tiles.append(tile)
        return tile
    }

    /// True while some swipe would change the board.
    static func hasMove(_ tiles: [Tile]) -> Bool {
        if tiles.count < size * size { return true }
        var values: [Cell: Int] = [:]
        for tile in tiles {
            values[Cell(row: tile.row, col: tile.col)] = tile.value
        }
        for tile in tiles {
            if values[Cell(row: tile.row, col: tile.col + 1)] == tile.value { return true }
            if values[Cell(row: tile.row + 1, col: tile.col)] == tile.value { return true }
        }
        return false
    }

    static func newGame<R: RandomNumberGenerator>(using rng: inout R) -> GameState {
        var state = GameState(tiles: [], score: 0, movesUntilRotation: movesPerRotation, nextID: 1)
        spawn(in: &state, using: &rng)
        spawn(in: &state, using: &rng)
        return state
    }

    /// Checks a restored game before it is trusted.
    static func isValid(_ state: GameState) -> Bool {
        guard state.score >= 0,
              (1...movesPerRotation).contains(state.movesUntilRotation),
              !state.tiles.isEmpty,
              state.tiles.count <= size * size
        else { return false }
        var cells: Set<Cell> = []
        var ids: Set<Int> = []
        for tile in state.tiles {
            guard (0..<size).contains(tile.row), (0..<size).contains(tile.col) else { return false }
            // Every tile is a power of two, from 2 up.
            guard tile.value >= 2, tile.value & (tile.value - 1) == 0 else { return false }
            guard tile.id < state.nextID else { return false }
            guard cells.insert(Cell(row: tile.row, col: tile.col)).inserted else { return false }
            guard ids.insert(tile.id).inserted else { return false }
        }
        return true
    }
}
