import Foundation
import Testing
@testable import FlipFusion

@MainActor
struct GameStoreTests {
    /// A private, empty settings store for one test.
    private func freshDefaults() -> UserDefaults {
        let name = "flipfusion.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func save(_ state: GameState, to defaults: UserDefaults) {
        defaults.set(try! JSONEncoder().encode(state), forKey: "ff.state")
    }

    @Test func startsANewGameWhenNothingIsSaved() {
        let store = GameStore(defaults: freshDefaults(), animated: false)
        #expect(store.state.tiles.count == 2)
        #expect(store.state.score == 0)
        #expect(store.state.movesUntilRotation == 2)
        #expect(store.best == 0)
        #expect(!store.isGameOver)
    }

    @Test func aSwipeThatChangesNothingIsNotAMove() {
        let defaults = freshDefaults()
        let start = GameState(tiles: tiles([[2, 4, 0, 0], [8, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 12, movesUntilRotation: 2, nextID: 10)
        save(start, to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        #expect(store.state == start)
    }

    @Test func aMoveScoresSpawnsAndCountsDown() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        #expect(store.state.score == 4)
        #expect(store.best == 4)
        #expect(store.state.tiles.count == 2)      // the merged 4 and one new tile
        #expect(store.state.movesUntilRotation == 1)
        #expect(store.hasMergedOnce)
        #expect(store.ghosts.isEmpty)
    }

    @Test func theBoardRotatesAfterTheSecondMove() {
        let defaults = freshDefaults()
        // One move from a rotation. Swiping left keeps the 8 in the top-left corner;
        // the quarter turn then carries it to the top-right, and gravity drops it
        // down the right-hand column.
        save(GameState(tiles: tiles([[0, 8, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 1, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        #expect(store.state.movesUntilRotation == 2)
        #expect(store.boardAngle == 0)
        #expect(store.state.tiles.count == 2)
        let eight = store.state.tiles.first { $0.value >= 8 }
        #expect(eight?.col == 3)
        // Gravity has run: nothing floats.
        let cells = Set(store.state.tiles.map { Cell(row: $0.row, col: $0.col) })
        for tile in store.state.tiles where tile.row < GameEngine.size - 1 {
            #expect(cells.contains(Cell(row: tile.row + 1, col: tile.col)))
        }
    }

    @Test func bestScoreAndTheGameSurviveARelaunch() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[4, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let first = GameStore(defaults: defaults, animated: false)
        first.swipe(.left)
        let second = GameStore(defaults: defaults, animated: false)
        #expect(second.state == first.state)
        #expect(second.best == 8)
        second.newGame()
        #expect(second.state.score == 0)
        #expect(second.best == 8)
        #expect(GameStore(defaults: defaults, animated: false).best == 8)
    }

    @Test func aCorruptSaveStartsANewGame() {
        let defaults = freshDefaults()
        defaults.set(Data("not a game".utf8), forKey: "ff.state")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.state.tiles.count == 2)
        #expect(store.state.score == 0)
    }

    @Test func anImpossibleSaveStartsANewGame() {
        let defaults = freshDefaults()
        save(GameState(tiles: [Tile(id: 1, value: 2, row: 9, col: 9)], score: 50, movesUntilRotation: 2, nextID: 2), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.state.score == 0)
        #expect(GameEngine.isValid(store.state))
    }

    @Test func aDeadBoardIsGameOverAndIgnoresSwipes() {
        let defaults = freshDefaults()
        let dead = GameState(tiles: tiles([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]]), score: 100, movesUntilRotation: 1, nextID: 20)
        save(dead, to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.isGameOver)
        store.swipe(.left)
        #expect(store.state == dead)
        store.newGame()
        #expect(!store.isGameOver)
        #expect(store.state.tiles.count == 2)
    }
}
