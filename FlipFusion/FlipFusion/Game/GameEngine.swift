import Foundation

/// The rules of Flip Fusion. Pure functions, no UI.
enum GameEngine {
    static let size = 4
    static let movesPerRotation = 2

    // MARK: Sliding

    /// Slides every tile as far as it goes in `dir`. Equal tiles that meet merge, and the
    /// result doubles for each tile that joins: two 2s make a 4, three make an 8 and four
    /// make a 16 (a "super combo"). The tile they make does not merge again in that slide.
    /// No tile enters a `blocked` cell: tiles stop beside it and do not merge across it.
    static func slide(_ tiles: [Tile], _ dir: Direction, blocked: Set<Cell> = []) -> StepResult {
        var kept: [Tile] = []
        var ghosts: [Tile] = []
        var mergedIDs: Set<Int> = []
        var removedIDs: Set<Int> = []
        var gained = 0
        var changed = false
        var effects: [TileEffect] = []
        var supers: [Int: Int] = [:]

        for line in 0..<size {
            // The tiles of this line, nearest the wall they are sliding toward first.
            let lineTiles = tiles
                .filter { lineIndex(of: $0, dir) == line }
                .sorted { distanceFromWall(of: $0, dir) < distanceFromWall(of: $1, dir) }

            // How far along this line each blocked cell is, nearest the wall first.
            let stops = blocked
                .map { Tile(id: 0, value: 2, row: $0.row, col: $0.col) }
                .filter { lineIndex(of: $0, dir) == line }
                .map { distanceFromWall(of: $0, dir) }
                .sorted()
            var nextStop = 0
            // Where the next tile comes to rest.
            var nextDistance = 0

            var placed: [Tile] = []
            // The value of the tiles gathered into the last placed tile, and how many.
            var runValue = 0
            var runCount = 0

            for tile in lineTiles {
                // A blocked cell between this tile and the ones already placed: the
                // tile stops just short of it, and nothing merges across it.
                let from = distanceFromWall(of: tile, dir)
                while nextStop < stops.count, stops[nextStop] < from {
                    if stops[nextStop] >= nextDistance {
                        nextDistance = stops[nextStop] + 1
                        runCount = 0
                    }
                    nextStop += 1
                }
                if runCount > 0, tile.kind != .stone, let last = placed.last, runValue == tile.value {
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
                    runCount += 1
                    if runCount >= 3 {
                        supers[survivor.id] = runCount
                    }
                    changed = true
                } else {
                    let cell = cellFor(line: line, distance: nextDistance, dir)
                    nextDistance += 1
                    var moved = tile
                    if moved.row != cell.row || moved.col != cell.col {
                        changed = true
                    }
                    moved.row = cell.row
                    moved.col = cell.col
                    placed.append(moved)
                    runValue = tile.value
                    // Nothing merges into a stone block.
                    runCount = tile.kind == .stone ? 0 : 1
                }
            }
            kept.append(contentsOf: placed)
        }

        // Each bomb clears the eight cells around the cell it merged in. The cleared
        // tiles score their own value and are drawn until the slide ends. A bomb tile
        // caught in a blast goes off too: a chain reaction.
        var blasts = effects.filter { $0.kind == .bomb }
        var next = 0
        while next < blasts.count {
            let effect = blasts[next]
            next += 1
            let blasted = kept.filter { tile in
                abs(tile.row - effect.row) <= 1 && abs(tile.col - effect.col) <= 1
                    && !(tile.row == effect.row && tile.col == effect.col)
            }
            for tile in blasted {
                gained += tile.value
                removedIDs.insert(tile.id)
                mergedIDs.remove(tile.id)
                supers[tile.id] = nil
                ghosts.append(tile)
                if tile.kind == .bomb {
                    let chained = TileEffect(kind: .bomb, row: tile.row, col: tile.col)
                    effects.append(chained)
                    blasts.append(chained)
                }
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
            effects: effects,
            supers: supers
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
    static func rotateClockwise(_ blocks: [Block]) -> [Block] {
        blocks.map { block in
            Block(row: block.col, col: size - 1 - block.row, kind: block.kind)
        }
    }

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
    static func settle(_ tiles: [Tile], blocked: Set<Cell> = []) -> [StepResult] {
        var passes: [StepResult] = []
        var current = tiles
        // A pass can only repeat after a merge, and there are at most 15 merges on 16 cells.
        while passes.count < size * size {
            var pass = slide(current, .down, blocked: blocked)
            guard pass.changed else { break }
            pass.gained *= passes.count + 1
            passes.append(pass)
            current = pass.tiles
            if pass.mergedIDs.isEmpty { break }
        }
        return passes
    }

    // MARK: Spawning and game over

    static func emptyCells(_ tiles: [Tile], blocked: Set<Cell> = []) -> [Cell] {
        let taken = Set(tiles.map { Cell(row: $0.row, col: $0.col) })
        var cells: [Cell] = []
        for row in 0..<size {
            for col in 0..<size {
                let cell = Cell(row: row, col: col)
                if !taken.contains(cell), !blocked.contains(cell) {
                    cells.append(cell)
                }
            }
        }
        return cells
    }

    /// Out of every 100 new tiles, how many are clock tiles and how many are bombs.
    static let timeTilesPerHundred = 5
    static let bombTilesPerHundred = 12

    // MARK: Board shapes

    /// A board never has more obstacles than this.
    static let maxBlocks = 6
    /// In the Shape Shift game the board changes shape after this many moves.
    static let movesPerShift = 4

    private static func wall(_ row: Int, _ col: Int) -> Block { Block(row: row, col: col, kind: .wall) }
    private static func hole(_ row: Int, _ col: Int) -> Block { Block(row: row, col: col, kind: .hole) }
    private static func crate(_ row: Int, _ col: Int) -> Block { Block(row: row, col: col, kind: .crate) }

    /// Every board shape. The first is the open board; the rest are met one per
    /// level from level 2 (and round again), or at random in the Shape Shift game.
    static let layouts: [[Block]] = [
        [],
        [hole(0, 0)],
        [wall(1, 2)],
        [crate(1, 1), crate(2, 2)],
        [hole(0, 0), hole(3, 3)],
        [wall(1, 1), wall(2, 2)],
        [hole(0, 2), wall(2, 1)],
        [crate(0, 1), crate(3, 2), wall(1, 3)],
        [hole(0, 1), hole(0, 2)],
        [wall(1, 1), crate(1, 2)],
        [hole(0, 0), hole(0, 3), crate(2, 1)],
        [crate(1, 0), crate(2, 3), crate(0, 2)],
        [wall(2, 0), wall(1, 3)],
        [hole(3, 0), wall(1, 1), crate(2, 2)],
        [crate(1, 1), crate(1, 2), crate(2, 1)],
        // From here on, two boards for each theme, in the order of `Skin.all`.
        [hole(3, 0), hole(3, 3)],
        [wall(1, 1), hole(0, 3)],
        [hole(0, 0), hole(0, 3), hole(3, 0)],
        [crate(1, 1), crate(2, 2), hole(0, 3)],
        [crate(1, 1), crate(2, 1)],
        [crate(0, 0), crate(3, 3), crate(1, 2)],
        [wall(1, 1), wall(1, 2), hole(3, 0)],
        [wall(0, 1), wall(2, 2), crate(3, 0)],
        [wall(1, 1), wall(1, 2)],
        [hole(0, 0), wall(2, 2), wall(1, 3)],
        [crate(1, 1), crate(1, 2), crate(2, 2)],
        [crate(0, 3), crate(3, 0), wall(1, 1)],
        [hole(1, 0), hole(2, 3)],
        [wall(0, 0), crate(1, 2), hole(3, 2)],
        [hole(0, 0), hole(3, 3), wall(1, 2)],
        [wall(1, 1), crate(2, 2), crate(0, 3)],
        // From here on, the outlines of the Shape Shift game: holes that cut the
        // board itself into a new shape. In the order of `silhouetteNames`.
        [hole(0, 1), hole(0, 2), hole(0, 3), hole(1, 2), hole(1, 3), hole(2, 3)],
        [hole(0, 0), hole(0, 3), hole(3, 0), hole(3, 3)],
        [hole(1, 1), hole(1, 2), hole(2, 1), hole(2, 2)],
        [hole(0, 2), hole(0, 3), hole(1, 2), hole(1, 3)],
        [hole(1, 0), hole(2, 0), hole(3, 0), hole(1, 3), hole(2, 3), hole(3, 3)],
        [hole(0, 1), hole(0, 2), hole(1, 1), hole(1, 2)],
        [hole(1, 0), hole(2, 0), hole(1, 3), hole(2, 3)],
        [hole(0, 2), hole(0, 3), hole(1, 3), hole(2, 0), hole(3, 0), hole(3, 1)],
    ]

    /// Where the outlines of the Shape Shift game begin in `layouts`, and their names.
    static let firstSilhouette = 31
    static let silhouetteNames = ["Triangle", "Circle", "Ring", "Corner", "Tee", "Cup", "Beam", "Zigzag"]

    /// The name of an outline, or nil for any other shape.
    static func silhouetteName(_ shapeID: Int) -> String? {
        let place = shapeID - firstSilhouette
        return silhouetteNames.indices.contains(place) ? silhouetteNames[place] : nil
    }

    /// How many shapes everyone has, after the open board. The rest belong to themes.
    static let standardShapes = 14

    /// Which shape a level is played on: the open board on level 1, then the boards
    /// of the theme in use (`signature`), then each standard shape in turn, starting
    /// over when they run out.
    static func layoutIndex(forLevel level: Int, signature: [Int] = []) -> Int {
        guard level > 1 else { return 0 }
        let step = level - 2
        if step < signature.count {
            return signature[step]
        }
        return 1 + (step - signature.count) % standardShapes
    }

    /// The crates a slide smashes: any crate with a merge in the cell beside it
    /// (above, below, left or right), and any crate inside a bomb's blast.
    static func cratesBroken(by result: StepResult, blocks: [Block]) -> [Block] {
        let crates = blocks.filter { $0.kind == .crate }
        guard !crates.isEmpty else { return [] }
        let merged = result.tiles.filter { result.mergedIDs.contains($0.id) }
        return crates.filter { crate in
            let besideMerge = merged.contains { abs($0.row - crate.row) + abs($0.col - crate.col) == 1 }
            let inBlast = result.effects.contains {
                $0.kind == .bomb && abs($0.row - crate.row) <= 1 && abs($0.col - crate.col) <= 1
            }
            return besideMerge || inBlast
        }
    }

    // MARK: Levels

    /// The score at which a level begins: 0, 200, 500, 900, 1,400, 2,000 and so on,
    /// each level a little longer than the last.
    static func scoreNeeded(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return 50 * (level - 1) * (level + 2)
    }

    /// The level a score has reached. A game starts on level 1.
    static func level(forScore score: Int) -> Int {
        var level = 1
        while scoreNeeded(forLevel: level + 1) <= score {
            level += 1
        }
        return level
    }

    /// At most this many stone blocks sit on the board at once.
    static let maxStones = 3

    /// Out of every 100 new tiles, how many are stone blocks. None before level 3.
    static func stonesPerHundred(level: Int) -> Int {
        level < 3 ? 0 : min(14, 4 + 2 * (level - 3))
    }

    /// Out of every 100 moves, how many drop a second new tile. None before level 4.
    static func extraTilePerHundred(level: Int) -> Int {
        level < 4 ? 0 : min(40, 10 * (level - 3))
    }

    /// Adds a new tile (a 2 nine times in ten, otherwise a 4) in a random empty cell.
    /// Now and then it is a clock tile or a bomb, and from level 3 a stone block.
    /// Returns nil when the board is full. `allowTime: false` turns would-be clock
    /// tiles into ordinary ones; `forcedKind` makes the new tile that kind whatever
    /// the dice say.
    @discardableResult
    static func spawn<R: RandomNumberGenerator>(
        in state: inout GameState,
        using rng: inout R,
        allowTime: Bool = true,
        forcedKind: TileKind? = nil,
        stonesPerHundred: Int = 0
    ) -> Tile? {
        let empty = emptyCells(state.tiles, blocked: Set(state.blocks.map(\.cell)))
        guard let cell = empty.randomElement(using: &rng) else { return nil }
        let value = Int.random(in: 0..<10, using: &rng) == 0 ? 4 : 2
        let roll = Int.random(in: 0..<100, using: &rng)
        var kind = TileKind.normal
        if roll < timeTilesPerHundred {
            kind = allowTime ? .time : .normal
        } else if roll < timeTilesPerHundred + bombTilesPerHundred {
            kind = .bomb
        } else if roll < timeTilesPerHundred + bombTilesPerHundred + stonesPerHundred,
                  state.tiles.filter({ $0.kind == .stone }).count < maxStones {
            kind = .stone
        }
        if let forcedKind {
            kind = forcedKind
        }
        // A stone block counts as a 2 when it is blasted or swept away.
        let tile = Tile(id: state.nextID, value: kind == .stone ? 2 : value, row: cell.row, col: cell.col, kind: kind)
        state.nextID += 1
        state.tiles.append(tile)
        return tile
    }

    /// True while some swipe would change the board.
    static func hasMove(_ tiles: [Tile], blocked: Set<Cell> = []) -> Bool {
        if tiles.count < size * size - blocked.count { return true }
        // Stone blocks never merge, so they are left out.
        var values: [Cell: Int] = [:]
        for tile in tiles where tile.kind != .stone {
            values[Cell(row: tile.row, col: tile.col)] = tile.value
        }
        for tile in tiles where tile.kind != .stone {
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
        guard state.blocks.count <= maxBlocks else { return false }
        for block in state.blocks {
            guard (0..<size).contains(block.row), (0..<size).contains(block.col) else { return false }
            // No two blocks, and no block and tile, share a cell.
            guard cells.insert(block.cell).inserted else { return false }
        }
        return true
    }
}
