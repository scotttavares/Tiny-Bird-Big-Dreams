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

    @Test func aTileMergesOnlyOncePerSlide() {
        let result = GameEngine.slide(tiles([[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), .left)
        #expect(grid(result.tiles)[0] == [4, 4, 0, 0])
        #expect(result.gained == 8)
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
            #expect(settled.map(\.value).reduce(0, +) == total)
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
}
