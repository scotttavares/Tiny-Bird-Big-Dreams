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
        #expect(Skin.all.count == 9)
        #expect(Set(Skin.all.map(\.id)).count == Skin.all.count)
        #expect(Set(Skin.all.map(\.name)).count == Skin.all.count)
        #expect(Skin.all[0].unlock == .free)
        // A saved theme that no longer exists falls back to the free one.
        #expect(Skin.named("no-such-theme").id == Skin.all[0].id)
        // The free theme has no boards of its own; every other has two, shared with no one.
        #expect(Skin.all[0].boards.isEmpty)
        let own = Skin.all.dropFirst().flatMap(\.boards)
        #expect(own.count == 16)
        #expect(Set(own).count == 16)
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
        #expect(store.rotatePulse == 6 || store.isGameOver)
        // The direction in the game matches the changes announced so far.
        #expect(store.state.counterClockwise == (store.directionEvent % 2 == 1))
        // The clock never runs, and the direction is saved with the game.
        #expect(!store.isTimeUp)
        let again = GameStore(defaults: defaults, animated: false)
        #expect(again.state.counterClockwise == store.state.counterClockwise)
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
