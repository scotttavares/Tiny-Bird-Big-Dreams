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

    @Test func anEmptyBoardIsDealtNewTilesOnASwipe() {
        let defaults = freshDefaults()
        save(GameState(tiles: [], score: 40, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        #expect(!store.state.tiles.isEmpty)
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
        // The endless game opens at stage 5.
        defaults.set(5, forKey: "ff.stage")
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
        defaults.set(5, forKey: "ff.stage")
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
        #expect(store.coins == store.state.score / GameStore.pointsPerCoin)
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

    @Test func aSuperComboWinsAGemAndShakesTheBoard() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        #expect(store.state.score == 12)
        #expect(store.superEvent == 1)
        #expect(store.lastSuperCount == 3)
        #expect(store.gems == GameStore.gemsForSuper)
        #expect(store.shakeEvent == 1)
        #expect(store.shakePower == 2)
        #expect(store.flashEvent == 1)
        #expect(store.bursts.contains { $0.isSuper })
        // Gems are remembered.
        #expect(GameStore(defaults: defaults, animated: false).gems == GameStore.gemsForSuper)
    }

    @Test func aMegaComboUnlocksTheGalaxyTheme() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[4, 4, 4, 4], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        let galaxy = Skin.named("galaxy")
        #expect(!store.owns(galaxy))
        store.swipe(.left)
        #expect(store.lastSuperCount == 4)
        #expect(store.gems == GameStore.gemsForMega)
        #expect(store.owns(galaxy))
        #expect(store.unlockEvent == 1)
        #expect(GameStore(defaults: defaults, animated: false).owns(galaxy))
    }

    @Test func aThemeIsBoughtWithGems() {
        let defaults = freshDefaults()
        defaults.set(45, forKey: "ff.gems")
        let store = GameStore(defaults: defaults, animated: false)
        let sunset = Skin.named("sunset")
        // No theme yet, so no Shape Shift game.
        #expect(!store.isUnlocked(.shift))
        store.switchMode(.shift)
        #expect(store.mode == .timed)
        #expect(store.owns(Skin.named("neon")))
        #expect(!store.owns(sunset))
        #expect(store.buy(sunset))
        #expect(store.gems == 5)
        #expect(store.owns(sunset))
        // Not twice, not without the gems, and not a theme that has to be won.
        #expect(!store.buy(sunset))
        #expect(!store.buy(Skin.named("ocean")))
        #expect(!store.buy(Skin.named("gold")))
        #expect(store.gems == 5)
        #expect(GameStore(defaults: defaults, animated: false).owns(sunset))
    }

    @Test func aBigScoreUnlocksTheGoldTheme() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[8, 8, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 1990, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        let gold = Skin.named("gold")
        #expect(!store.owns(gold))
        store.swipe(.left)
        #expect(store.state.score == 2006)
        #expect(store.owns(gold))
        #expect(store.lastUnlockedSkin == "Gold Rush")
    }

    @Test func theBombsBoosterArmsThreeTiles() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 4, 8, 16], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.useBooster(.arm))
        #expect(store.state.tiles.filter { $0.kind == .bomb }.count == GameStore.armedTiles)
        #expect(store.lastArmCount == GameStore.armedTiles)
        #expect(store.boosterCounts[.arm] == GameStore.freeBoosters - 1)
        #expect(store.state.movesUntilRotation == 2)
    }

    @Test func aFinishedGamePaysGemsOnce() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 996, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(5000, forKey: "ff.best")
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        #expect(store.state.score == 1000)
        #expect(store.gems == 0)
        store.tick(GameStore.roundSeconds + 1)
        #expect(store.isGameOver)
        // 1,000 points is two gems; no new best, so nothing more.
        #expect(store.gems == 1000 / GameStore.pointsPerGem)
        store.tick(5)
        #expect(store.gems == 1000 / GameStore.pointsPerGem)
    }

    @Test func boughtGemsAreAddedOncePerPurchase() {
        let defaults = freshDefaults()
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.addPurchasedGems(25, purchaseID: "1001"))
        #expect(store.gems == 25)
        // The App Store can report the same purchase again; it must not pay twice.
        #expect(!store.addPurchasedGems(25, purchaseID: "1001"))
        #expect(store.gems == 25)
        #expect(store.addPurchasedGems(60, purchaseID: "1002"))
        #expect(store.gems == 85)
        let relaunched = GameStore(defaults: defaults, animated: false)
        #expect(relaunched.gems == 85)
        #expect(!relaunched.addPurchasedGems(25, purchaseID: "1001"))
    }

    @Test func everyGemPackHasItsOwnIdAndSomeGems() {
        #expect(Set(GemShop.packs.map(\.id)).count == GemShop.packs.count)
        #expect(GemShop.packs.allSatisfy { $0.gems > 0 })
        #expect(GemShop.pack(for: "not.a.pack") == nil)
    }

    @Test func aNewLevelAddsTimeAndWinsAPrize() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 196, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(60.0, forKey: "ff.time")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.level == 1)
        #expect(store.prizeEvent == 0)
        let before = store.coins + store.gems + store.boosterCounts.values.reduce(0, +)
        store.swipe(.left)
        #expect(store.state.score == 200)
        #expect(store.level == 2)
        #expect(store.levelEvent == 1)
        #expect(store.secondsLeft == 60 + GameStore.levelTimeBonus)
        // The reel stopped on coins, gems or a free booster.
        #expect(store.prizeEvent == 1)
        #expect(store.coins + store.gems + store.boosterCounts.values.reduce(0, +) > before)
        // The level comes back with the game.
        #expect(GameStore(defaults: defaults, animated: false).level == 2)
        store.newGame()
        #expect(store.level == 1)
    }

    @Test func reachingTheGoalClearsTheStageAndWinsLoot() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 246, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(90.0, forKey: "ff.time")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.stage == 1)
        #expect(store.stageGoal == 250)
        #expect(!store.isGameOver)
        store.swipe(.left)
        #expect(store.state.score == 250)
        #expect(store.isStageWon)
        #expect(store.isGameOver)
        #expect(!store.canContinue)
        #expect(store.stage == 2)
        #expect(store.stageEvent == 1)
        #expect(store.lastLoot.stage == 1)
        #expect(store.lastLoot.stars == 3)
        #expect(store.lastLoot.streak == 1)
        #expect(store.lastLoot.booster != nil)
        #expect(store.gems >= store.lastLoot.gems)
        #expect(store.coins >= store.lastLoot.coins)
        // Paid once, and the stage is remembered.
        let gems = store.gems
        store.tick(5)
        #expect(store.gems == gems)
        let relaunched = GameStore(defaults: defaults, animated: false)
        #expect(relaunched.stage == 2)
        #expect(relaunched.isGameOver)
        // The next stage starts from nothing, with a higher score to reach.
        store.newGame()
        #expect(!store.isGameOver)
        #expect(!store.isStageWon)
        #expect(store.state.score == 0)
        #expect(store.stageGoal == 750)
    }

    @Test func runningOutOfTimeKeepsTheStageAndEndsTheRun() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 100, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(3, forKey: "ff.stage")
        defaults.set(2, forKey: "ff.stage.streak")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.stage == 3)
        #expect(store.stageGoal == 1200)
        store.swipe(.down)
        store.tick(GameStore.roundSeconds + 1)
        #expect(store.isGameOver)
        #expect(!store.isStageWon)
        #expect(store.stage == 3)
        #expect(store.stageStreak == 0)
        #expect(store.stageEvent == 0)
    }

    @Test func laterStagesAskForMoreAndPayMore() {
        #expect(GameStore.stageGoal(1) == 250)
        #expect(GameStore.stageGoal(2) == 750)
        #expect(GameStore.stageGoal(5) == 2400)
        #expect(GameStore.stageLoot(1).coins == 45)
        #expect(GameStore.stageLoot(1).gems == 1)
        #expect(GameStore.stageLoot(4).gems == 2)
        #expect(!GameStore.stageLoot(4).isChest)
        #expect(GameStore.stageLoot(5).isChest)
        #expect(GameStore.stageLoot(5).coins == 210)
        #expect(GameStore.stageLoot(5).gems == 5)
        #expect(GameStore.stageStars(secondsLeft: 70) == 3)
        #expect(GameStore.stageStars(secondsLeft: 30) == 2)
        #expect(GameStore.stageStars(secondsLeft: 5) == 1)
    }

    @Test func stagesTakeTurnsWithGoals() {
        #expect(GameStore.goal(forStage: 1) == .score(250))
        #expect(GameStore.goal(forStage: 3) == .score(1200))
        #expect(GameStore.goal(forStage: 4) == .merges(24))
        #expect(GameStore.goal(forStage: 5) == .score(2400))
        #expect(GameStore.goal(forStage: 6) == .moves(score: 750, moves: 42))
        #expect(GameStore.goal(forStage: 7) == .chains(3))
        #expect(GameStore.goal(forStage: 9) == .tile(128))
        // A stage with no clock is never a sprint.
        #expect(GameStore.isMovesStage(14))
        #expect(GameStore.twist(forStage: 14) == .plain)
        #expect(GameStore.stageHint(1) != nil)
        #expect(GameStore.stageHint(4) == nil)
    }

    @Test func aMergeStageCountsMergesAndOpensTheEndlessGame() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(4, forKey: "ff.stage")
        defaults.set(23, forKey: "ff.stage.count")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(!store.isUnlocked(.endless))
        #expect(store.stageProgress == 23)
        #expect(store.stageTarget == 24)
        store.swipe(.left)
        #expect(store.isStageWon)
        #expect(store.isGameOver)
        #expect(store.stage == 5)
        #expect(store.playedStage == 4)
        #expect(store.lastLoot.opened != nil)
        #expect(store.isUnlocked(.endless))
        // The count starts again with the next stage.
        store.newGame()
        #expect(store.stageProgress == 0)
        #expect(store.playedStage == 5)
    }

    @Test func aTileStageIsClearedByMakingTheTile() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[64, 64, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(9, forKey: "ff.stage")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.playedGoal == .tile(128))
        #expect(!store.isStageWon)
        store.swipe(.left)
        #expect(store.isStageWon)
        #expect(store.stage == 10)
    }

    @Test func aMoveStageHasNoClockAndEndsWhenTheMovesRunOut() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 100, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(6, forKey: "ff.stage")
        defaults.set(2, forKey: "ff.stage.moves")
        defaults.set(GameStore.continueCost, forKey: "ff.gems")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(!store.hasClock)
        #expect(store.movesLeft == 2)
        store.swipe(.down)
        #expect(store.movesLeft == 1)
        // The clock does not run the game down.
        store.tick(GameStore.roundSeconds + 1)
        #expect(!store.isGameOver)
        store.swipe(.right)
        #expect(store.movesLeft == 0)
        #expect(store.isOutOfMoves)
        #expect(store.isGameOver)
        #expect(!store.isStageWon)
        #expect(store.stage == 6)
        // Carrying on gives more moves.
        #expect(store.continueGame())
        #expect(store.movesLeft == GameStore.continueMoves)
        #expect(!store.isGameOver)
        // A new game of the stage starts with all its moves.
        store.newGame()
        #expect(store.movesLeft == 42)
    }

    @Test func coinsBuyBoostersAndGems() {
        let defaults = freshDefaults()
        defaults.set(1000, forKey: "ff.coins")
        let store = GameStore(defaults: defaults, animated: false)
        let flips = store.boosterCounts[.flip] ?? 0
        #expect(store.buy(.flips))
        #expect(store.coins == 1000 - GameStore.Booster.flip.price * 2)
        #expect(store.boosterCounts[.flip] == flips + 3)
        #expect(store.buy(.gem))
        #expect(store.gems == 1)
        #expect(store.coins == 200)
        // Not enough left for anything more.
        #expect(!store.buy(.sweeps))
        #expect(store.coins == 200)
        #expect(GameStore(defaults: defaults, animated: false).boosterCounts[.flip] == flips + 3)
    }

    @Test func dailyQuestsCountPlayAndPayWhenCollected() {
        #expect(GameStore.quests(day: 0).map(\.kind) == [.merges, .chains, .stages])
        #expect(GameStore.quests(day: 1).map(\.kind) != GameStore.quests(day: 0).map(\.kind))
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(0, forKey: "ff.quest.day")
        defaults.set([59, 4, 2], forKey: "ff.quest.counts")
        let store = GameStore(defaults: defaults, animated: false)
        store.today = { 0 }
        #expect(store.questsWaiting == 2)
        // Nothing to collect on a quest that is not finished.
        #expect(!store.claimQuest(0))
        store.swipe(.left)
        #expect(store.questProgress[0] == 60)
        #expect(store.questEvent == 1)
        #expect(store.questsWaiting == 3)
        #expect(store.coins == 0)
        #expect(store.claimQuest(0))
        #expect(store.coins == 40)
        #expect(!store.claimQuest(0))
        #expect(store.claimQuest(1))
        #expect(store.claimQuest(2))
        // All three: the bonus and a gem.
        #expect(store.coins == 40 + 40 + 50 + GameStore.questBonus)
        #expect(store.gems == 1)
        #expect(store.questsWaiting == 0)
        // A new day starts the quests again.
        store.today = { 1 }
        #expect(store.questProgress == [0, 0, 0])
        #expect(store.questsWaiting == 0)
    }

    @Test func aChestStagePaysTheJarAndTheTimeLeft() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 2396, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(5, forKey: "ff.stage")
        defaults.set(80, forKey: "ff.jar")
        defaults.set(90.0, forKey: "ff.time")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.jar == 80)
        store.swipe(.left)
        #expect(store.isStageWon)
        #expect(store.lastLoot.isChest)
        #expect(store.lastLoot.jar == 80)
        #expect(store.lastLoot.bonus == 45)
        #expect(store.jar == 0)
        #expect(store.coins >= store.lastLoot.coins + 45 + 80)
    }

    @Test func aWinningRunStartsWithABombAndStarsOpenAChest() {
        #expect(GameStore.streakBombs(2) == 0)
        #expect(GameStore.streakBombs(3) == 1)
        #expect(GameStore.streakBombs(5) == 2)
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(4, forKey: "ff.stage")
        defaults.set(23, forKey: "ff.stage.count")
        defaults.set(2, forKey: "ff.stage.streak")
        defaults.set([3, 3, 3], forKey: "ff.stage.stars")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.starTotal == 9)
        #expect(store.nextStarMark == 10)
        store.swipe(.left)
        #expect(store.isStageWon)
        // Twelve stars: the first star chest.
        #expect(store.starTotal == 12)
        #expect(store.lastLoot.starCoins == 150)
        #expect(store.lastLoot.starGems == 3)
        #expect(store.nextStarMark == 25)
        // Three wins in a row: the next stage starts with a bomb.
        #expect(store.stageStreak == 3)
        store.newGame()
        // The two tiles a game starts with may be bombs too.
        #expect(store.state.tiles.filter { $0.kind == .bomb }.count >= 1)
        #expect(store.state.tiles.count == 3)
    }

    @Test func finishingAWorldUnlocksTheNextWorldsTheme() {
        #expect(GameStore.world(ofStage: 8) == 0)
        #expect(GameStore.world(ofStage: 9) == 1)
        #expect(GameStore.worldSkin(1) == "sunset")
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 3946, movesUntilRotation: 2, nextID: 10), to: defaults)
        // Stage 8, the last of the first world, is its boss: 3,950 points.
        defaults.set(8, forKey: "ff.stage")
        let store = GameStore(defaults: defaults, animated: false)
        let sunset = Skin.named("sunset")
        #expect(!store.owns(sunset))
        store.swipe(.left)
        #expect(store.isStageWon)
        #expect(store.stage == 9)
        #expect(store.owns(sunset))
        #expect(store.worldEvent == 1)
        #expect(store.lastWorldSkin == "sunset")
        // A player already deep in the map has every theme on the way.
        defaults.set(17, forKey: "ff.stage")
        let later = GameStore(defaults: defaults, animated: false)
        #expect(later.owns(sunset))
        #expect(later.owns(Skin.named("ocean")))
        #expect(!later.owns(Skin.named("bubblegum")))
    }

    @Test func theLastStageOfAWorldIsItsBoss() {
        #expect(GameStore.isBossStage(8))
        #expect(!GameStore.isBossStage(7))
        #expect(GameStore.goal(forStage: 8) == .score(3950))
        #expect(GameStore.twist(forStage: 8) == .plain)
        #expect(GameStore.boss(forStage: 24) == .shark)
        #expect(GameStore.bossMove(.shark) == .bite)
        #expect(GameStore.boss(forStage: 40) == .monkey)
        #expect(GameStore.bossMove(.monkey) == .steal)
        #expect(GameStore.bossWords(forStage: 7) == nil)
        #expect(GameStore.bossWords(forStage: 24) != nil)

        // The shark bites a hole out of the board after a few moves.
        let defaults = freshDefaults()
        defaults.set(24, forKey: "ff.stage")
        let store = GameStore(defaults: defaults, animated: false)
        store.newGame()
        #expect(store.isBossGame)
        let directions: [Direction] = [.left, .down, .right, .up]
        var tries = 0
        while store.bossEvent == 0, !store.isGameOver, tries < 80 {
            store.swipe(directions[tries % 4])
            tries += 1
        }
        #expect(store.bossEvent == 1)
        #expect(store.state.blocks.contains { $0.kind == .hole })
        #expect(GameEngine.isValid(store.state))
        #expect(!store.lastBossWords.isEmpty)
    }

    @Test func worldsAfterTheFirstShowPicturesForNumbers() {
        #expect(Fruit.face(for: 2, theme: "ocean") != Fruit.face(for: 2))
        #expect(Fruit.face(for: 4096, theme: "ocean") == Fruit.face(for: 2048, theme: "ocean"))
        #expect(Fruit.themed.values.allSatisfy { $0.count == 11 && Set($0).count == 11 })
        #expect(Set(Fruit.themed.keys) == Set(GameStore.worldSkins).subtracting(["neon"]))
        #expect(GameStore.tileName(128, stage: 5) == "128")
        #expect(GameStore.tileName(128, stage: 20) == Fruit.face(for: 128, theme: "ocean"))
        let defaults = freshDefaults()
        #expect(GameStore(defaults: defaults, animated: false).symbolTheme == nil)
        defaults.set(20, forKey: "ff.stage")
        #expect(GameStore(defaults: defaults, animated: false).symbolTheme == "ocean")
    }

    @Test func oneTileCanBeMovedOnItsOwn() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 4, 0, 8], [0, 0, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 20), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.singleMovesLeft == GameStore.freeSingleMoves)
        // No tile there, and a tile with nowhere to go: nothing is spent.
        #expect(!store.moveOne(row: 3, col: 0, .left))
        #expect(!store.moveOne(row: 0, col: 0, .left))
        #expect(store.singleMovesLeft == GameStore.freeSingleMoves)
        // The 8 slides left until it meets the 4; nothing else moves.
        #expect(store.moveOne(row: 0, col: 3, .left))
        #expect(store.singleMovesLeft == GameStore.freeSingleMoves - 1)
        #expect(store.state.movesUntilRotation == 1)
        #expect(store.state.score == 0)
        #expect(store.state.tiles.contains { $0.value == 8 && $0.row == 0 && $0.col == 2 })
        #expect(store.state.tiles.contains { $0.value == 4 && $0.row == 0 && $0.col == 1 })
        #expect(store.state.tiles.contains { $0.value == 2 && $0.row == 0 && $0.col == 0 })
        #expect(store.state.tiles.contains { $0.value == 2 && $0.row == 1 && $0.col == 3 })
        store.newGame()
        #expect(store.singleMovesLeft == GameStore.freeSingleMoves)
    }

    @Test func aTileMovedOnItsOwnMergesWithItsEqual() {
        let state = GameState(tiles: tiles([[2, 0, 0, 2], [4, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 20)
        let mover = state.tiles.first { $0.row == 0 && $0.col == 3 }!
        let result = GameEngine.slideOne(state.tiles, id: mover.id, .left)
        #expect(result.changed)
        #expect(result.gained == 4)
        #expect(result.tiles.count == 2)
        #expect(result.tiles.contains { $0.value == 4 && $0.row == 0 && $0.col == 0 })
        #expect(result.tiles.contains { $0.value == 4 && $0.row == 1 && $0.col == 0 })
        // A tile that is not there changes nothing.
        #expect(!GameEngine.slideOne(state.tiles, id: 999, .left).changed)
    }

    @Test func theDailyChestGrowsOverARunOfDays() {
        let defaults = freshDefaults()
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.isDailyReady(today: 100))
        #expect(store.dailyDay(today: 100) == 1)
        let first = store.claimDaily(today: 100)
        #expect(first == GameStore.dailyGift(day: 1))
        #expect(store.coins == 30)
        // Once a day.
        #expect(!store.isDailyReady(today: 100))
        #expect(store.claimDaily(today: 100) == nil)
        #expect(store.coins == 30)
        // The next day is day 2; the run is remembered.
        let relaunched = GameStore(defaults: defaults, animated: false)
        #expect(relaunched.dailyDay(today: 101) == 2)
        #expect(relaunched.claimDaily(today: 101) == GameStore.dailyGift(day: 2))
        #expect(relaunched.dailyStreak == 2)
        // A missed day starts the run again.
        #expect(relaunched.dailyDay(today: 103) == 1)
        #expect(relaunched.claimDaily(today: 103) == GameStore.dailyGift(day: 1))
        #expect(relaunched.dailyStreak == 1)
        #expect(GameStore.dailyGift(day: 7).gems == 5)
        #expect(GameStore.dailyGift(day: 7).coins == 150)
    }

    @Test func stagesTakeTurnsWithTwists() {
        #expect(GameStore.twist(forStage: 1) == .plain)
        #expect(GameStore.twist(forStage: 3) == .rocky)
        #expect(GameStore.twist(forStage: 4) == .breather)
        #expect(GameStore.twist(forStage: 5) == .plain)
        #expect(GameStore.twist(forStage: 7) == .quickTurn)
        #expect(GameStore.twist(forStage: 11) == .sprint)
        #expect(GameStore.stageGoal(4) == 1300)

        let defaults = freshDefaults()
        defaults.set(7, forKey: "ff.stage")
        let quick = GameStore(defaults: defaults, animated: false)
        quick.newGame()
        #expect(quick.twist == .quickTurn)
        #expect(quick.state.movesUntilRotation == 1)
        #expect(GameEngine.isValid(quick.state))

        defaults.set(3, forKey: "ff.stage")
        let rocky = GameStore(defaults: defaults, animated: false)
        rocky.newGame()
        #expect(rocky.state.tiles.filter { $0.kind == .stone }.count == 2)
        #expect(rocky.state.tiles.count == 4)

        defaults.set(11, forKey: "ff.stage")
        let sprint = GameStore(defaults: defaults, animated: false)
        sprint.newGame()
        #expect(sprint.secondsLeft == GameStore.sprintSeconds)
    }

    @Test func aHighLevelUnlocksThePartyLightsTheme() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 2696, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        let party = Skin.named("party")
        #expect(store.level == 6)
        #expect(!store.owns(party))
        store.swipe(.left)
        #expect(store.level == 7)
        #expect(store.owns(party))
    }

    @Test func gemsKeepATimedGameGoingOnce() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 300, movesUntilRotation: 2, nextID: 10), to: defaults)
        defaults.set(0.0, forKey: "ff.time")
        defaults.set(7, forKey: "ff.gems")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.isGameOver)
        #expect(store.canContinue)
        #expect(store.continueGame())
        #expect(store.gems == 7 - GameStore.continueCost)
        #expect(!store.isGameOver)
        #expect(store.secondsLeft == GameStore.continueSeconds)
        #expect(store.continueEvent == 1)
        // Not while the game is running, and not a second time once it ends again.
        #expect(!store.continueGame())
        store.swipe(.down)
        store.tick(GameStore.continueSeconds + 1)
        #expect(store.isGameOver)
        #expect(!store.canContinue)
        #expect(!store.continueGame())
        #expect(store.gems == 7 - GameStore.continueCost)
        // A new game can be carried on again.
        store.newGame()
        #expect(store.continuesUsed == 0)
    }

    @Test func gemsClearTilesOffADeadBoard() {
        let defaults = freshDefaults()
        let dead = GameState(tiles: tiles([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]]), score: 100, movesUntilRotation: 1, nextID: 20)
        save(dead, to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.isGameOver)
        // No gems: nothing happens.
        #expect(!store.continueGame())
        #expect(store.state == dead)
        #expect(store.isGameOver)

        defaults.set(GameStore.continueCost, forKey: "ff.gems")
        let funded = GameStore(defaults: defaults, animated: false)
        #expect(funded.continueGame())
        #expect(funded.gems == 0)
        #expect(!funded.isGameOver)
        #expect(funded.state.tiles.count == 16 - GameStore.continueClears)
        // The smallest tiles went first: every 4 is still there.
        #expect(funded.state.tiles.filter { $0.value == 4 }.count == 8)
    }

    @Test func everyThemeHasItsOwnIdAndName() {
        #expect(Skin.all.count == 11)
        #expect(Set(Skin.all.map(\.id)).count == Skin.all.count)
        #expect(Set(Skin.all.map(\.name)).count == Skin.all.count)
        #expect(Skin.all[0].unlock == .free)
        // A saved theme that no longer exists falls back to the free one.
        #expect(Skin.named("no-such-theme").id == Skin.all[0].id)
        // The free theme has no boards of its own; every other has two, shared with no one.
        #expect(Skin.all[0].boards.isEmpty)
        let own = Skin.all.dropFirst().flatMap(\.boards)
        #expect(own.count == 20)
        #expect(Set(own).count == 20)
        #expect(own.allSatisfy { $0 > GameEngine.standardShapes && $0 < GameEngine.layouts.count })
    }

    @Test func biggerGemPacksShowTheirBonus() {
        #expect(GemShop.bonusPercent(gems: 25, price: 0.99, baseGems: 25, basePrice: 0.99) == 0)
        #expect(GemShop.bonusPercent(gems: 60, price: 1.99, baseGems: 25, basePrice: 0.99) == 19)
        #expect(GemShop.bonusPercent(gems: 150, price: 3.99, baseGems: 25, basePrice: 0.99) == 48)
        #expect(GemShop.bonusPercent(gems: 10, price: 0, baseGems: 25, basePrice: 0.99) == 0)
    }

    @Test func starsFollowTheLevelReached() {
        #expect(StarRow.stars(forLevel: 1) == 0)
        #expect(StarRow.stars(forLevel: 2) == 1)
        #expect(StarRow.stars(forLevel: 5) == 2)
        #expect(StarRow.stars(forLevel: 6) == 3)
    }

    @Test func aNewLevelChangesTheBoardsShape() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 196, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.state.blocks.isEmpty)
        store.swipe(.left)
        #expect(store.level == 2)
        // Level 2 is played on the second shape: a hole in the corner the 4 was made in.
        #expect(store.state.shapeID == 1)
        #expect(store.state.blocks == GameEngine.layouts[1])
        #expect(store.shapeEvent == 1)
        // The 4 jumped out of the way; nothing was lost.
        #expect(store.state.tiles.count == 2)
        #expect(!store.state.tiles.contains { $0.row == 0 && $0.col == 0 })
        #expect(GameEngine.isValid(store.state))
        // The shape comes back with the game, and a new game starts on the open board.
        #expect(GameStore(defaults: defaults, animated: false).state.blocks == GameEngine.layouts[1])
        store.newGame()
        #expect(store.state.blocks.isEmpty)
        #expect(store.state.shapeID == 0)
    }

    @Test func smashingACrateScoresAndClearsIt() {
        let defaults = freshDefaults()
        save(GameState(
            tiles: tiles([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]),
            score: 0,
            movesUntilRotation: 2,
            nextID: 10,
            blocks: [Block(row: 1, col: 0, kind: .crate), Block(row: 3, col: 3, kind: .wall)]
        ), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        #expect(store.crateEvent == 1)
        #expect(store.lastCrateCount == 1)
        #expect(store.state.score == 4 + GameStore.cratePoints)
        #expect(store.state.blocks == [Block(row: 3, col: 3, kind: .wall)])
    }

    @Test func theShapeShiftGameChangesTheBoardEveryFewMoves() {
        let defaults = freshDefaults()
        defaults.set("shift", forKey: "ff.mode")
        // Saved as the game in play, but with no theme it is not open yet.
        #expect(GameStore(defaults: defaults, animated: false).mode == .timed)
        defaults.set(["sunset"], forKey: "ff.skins")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.isUnlocked(.shift))
        #expect(store.mode == .shift)
        #expect(store.state.blocks.isEmpty)
        #expect(!store.isTimeUp)
        let directions: [Direction] = [.left, .down, .right, .up]
        var tries = 0
        while store.shapeEvent == 0, tries < 60 {
            store.swipe(directions[tries % 4])
            tries += 1
        }
        // It changed on the fourth swipe that moved something, not before.
        #expect(store.shapeEvent == 1)
        #expect(store.slidePulse == GameEngine.movesPerShift)
        #expect(!store.state.blocks.isEmpty)
        // The board is now one of the outlines, cut out of it with holes.
        #expect(GameEngine.silhouetteName(store.state.shapeID) != nil)
        #expect(store.state.blocks.allSatisfy { $0.kind == .hole })
        #expect(store.state.movesUntilShift == GameEngine.movesPerShift)
        #expect(GameEngine.isValid(store.state))
        // The clock never runs in this game.
        store.tick(GameStore.roundSeconds + 1)
        #expect(!store.isGameOver)
        // It keeps its own saved game, apart from the other two.
        store.switchMode(.timed)
        #expect(store.state.blocks.isEmpty)
        store.switchMode(.shift)
        #expect(!store.state.blocks.isEmpty)
    }

    @Test func mergesBeforeTheBoardTurnsBuildACombo() {
        let defaults = freshDefaults()
        save(GameState(tiles: tiles([[2, 2, 4, 4], [8, 8, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), score: 0, movesUntilRotation: 2, nextID: 10), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.turnMerges == 0)
        store.swipe(.left)
        // Three merges in one swipe: a combo, and each burst carries the count.
        #expect(store.turnMerges == 3)
        #expect(store.heatEvent == 1)
        #expect(store.bursts.filter { $0.heat == 3 }.count == 3)
        // The turn starts the count again.
        #expect(store.useBooster(.flip))
        #expect(store.turnMerges == 0)
    }

    @Test func theTwistGameNeedsTwoThemesAndTurnsEitherWay() {
        let defaults = freshDefaults()
        defaults.set("twist", forKey: "ff.mode")
        defaults.set(["sunset"], forKey: "ff.skins")
        // One theme is not enough.
        let early = GameStore(defaults: defaults, animated: false)
        #expect(early.mode == .timed)
        #expect(!early.isUnlocked(.twist))
        #expect(early.isUnlocked(.shift))

        defaults.set(["sunset", "ocean"], forKey: "ff.skins")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.mode == .twist)
        #expect(!store.state.counterClockwise)
        let directions: [Direction] = [.left, .down, .right, .up]
        var tries = 0
        // Play until the board has turned six times.
        while store.rotatePulse < 6, tries < 200, !store.isGameOver {
            store.swipe(directions[tries % 4])
            tries += 1
            #expect(GameEngine.isValid(store.state))
        }
        let playedOut = store.rotatePulse == 6 || store.isGameOver
        #expect(playedOut)
        // The direction in the game matches the changes announced so far.
        let changedAnOddNumberOfTimes = store.directionEvent % 2 == 1
        #expect(store.state.counterClockwise == changedAnOddNumberOfTimes)
        // The clock never runs, and the direction is saved with the game.
        #expect(!store.isTimeUp)
        let again = GameStore(defaults: defaults, animated: false)
        #expect(again.state.counterClockwise == store.state.counterClockwise)
    }

    @Test func theSharkScattersTheTilesAndTakesTwo() {
        let defaults = freshDefaults()
        var start = GameState(
            tiles: tiles([[2, 4, 8, 16], [32, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]),
            score: 0,
            movesUntilRotation: 2,
            nextID: 20,
            blocks: [Block(row: 3, col: 3, kind: .wall)]
        )
        start.tiles[5].kind = .stone
        save(start, to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.stirBoard())
        #expect(store.stirEvent == 1)
        #expect(store.lastStirDropped == 2)
        // It bit one cell out of the board: a hole beside the wall that was there.
        #expect(store.lastChewCount == 1)
        #expect(store.state.blocks.filter { $0.kind == .hole }.count == 1)
        #expect(store.state.blocks.count == 2)
        // The stone block went first, then the smallest tile; the rest are all there.
        #expect(store.state.tiles.map(\.value).sorted() == [4, 8, 16, 32])
        #expect(!store.state.tiles.contains { $0.kind == .stone })
        // Nobody landed on the wall or on anybody else.
        #expect(GameEngine.isValid(store.state))
        #expect(!store.isGameOver)

        // It never leaves fewer than two tiles.
        #expect(store.stirBoard(dropping: 10))
        #expect(store.state.tiles.count == 2)
        #expect(store.stirBoard())
        #expect(store.state.tiles.count == 2)
        #expect(store.lastStirDropped == 0)
    }

    @Test func everyTileValueHasItsOwnFruit() {
        var seen: Set<String> = []
        var value = 2
        while value <= 2048 {
            let isNew = seen.insert(Fruit.face(for: value)).inserted
            #expect(isNew)
            value *= 2
        }
        #expect(seen.count == 11)
        // Past the last fruit it stays a star, and nonsense values do not crash.
        #expect(Fruit.face(for: 4096) == Fruit.face(for: 2048))
        #expect(Fruit.face(for: 0) == Fruit.face(for: 2))
    }

    @Test func theFruitGameIsOpenToEveryoneAndFusionNeedsThreeThemes() {
        let defaults = freshDefaults()
        // Fruit Salad opens at stage 8.
        #expect(!GameStore(defaults: defaults, animated: false).isUnlocked(.fruit))
        defaults.set(8, forKey: "ff.stage")
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.isUnlocked(.fruit))
        #expect(!store.isUnlocked(.fusion))
        store.switchMode(.fruit)
        #expect(store.mode == .fruit)
        #expect(!store.isTimeUp)

        defaults.set(["sunset", "ocean", "lava"], forKey: "ff.skins")
        defaults.set("fusion", forKey: "ff.mode")
        let fusion = GameStore(defaults: defaults, animated: false)
        #expect(fusion.mode == .fusion)
        let directions: [Direction] = [.left, .down, .right, .up]
        for turn in 0..<24 where !fusion.isGameOver {
            fusion.swipe(directions[turn % 4])
            // Tiles that change by themselves stay proper tiles.
            #expect(GameEngine.isValid(fusion.state))
        }
        // At most one tile changes for each move made.
        #expect(fusion.mutateEvent <= fusion.slidePulse)
        #expect(fusion.mutateEvent > 0)
    }

    @Test func openingACrateIsAGambleThatUsesAMove() {
        let defaults = freshDefaults()
        save(GameState(
            tiles: tiles([[2, 4, 8, 16], [32, 64, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]),
            score: 0,
            movesUntilRotation: 2,
            nextID: 20,
            blocks: [Block(row: 3, col: 0, kind: .crate), Block(row: 3, col: 3, kind: .crate), Block(row: 2, col: 2, kind: .wall)]
        ), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        // Nothing to open where there is no crate, or where there is a wall.
        #expect(!store.openCrate(row: 0, col: 0))
        #expect(!store.openCrate(row: 2, col: 2))

        // A prize: coins, the crate is gone, and a move has been used.
        #expect(store.openCrate(row: 3, col: 0, forcing: .coins(100)))
        #expect(store.coins == 100)
        #expect(store.crateOpenEvent == 1)
        #expect(store.state.blocks.filter { $0.kind == .crate }.count == 1)
        #expect(store.state.movesUntilRotation == 1)
        #expect(store.state.tiles.count == 6)

        // Trouble: a shark eats two tiles, and this second move turns the board.
        #expect(store.openCrate(row: 3, col: 3, forcing: .shark))
        #expect(store.lastCrateFind == .shark)
        #expect(store.lastStirDropped == 2)
        #expect(store.rotatePulse == 1)
        #expect(store.state.movesUntilRotation == 2)
        #expect(!store.state.blocks.contains { $0.kind == .crate })
        // The two smallest tiles went; the rest are all still there.
        var total = 0
        for tile in store.state.tiles {
            total += tile.value
        }
        // (Less anything the hole the shark bit then swallowed as the board turned.)
        let kept = total + store.swallowedValue
        #expect(kept >= 120)
        #expect(GameEngine.isValid(store.state))
    }

    @Test func aliensBeamUpTwoTilesAndATrexStampsThreeDown() {
        let defaults = freshDefaults()
        save(GameState(
            tiles: tiles([[8, 16, 32, 64], [128, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]),
            score: 0,
            movesUntilRotation: 2,
            nextID: 20,
            blocks: [Block(row: 3, col: 0, kind: .crate), Block(row: 3, col: 3, kind: .crate)]
        ), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)

        // The T-rex first: nothing is lost, but three tiles are worth half.
        #expect(store.openCrate(row: 3, col: 0, forcing: .trex))
        #expect(store.lastHazardCount == 3)
        #expect(store.state.tiles.count == 5)
        var total = 0
        for tile in store.state.tiles {
            total += tile.value
        }
        #expect(total < 248)
        #expect(total >= 124)
        #expect(GameEngine.isValid(store.state))

        // Then the aliens: two tiles go.
        let before = store.state.tiles.count
        #expect(store.openCrate(row: 3, col: 3, forcing: .ufo))
        #expect(store.lastHazardCount == 2)
        // The second crate was the second move, so the board turned as well; a turn
        // only merges or keeps tiles, so there are never more than three fewer.
        #expect(store.state.tiles.count <= before - 2)
        #expect(GameEngine.isValid(store.state))
        #expect(!GameStore.CrateFind.ufo.isPrize)
        #expect(!GameStore.CrateFind.trex.isPrize)

        // The monkey's bouncing about can be done at any quiet moment and loses nothing.
        let held = store.state.tiles.count
        #expect(store.jumble())
        #expect(store.state.tiles.count == held)
        #expect(GameEngine.isValid(store.state))
    }

    @Test func aMonkeyMixesTheBoardButTakesNothing() {
        let defaults = freshDefaults()
        save(GameState(
            tiles: tiles([[2, 4, 8, 16], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]),
            score: 0,
            movesUntilRotation: 2,
            nextID: 20,
            blocks: [Block(row: 3, col: 0, kind: .crate)]
        ), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.openCrate(row: 3, col: 0, forcing: .monkey))
        #expect(store.lastStirDropped == 0)
        #expect(store.state.tiles.map(\.value).sorted() == [2, 4, 8, 16])
        #expect(GameEngine.isValid(store.state))
        #expect(!GameStore.CrateFind.monkey.isPrize)
        #expect(GameStore.CrateFind.gem.isPrize)
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

    @Test func aHoleClosesAfterThreeTiles() {
        let defaults = freshDefaults()
        var hungry = Block(row: 0, col: 0, kind: .hole)
        hungry.fed = 2
        save(GameState(
            tiles: tiles([[0, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [8, 0, 0, 16]]),
            score: 0,
            movesUntilRotation: 2,
            nextID: 20,
            blocks: [hungry]
        ), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        store.swipe(.left)
        #expect(store.swallowEvent == 1)
        #expect(store.lastSwallowCount == 1)
        #expect(store.swallowedValue == 2)
        // That was its third: the hole has closed.
        #expect(store.holeClosedEvent == 1)
        #expect(store.state.blocks.isEmpty)
        #expect(store.state.score == 0)
    }

    @Test func everyThemeHasACreatureOfItsOwn() {
        var seen: [GameStore.CrateFind] = []
        for skin in Skin.all {
            let found = GameStore.creatures(forTheme: skin.id)
            #expect(found.count == 1)
            #expect(found.allSatisfy { $0.isCreature })
            seen.append(contentsOf: found)
        }
        // Eleven themes, eleven different creatures.
        #expect(seen.count == 11)
        for index in seen.indices {
            #expect(!seen[..<index].contains(seen[index]))
        }
    }

    @Test func aMoleDigsHolesAndAPinataPaysOut() {
        let defaults = freshDefaults()
        save(GameState(
            tiles: tiles([[2, 4, 8, 16], [32, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]),
            score: 0,
            movesUntilRotation: 2,
            nextID: 20,
            blocks: [Block(row: 3, col: 0, kind: .crate), Block(row: 3, col: 3, kind: .crate)]
        ), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        #expect(store.openCrate(row: 3, col: 0, forcing: .beast(.mole)))
        #expect(store.lastChewCount == 2)
        #expect(store.state.blocks.filter { $0.kind == .hole }.count == 2)
        #expect(store.state.tiles.count == 5)
        #expect(!GameStore.CrateFind.beast(.mole).isPrize)

        let coins = store.coins
        let gems = store.gems
        #expect(store.openCrate(row: 3, col: 3, forcing: .beast(.pinata)))
        #expect(store.coins == coins + GameStore.pinataCoins)
        #expect(store.gems == gems + 1)
        #expect(GameStore.CrateFind.beast(.pinata).isPrize)
    }

    @Test func wildWeatherHitsTheBoard() {
        let defaults = freshDefaults()
        save(GameState(
            tiles: tiles([[2, 4, 8, 16], [32, 64, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]),
            score: 0,
            movesUntilRotation: 2,
            nextID: 20
        ), to: defaults)
        let store = GameStore(defaults: defaults, animated: false)
        // An asteroid shower knocks the two smallest tiles off.
        #expect(store.stormStrikes(forcing: .asteroids))
        #expect(store.stormEvent == 1)
        #expect(store.lastStorm == .asteroids)
        #expect(store.state.tiles.map(\.value).sorted() == [8, 16, 32, 64])
        // A downpour moves tiles and takes none.
        #expect(store.stormStrikes(forcing: .downpour))
        #expect(store.state.tiles.count == 4)
        // An eruption lands two lumps of rock.
        #expect(store.stormStrikes(forcing: .eruption))
        #expect(store.state.tiles.filter { $0.kind == .stone }.count == 2)
        // A falling star takes a tile and leaves a crater.
        #expect(store.stormStrikes(forcing: .meteors))
        #expect(store.state.blocks.filter { $0.kind == .hole }.count == 1)
        #expect(GameEngine.isValid(store.state))
        #expect(GameStore.storm(forTheme: "galaxy") == .asteroids)
        #expect(GameStore.storm(forTheme: "neon") == nil)
    }

    @Test func aHeadToHeadGameStartsFromTheDealtBoardWithTheClockRunning() {
        let store = GameStore(defaults: freshDefaults(), animated: false)
        let dealt = tiles([[0, 0, 4, 0], [0, 0, 0, 0], [0, 2, 0, 0], [0, 0, 0, 0]])
        store.startVersus(with: dealt)
        #expect(store.isVersus)
        #expect(store.mode == .timed)
        #expect(store.state.score == 0)
        #expect(store.state.tiles.map(\.value).sorted() == [2, 4])
        #expect(store.isTimerRunning)
        // It cannot be carried on with gems, even when time runs out.
        store.tick(GameStore.roundSeconds + 1)
        #expect(store.isGameOver)
        #expect(!store.canContinue)
        store.endVersus()
        #expect(!store.isVersus)
    }
}
