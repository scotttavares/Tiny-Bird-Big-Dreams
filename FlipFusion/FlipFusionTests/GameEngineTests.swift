import Foundation
import Testing
@testable import FlipFusion

/// A repeatable random source for tests.
struct SeededGenerator: RandomNumberGenerator {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return seed
    }
}

/// Builds tiles from a grid of values (0 = empty), top row first.
func tiles(_ grid: [[Int]]) -> [Tile] {
    var result: [Tile] = []
    var id = 1
    for (row, values) in grid.enumerated() {
        for (col, value) in values.enumerated() where value != 0 {
            result.append(Tile(id: id, value: value, row: row, col: col))
            id += 1
        }
    }
    return result
}

/// Turns tiles back into a grid of values.
func grid(_ tiles: [Tile]) -> [[Int]] {
    var result = Array(repeating: Array(repeating: 0, count: GameEngine.size), count: GameEngine.size)
    for tile in tiles {
        result[tile.row][tile.col] = tile.value
    }
    return result
}

struct GameEngineTests {
    @Test func slideLeftMergesAPairAndPacksTheRest() {
        let result = GameEngine.slide(tiles([[2, 2, 4, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .left)
        #expect(grid(result.tiles)[0] == [4, 4, 0, 0])
        #expect(result.gained == 4)
        #expect(result.changed)
        #expect(result.mergedIDs.count == 1)
        #expect(result.removedIDs.count == 1)
        #expect(result.ghosts.count == 1)
    }

    @Test func threeEqualTilesMergeAtOnce() {
        let result = GameEngine.slide(tiles([[2, 2, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .left)
        #expect(grid(result.tiles)[0] == [8, 0, 0, 0])
        // 2+2 scores 4, and the third tile doubles it again for 8 more.
        #expect(result.gained == 12)
        #expect(result.supers.values.sorted() == [3])
        #expect(result.ghosts.count == 2)
    }

    @Test func fourEqualTilesMakeOneBigTile() {
        let result = GameEngine.slide(tiles([[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .left)
        #expect(grid(result.tiles)[0] == [16, 0, 0, 0])
        #expect(result.gained == 4 + 8 + 16)
        #expect(result.supers.values.sorted() == [4])
    }

    @Test func aMergedTileDoesNotMergeAgainInTheSameSlide() {
        // The 4 made from the two 2s does not go on to merge with the 4 beside it.
        let result = GameEngine.slide(tiles([[2, 2, 4, 4], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .left)
        #expect(grid(result.tiles)[0] == [4, 8, 0, 0])
        #expect(result.gained == 12)
        #expect(result.supers.isEmpty)
        let other = GameEngine.slide(tiles([[4, 2, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .left)
        #expect(grid(other.tiles)[0] == [4, 4, 0, 0])
    }

    @Test func aBombCaughtInABlastGoesOffToo() {
        var start = tiles([[2, 2, 0, 0], [8, 0, 0, 0], [0, 16, 0, 0], [0, 0, 0, 0]])
        start[0].kind = .bomb
        start[2].kind = .bomb
        let result = GameEngine.slide(start, .left)
        // The first bomb merges in the corner and catches the bomb 8 below it. That one
        // goes off in turn, taking the new 4 above it and the 16 below it.
        #expect(result.tiles.isEmpty)
        #expect(result.effects.count == 2)
        #expect(result.gained == 4 + 8 + 4 + 16)
    }

    @Test func slideRightAndUpAndDown() {
        let start = tiles([[2, 0, 0, 2], [0, 4, 0, 0], [0, 4, 0, 0], [8, 0, 0, 0]])
        #expect(grid(GameEngine.slide(start, .right).tiles) == [[0, 0, 0, 4], [0, 0, 0, 4], [0, 0, 0, 4], [0, 0, 0, 8]])
        #expect(grid(GameEngine.slide(start, .up).tiles) == [[2, 8, 0, 2], [8, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        #expect(grid(GameEngine.slide(start, .down).tiles) == [[0, 0, 0, 0], [0, 0, 0, 0], [2, 0, 0, 0], [8, 8, 0, 2]])
    }

    @Test func aSlideThatChangesNothingSaysSo() {
        let start = tiles([[2, 4, 0, 0], [8, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        let result = GameEngine.slide(start, .left)
        #expect(!result.changed)
        #expect(result.gained == 0)
        #expect(grid(result.tiles) == grid(start))
    }

    @Test func rotationIsAQuarterTurnClockwise() {
        let turned = GameEngine.rotateClockwise(tiles([[2, 0, 0, 4], [0, 0, 0, 0], [0, 0, 0, 0], [8, 0, 0, 0]]))
        // top-left → top-right, top-right → bottom-right, bottom-left → top-left
        #expect(grid(turned) == [[8, 0, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 4]])
    }

    @Test func gravityChainsMergesAndScoresTheChain() {
        let passes = GameEngine.settle(tiles([[2, 0, 0, 0], [2, 0, 0, 0], [4, 0, 0, 0], [0, 0, 0, 0]]))
        #expect(passes.count == 2)
        #expect(grid(passes[1].tiles) == [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [8, 0, 0, 0]])
        // First pass: 2+2 = 4, worth 4. Second pass: 4+4 = 8, worth double.
        #expect(passes.map(\.gained) == [4, 16])
    }

    @Test func gravityOnASettledBoardDoesNothing() {
        #expect(GameEngine.settle(tiles([[0, 0, 0, 0], [0, 0, 0, 0], [2, 0, 0, 0], [4, 8, 0, 0]])).isEmpty)
    }

    @Test func rotatingAFullBoardKeepsEveryTile() {
        let full = tiles([[2, 4, 8, 16], [32, 64, 128, 256], [512, 1024, 2048, 4096], [8192, 16384, 32768, 65536]])
        let turned = GameEngine.rotateClockwise(full)
        #expect(turned.count == 16)
        #expect(Set(turned.map { Cell(row: $0.row, col: $0.col) }).count == 16)
        #expect(turned.map(\.value).reduce(0, +) == full.map(\.value).reduce(0, +))
        #expect(GameEngine.settle(turned).isEmpty)
    }

    @Test func rotationThenGravityNeverLosesValue() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<200 {
            var state = GameState(tiles: [], score: 0, movesUntilRotation: 2, nextID: 1)
            let count = Int.random(in: 1...16, using: &rng)
            for _ in 0..<count {
                GameEngine.spawn(in: &state, using: &rng)
            }
            // Ordinary tiles only: a bomb is meant to remove value.
            state.tiles = state.tiles.map { tile in
                var plain = tile
                plain.kind = .normal
                return plain
            }
            let total = state.tiles.map(\.value).reduce(0, +)
            let turned = GameEngine.rotateClockwise(state.tiles)
            let settled = GameEngine.settle(turned).last?.tiles ?? turned
            // A super combo adds value; nothing ever takes it away.
            #expect(settled.map(\.value).reduce(0, +) >= total)
            #expect(Set(settled.map { Cell(row: $0.row, col: $0.col) }).count == settled.count)
            // Nothing floats: every tile rests on the floor or on another tile.
            let cells = Set(settled.map { Cell(row: $0.row, col: $0.col) })
            for tile in settled where tile.row < GameEngine.size - 1 {
                #expect(cells.contains(Cell(row: tile.row + 1, col: tile.col)))
            }
        }
    }

    @Test func aClockTileReportsItsMergeAndTurnsOrdinary() {
        var start = tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        start[1].kind = .time
        let result = GameEngine.slide(start, .left)
        #expect(result.effects == [TileEffect(kind: .time, row: 0, col: 0)])
        #expect(result.tiles.count == 1)
        #expect(result.tiles.first?.kind == .normal)
        #expect(result.gained == 4)
    }

    @Test func aBombClearsTheTilesAroundIt() {
        var start = tiles([[2, 2, 0, 32], [8, 16, 0, 0], [0, 0, 64, 0], [0, 0, 0, 0]])
        start[0].kind = .bomb
        let result = GameEngine.slide(start, .left)
        // The bomb merges in the top-left corner. The 32 slides in beside it, and the 8
        // and 16 sit below it: all three are cleared. The 64, two rows down, is out of reach.
        #expect(grid(result.tiles) == [[4, 0, 0, 0], [0, 0, 0, 0], [64, 0, 0, 0], [0, 0, 0, 0]])
        #expect(result.gained == 4 + 32 + 8 + 16)
        #expect(result.effects == [TileEffect(kind: .bomb, row: 0, col: 0)])
        // One tile merged away plus three cleared.
        #expect(result.ghosts.count == 4)
    }

    @Test func gamesSavedBeforeSpecialTilesStillLoad() throws {
        let old = Data(#"{"tiles":[{"id":1,"value":2,"row":0,"col":0}],"score":8,"movesUntilRotation":2,"nextID":2}"#.utf8)
        let state = try JSONDecoder().decode(GameState.self, from: old)
        #expect(state.tiles.first?.kind == .normal)
        #expect(GameEngine.isValid(state))
    }

    @Test func hasMoveKnowsADeadBoard() {
        let dead = tiles([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]])
        #expect(!GameEngine.hasMove(dead))
        let alive = tiles([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 4]])
        #expect(GameEngine.hasMove(alive))
        #expect(GameEngine.hasMove(tiles([[2, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])))
    }

    @Test func spawnFillsAnEmptyCellAndStopsWhenFull() {
        var rng = SeededGenerator(seed: 1)
        var state = GameState(tiles: [], score: 0, movesUntilRotation: 2, nextID: 1)
        for _ in 0..<16 {
            let tile = GameEngine.spawn(in: &state, using: &rng)
            #expect(tile != nil)
            #expect(tile?.value == 2 || tile?.value == 4)
        }
        #expect(Set(state.tiles.map { Cell(row: $0.row, col: $0.col) }).count == 16)
        #expect(Set(state.tiles.map(\.id)).count == 16)
        let extra = GameEngine.spawn(in: &state, using: &rng)
        #expect(extra == nil)
    }

    @Test func aStoneBlockSlidesButNeverMerges() {
        var start = tiles([[0, 2, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        start[0].kind = .stone
        let result = GameEngine.slide(start, .left)
        // The stone and the 2 pack up side by side; they do not become a 4.
        #expect(grid(result.tiles)[0] == [2, 2, 0, 0])
        #expect(result.changed)
        #expect(result.mergedIDs.isEmpty)
        #expect(result.gained == 0)
        #expect(result.tiles.contains { $0.kind == .stone })

        // A stone between two equal tiles keeps them apart.
        var blocked = tiles([[2, 2, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        blocked[1].kind = .stone
        let stuck = GameEngine.slide(blocked, .left)
        #expect(!stuck.changed)
        #expect(stuck.gained == 0)
    }

    @Test func aBombBlastsAStoneBlockAway() {
        var start = tiles([[2, 2, 0, 0], [2, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        start[0].kind = .bomb
        start[2].kind = .stone
        let result = GameEngine.slide(start, .left)
        #expect(!result.tiles.contains { $0.kind == .stone })
        #expect(grid(result.tiles)[0] == [4, 0, 0, 0])
    }

    @Test func aStoneBlockIsNotAMove() {
        // A dead board. Turning a 4 into a stone (which counts as a 2) next to 2s
        // must not make it look as if something could merge.
        var dead = tiles([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]])
        dead[1].kind = .stone
        dead[1].value = 2
        #expect(!GameEngine.hasMove(dead))
    }

    @Test func levelsStartAtRisingScores() {
        #expect(GameEngine.level(forScore: 0) == 1)
        #expect(GameEngine.level(forScore: 199) == 1)
        #expect(GameEngine.level(forScore: 200) == 2)
        #expect(GameEngine.level(forScore: 499) == 2)
        #expect(GameEngine.level(forScore: 500) == 3)
        #expect(GameEngine.level(forScore: 2000) == 6)
        #expect(GameEngine.scoreNeeded(forLevel: 1) == 0)
        #expect(GameEngine.scoreNeeded(forLevel: 7) == 2700)
    }

    @Test func theGameGetsHarderWithTheLevel() {
        #expect(GameEngine.stonesPerHundred(level: 1) == 0)
        #expect(GameEngine.stonesPerHundred(level: 3) == 8)
        #expect(GameEngine.stonesPerHundred(level: 30) == 18)
        #expect(GameEngine.extraTilePerHundred(level: 1) == 0)
        #expect(GameEngine.extraTilePerHundred(level: 4) == 36)
        #expect(GameEngine.extraTilePerHundred(level: 30) == 60)
    }

    @Test func thereAreNeverTooManyStoneBlocks() {
        var rng = SeededGenerator(seed: 5)
        var state = GameState(tiles: [], score: 0, movesUntilRotation: 2, nextID: 1)
        for _ in 0..<16 {
            GameEngine.spawn(in: &state, using: &rng, stonesPerHundred: 100)
        }
        let stones = state.tiles.filter { $0.kind == .stone }
        #expect(stones.count == GameEngine.maxStones)
        #expect(stones.allSatisfy { $0.value == 2 })
        #expect(GameEngine.isValid(state))
    }

    @Test func tilesStopBesideABlockedCell() {
        let wall: Set<Cell> = [Cell(row: 0, col: 1)]
        let stopped = GameEngine.slide(tiles([[0, 0, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .left, blocked: wall)
        #expect(grid(stopped.tiles)[0] == [0, 0, 2, 0])
        #expect(stopped.changed)

        // Equal tiles either side of it do not merge.
        let apart = GameEngine.slide(tiles([[2, 0, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .left, blocked: wall)
        #expect(!apart.changed)
        #expect(apart.gained == 0)

        // Tiles on the same side of it still merge, against it.
        let merged = GameEngine.slide(tiles([[0, 0, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .left, blocked: wall)
        #expect(grid(merged.tiles)[0] == [0, 0, 4, 0])
        #expect(merged.gained == 4)

        // Sliding the other way, the block is in nobody's way.
        let free = GameEngine.slide(tiles([[0, 0, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .right, blocked: wall)
        #expect(grid(free.tiles)[0] == [0, 0, 0, 4])
    }

    @Test func gravityRestsATileOnABlockedCell() {
        let passes = GameEngine.settle(
            tiles([[2, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]),
            blocked: [Cell(row: 2, col: 0)]
        )
        #expect(passes.count == 1)
        #expect(passes.last?.tiles.first?.row == 1)
        #expect(passes.last?.tiles.first?.col == 0)
    }

    @Test func blocksTurnWithTheBoard() {
        let turned = GameEngine.rotateClockwise([Block(row: 0, col: 0, kind: .wall), Block(row: 1, col: 2, kind: .crate)])
        #expect(turned == [Block(row: 0, col: 3, kind: .wall), Block(row: 2, col: 2, kind: .crate)])
    }

    @Test func aTurnToTheLeftUndoesATurnToTheRight() {
        let start = tiles([[2, 4, 0, 0], [0, 8, 0, 0], [0, 0, 0, 16], [32, 0, 0, 0]])
        let there = GameEngine.rotateClockwise(start)
        #expect(GameEngine.rotateCounterClockwise(there) == start)
        // The top-right cell goes to the top-left.
        let turned = GameEngine.rotateCounterClockwise([Tile(id: 1, value: 2, row: 0, col: 3)])
        #expect(turned[0].row == 0)
        #expect(turned[0].col == 0)
        let blocks = [Block(row: 0, col: 3, kind: .wall), Block(row: 2, col: 1, kind: .crate)]
        #expect(GameEngine.rotateCounterClockwise(GameEngine.rotateClockwise(blocks)) == blocks)
    }

    @Test func aBlockedCellCountsAsFull() {
        var almostDead = tiles([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]])
        almostDead.removeFirst()
        // With the corner open there is room to move; with a hole there, there is not.
        #expect(GameEngine.hasMove(almostDead))
        #expect(!GameEngine.hasMove(almostDead, blocked: [Cell(row: 0, col: 0)]))
        #expect(GameEngine.emptyCells(almostDead, blocked: [Cell(row: 0, col: 0)]).isEmpty)
    }

    @Test func newTilesNeverLandOnABlock() {
        var rng = SeededGenerator(seed: 9)
        var state = GameState(tiles: [], score: 0, movesUntilRotation: 2, nextID: 1)
        state.blocks = [Block(row: 0, col: 0, kind: .wall), Block(row: 1, col: 1, kind: .hole)]
        for _ in 0..<14 {
            #expect(GameEngine.spawn(in: &state, using: &rng) != nil)
        }
        #expect(GameEngine.spawn(in: &state, using: &rng) == nil)
        #expect(!state.tiles.contains { ($0.row == 0 && $0.col == 0) || ($0.row == 1 && $0.col == 1) })
        #expect(GameEngine.isValid(state))

        var broken = state
        broken.tiles[0].row = 0
        broken.tiles[0].col = 0
        #expect(!GameEngine.isValid(broken))
    }

    @Test func everyBoardShapeIsSound() {
        #expect(GameEngine.layouts.count == 39)
        #expect(Set(GameEngine.layouts).count == 39)
        // The outlines of the Shape Shift game: all holes, each leaving room to play.
        #expect(GameEngine.firstSilhouette + GameEngine.silhouetteNames.count == GameEngine.layouts.count)
        #expect(GameEngine.silhouetteName(GameEngine.firstSilhouette) == "Triangle")
        #expect(GameEngine.silhouetteName(3) == nil)
        for outline in GameEngine.layouts[GameEngine.firstSilhouette...] {
            #expect(outline.allSatisfy { $0.kind == .hole })
            #expect(outline.count >= 4)
        }
        // With a theme's two boards, levels 2 and 3 use them and the rest follow.
        #expect(GameEngine.layoutIndex(forLevel: 1, signature: [15, 16]) == 0)
        #expect(GameEngine.layoutIndex(forLevel: 2, signature: [15, 16]) == 15)
        #expect(GameEngine.layoutIndex(forLevel: 3, signature: [15, 16]) == 16)
        #expect(GameEngine.layoutIndex(forLevel: 4, signature: [15, 16]) == 1)
        #expect(GameEngine.layouts[0].isEmpty)
        for layout in GameEngine.layouts.dropFirst() {
            #expect(!layout.isEmpty)
            #expect(layout.count <= GameEngine.maxBlocks)
            #expect(Set(layout.map(\.cell)).count == layout.count)
            #expect(layout.allSatisfy { (0..<4).contains($0.row) && (0..<4).contains($0.col) })
        }
        #expect(GameEngine.layoutIndex(forLevel: 1) == 0)
        #expect(GameEngine.layoutIndex(forLevel: 2) == 1)
        #expect(GameEngine.layoutIndex(forLevel: 15) == 14)
        #expect(GameEngine.layoutIndex(forLevel: 16) == 1)
    }

    @Test func aMergeBesideACrateSmashesIt() {
        let result = GameEngine.slide(tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .left)
        let below = Block(row: 1, col: 0, kind: .crate)
        let diagonal = Block(row: 1, col: 1, kind: .crate)
        let wall = Block(row: 0, col: 1, kind: .wall)
        // The merge is in the top-left corner: only the crate straight below it goes.
        #expect(GameEngine.cratesBroken(by: result, blocks: [below, diagonal, wall]) == [below])

        var armed = tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        armed[0].kind = .bomb
        let blast = GameEngine.slide(armed, .left)
        // A bomb's blast reaches the diagonal one too.
        #expect(GameEngine.cratesBroken(by: blast, blocks: [below, diagonal, wall]) == [below, diagonal])
    }

    @Test func aGameSavedBeforeBoardShapesStillOpens() throws {
        let old = #"{"tiles":[{"id":1,"value":2,"row":0,"col":0}],"score":8,"movesUntilRotation":2,"nextID":2}"#
        let state = try JSONDecoder().decode(GameState.self, from: Data(old.utf8))
        #expect(state.blocks.isEmpty)
        #expect(state.shapeID == 0)
        #expect(state.movesUntilShift == GameEngine.movesPerShift)
        #expect(GameEngine.isValid(state))
    }

    @Test func aNewGameStartsWithTwoTiles() {
        var rng = SeededGenerator(seed: 3)
        let state = GameEngine.newGame(using: &rng)
        #expect(state.tiles.count == 2)
        #expect(state.score == 0)
        #expect(state.movesUntilRotation == 2)
        #expect(GameEngine.isValid(state))
    }

    @Test func brokenSavesAreRejected() {
        var overlapping = GameState(tiles: tiles([[2, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 9)
        overlapping.tiles.append(Tile(id: 5, value: 2, row: 0, col: 0))
        #expect(!GameEngine.isValid(overlapping))
        let outOfRange = GameState(tiles: [Tile(id: 1, value: 2, row: 4, col: 0)], score: 0, movesUntilRotation: 2, nextID: 2)
        #expect(!GameEngine.isValid(outOfRange))
        let oddValue = GameState(tiles: [Tile(id: 1, value: 3, row: 0, col: 0)], score: 0, movesUntilRotation: 2, nextID: 2)
        #expect(!GameEngine.isValid(oddValue))
        let badCounter = GameState(tiles: [Tile(id: 1, value: 2, row: 0, col: 0)], score: 0, movesUntilRotation: 0, nextID: 2)
        #expect(!GameEngine.isValid(badCounter))
    }

    @Test func aHoleSwallowsTheFirstTileToReachIt() {
        // Row 0: a hole at the left end, then a 2, a gap and a 4. Swiping left drops
        // the 2 down the hole; the 4 stops beside it.
        let row = [Tile(id: 1, value: 2, row: 0, col: 1), Tile(id: 2, value: 4, row: 0, col: 3)]
        let hole = Cell(row: 0, col: 0)
        let result = GameEngine.slide(row, .left, blocked: [hole], holes: [hole])
        #expect(result.changed)
        #expect(result.gained == 0)
        #expect(result.swallowed.map(\.id) == [1])
        #expect(result.removedIDs == [1])
        #expect(result.tiles.count == 1)
        #expect(result.tiles[0].id == 2)
        #expect(result.tiles[0].col == 1)

        // A plain blocked cell swallows nothing.
        let plain = GameEngine.slide(row, .left, blocked: [hole])
        #expect(plain.swallowed.isEmpty)
        #expect(plain.tiles.count == 2)

        // A full board has a move while a tile stands beside a hole.
        let lone = [Tile(id: 1, value: 2, row: 0, col: 1)]
        #expect(GameEngine.hasMove(lone, blocked: [hole], holes: [hole]))
    }
}
