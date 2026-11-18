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

    @Test func theClockStartsOnTheFirstSwipe() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.secondsLeft == GameStore.roundSeconds)
        store.tick(5)
        #expect(store.secondsLeft == GameStore.roundSeconds)
        store.swipe(.left)
        store.tick(5)
        #expect(store.secondsLeft == GameStore.roundSeconds - 5)
        #expect(store.wholeSecondsLeft == Int(GameStore.roundSeconds) - 5)
    }

    @Test func runningOutOfTimeEndsTheGame() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        store.tick(GameStore.roundSeconds + 1)
        #expect(store.secondsLeft == 0)
        #expect(store.isTimeUp)
        #expect(store.isGameOver)
        let after = store.state
        store.swipe(.right)
        #expect(store.state == after)
        // Still over after a relaunch, until a new game starts.
        #expect(GameStore(defaults: defaults, animated: false).isGameOver)
        store.newGame()
        #expect(!store.isGameOver)
        #expect(store.secondsLeft == GameStore.roundSeconds)
    }

    @Test func aPausedClockKeepsItsTimeAcrossARelaunch() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        store.tick(30)
        store.pauseTimer()
        store.tick(30)
        #expect(store.secondsLeft == GameStore.roundSeconds - 30)
        let relaunched = GameStore(defaults: defaults, animated: false)
        #expect(relaunched.secondsLeft == GameStore.roundSeconds - 30)
        #expect(!relaunched.isTimerRunning)
    }

    @Test func aMergeLeavesABurstAndAScorePop() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[8, 8, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        #expect(store.bursts.count == 1)
        #expect(store.bursts.first?.value == 16)
        #expect(store.lastMergeValue == 16)
        #expect(store.lastGain == 16)
        #expect(store.gainEvent == 1)
    }

    @Test func aClockTileAddsTime() {
        let defaults = freshDefaults()
        var start = tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        start[0].kind = .time
        save(GameState(tiles: start, score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(50.0, forKey: "ff.time")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.secondsLeft == 50)
        store.swipe(.left)
        #expect(store.secondsLeft == 50 + GameStore.timeBonus)
        #expect(store.timeBonusEvent == 1)
    }

    @Test func aBombScoresWhatItClears() {
        let defaults = freshDefaults()
        var start = tiles([[2, 2, 0, 0], [8, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        start[1].kind = .bomb
        save(GameState(tiles: start, score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        #expect(store.state.score == 4 + 8)
        #expect(store.bombEvent == 1)
        #expect(store.bursts.contains { $0.isBlast })
        #expect(!store.state.tiles.contains { $0.value == 8 })
    }

    @Test func aChainStartsDoublePointsForAWhile() {
        let defaults = freshDefaults()
        // One move from a rotation. Swiping up lifts this row to the top; the quarter
        // turn stands it up as the right-hand column (2, 2, 4, 16 from the top), and
        // gravity then merges 2+2 and, in a second pass, 4+4: a chain of two.
        let start = tiles([[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [2, 2, 4, 16]])
        save(GameState(tiles: start, score: 0, movesUntilRotation: 1, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.up)
        #expect(store.lastCombo == 2)
        #expect(store.isFever)
        store.tick(GameStore.feverSeconds + 1)
        #expect(!store.isFever)
    }

    @Test func aChainIsRewardedWithAPowerUpTile() {
        let defaults = freshDefaults()
        let start = tiles([[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [2, 2, 4, 16]])
        save(GameState(tiles: start, score: 0, movesUntilRotation: 1, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.up)
        #expect(store.lastCombo == 2)
        #expect(store.state.tiles.contains { $0.kind != .normal })
        #expect(store.specialSpawnEvent >= 1)
        #expect(store.feverEvent == 1)
    }

    @Test func eachModeKeepsItsOwnGameAndBestScore() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[4, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.mode == .timed)
        store.swipe(.left)
        let timedGame = store.state
        #expect(store.best == 8)

        store.switchMode(.endless)
        #expect(store.mode == .endless)
        #expect(store.state.score == 0)
        #expect(store.best == 0)
        #expect(store.state.tiles.count == 2)
        #expect(!store.isTimerRunning)

        // The mode is remembered, and so is the timed game left behind.
        let relaunched = GameStore(defaults: defaults, animated: false)
        #expect(relaunched.mode == .endless)
        relaunched.switchMode(.timed)
        #expect(relaunched.state == timedGame)
        #expect(relaunched.best == 8)
    }

    @Test func theEndlessGameHasNoClockAndGetsAnExtraTileAfterARotation() {
        let defaults = freshDefaults()
        defaults.set("endless", forKey: "ff.mode")
        // One lone tile, one move from a rotation: nothing can merge.
        defaults.set(
            try! JSONEncoder().encode(GameState(tiles: tiles([[0, 8, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 1, nextID: 10)),
            forKey: "ff.endless.state"
        )
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.mode == .endless)
        store.swipe(.left)
        // The 8, the usual new tile, and the endless game's extra one.
        #expect(store.state.tiles.count == 3)
        #expect(!store.state.tiles.contains { $0.kind == .time })
        store.tick(GameStore.roundSeconds * 3)
        #expect(!store.isGameOver)
        #expect(!store.isTimeUp)
    }

    @Test func quickMergesBuildASpeedStreakThatFadesAndEarnCoins() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 4, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)          // 2+2: the first merge, at x1
        #expect(store.streak == 0)
        #expect(store.state.score == 4)
        store.swipe(.left)          // 4+4 straight after: the streak begins, at x2
        #expect(store.streak == 1)
        #expect(store.state.score >= 4 + 16)
        #expect(store.coins >= 1)
        store.tick(GameStore.streakWindow + 1)
        #expect(store.streak == 0)
    }

    @Test func theFlipBoosterTurnsTheBoardWithoutUsingAMove() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[8, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.boosterCounts[.flip] == GameStore.freeBoosters)
        #expect(store.useBooster(.flip))
        #expect(store.boosterCounts[.flip] == GameStore.freeBoosters - 1)
        #expect(store.rotatePulse == 1)
        #expect(store.state.movesUntilRotation == 2)
        // Top-left goes to top-right, then falls to the bottom-right corner.
        #expect(store.state.tiles.first?.row == 3)
        #expect(store.state.tiles.first?.col == 3)
        // The free uses are remembered.
        #expect(GameStore(defaults: defaults, animated: false).boosterCounts[.flip] == GameStore.freeBoosters - 1)
    }

    @Test func theSweepBoosterClearsTwosAndFours() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 4, 8, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.useBooster(.sweep))
        #expect(store.lastSweepCount == 2)
        #expect(store.state.score == 6)
        #expect(store.state.tiles.contains { $0.value == 8 })
        // The board is topped back up to two tiles.
        #expect(store.state.tiles.count == 2)

        // With nothing small to clear, the booster is not used up.
        let other = freshDefaults()
        save(GameState(tiles: tiles([[8, 16, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: other)
        let untouched = GameStore(defaults: other, animated: false)
        #expect(!untouched.useBooster(.sweep))
        #expect(untouched.boosterCounts[.sweep] == GameStore.freeBoosters)
        #expect(untouched.boosterDeniedEvent == 1)
    }

    @Test func aBoosterCostsCoinsOnceTheFreeUsesAreGone() {
        let defaults = freshDefaults()
        defaults.set(0, forKey: "ff.booster.fever")
        defaults.set(250, forKey: "ff.coins")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.useBooster(.fever))
        #expect(store.isFever)
        #expect(store.coins == 250 - GameStore.Booster.fever.price)
        // 50 coins left: not enough for another.
        #expect(!store.useBooster(.fever))
        #expect(store.coins == 50)
        #expect(store.boosterDeniedEvent == 1)
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
