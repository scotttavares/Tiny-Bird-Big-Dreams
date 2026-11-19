import Foundation
import Observation
import SwiftUI

/// Holds the game in play, runs each move as a short sequence of animated steps,
/// and saves the game and the best score.
@MainActor
@Observable
final class GameStore {
    private(set) var state: GameState
    private(set) var best: Int
    private(set) var isGameOver = false
    /// Degrees the board is turned on screen. 0 at rest, sweeps to 90 during a rotation.
    private(set) var boardAngle: Double = 0
    /// Tiles merged away in the current step, still drawn until the step ends.
    private(set) var ghosts: [Tile] = []
    /// Tiles to pulse right now.
    private(set) var poppedIDs: Set<Int> = []
    /// How many chain passes merged tiles in the last rotation.
    private(set) var lastCombo = 0
    /// Goes up each time a chain of two or more happens (drives the "Chain" banner).
    private(set) var comboEvent = 0
    /// Goes up on every merge and on every rotation (drive the haptics).
    private(set) var mergePulse = 0
    private(set) var rotatePulse = 0
    private(set) var isAnimating = false
    /// True once the player has merged anything, ever. Hides the first-game hint.
    private(set) var hasMergedOnce: Bool

    /// How long one game lasts.
    static let roundSeconds: Double = 120
    /// Time left in this game. The clock starts on the first swipe.
    private(set) var secondsLeft: Double
    /// `secondsLeft` rounded up, so views that only need whole seconds redraw once a second.
    private(set) var wholeSecondsLeft: Int
    private(set) var isTimerRunning = false
    /// Goes up on every swipe that moves something (drives the swipe sound).
    private(set) var slidePulse = 0
    /// The biggest tile made by the latest merge (picks the merge sound).
    private(set) var lastMergeValue = 0
    /// Merges to sparkle on the board. Cleared at the start of the next move.
    private(set) var bursts: [Burst] = []
    /// Goes up each time points are scored; `lastGain` is how many.
    private(set) var gainEvent = 0
    private(set) var lastGain = 0

    /// Seconds a clock tile adds, and how long double points last.
    static let timeBonus: Double = 10
    static let feverSeconds: Double = 10
    /// A chain this long (or longer) starts double points.
    static let feverChain = 2

    /// True while every point scored counts double.
    private(set) var isFever = false
    /// Goes up each time double points starts.
    private(set) var feverEvent = 0
    /// Go up when a clock tile adds time, when a bomb goes off, and when a special tile arrives.
    private(set) var timeBonusEvent = 0
    private(set) var bombEvent = 0
    private(set) var specialSpawnEvent = 0
    private(set) var lastSpecialKind = TileKind.normal

    /// One merge to sparkle, at a board cell. A blast is the bigger burst of a bomb.
    struct Burst: Identifiable, Equatable {
        let id: Int
        let row: Int
        let col: Int
        let value: Int
        var isBlast = false
        /// A super combo: three or four tiles merged here at once.
        var isSuper = false
        /// Points to float up from the cell (0 shows nothing).
        var points = 0
        /// How many merges the player had made since the board last turned when this
        /// one happened. The more, the bigger the burst.
        var heat = 0
    }

    /// Merges made by swipes since the board last turned. Each one makes the next
    /// burst bigger; the turn sets it back to nothing.
    private(set) var turnMerges = 0
    /// Goes up each time a swipe takes `turnMerges` to this many or more.
    private(set) var heatEvent = 0
    static let heatCombo = 3

    @ObservationIgnored private var feverLeft: Double = 0

    // MARK: Coins, boosters and the speed streak

    /// A helper the player taps under the board. Each starts with a few free uses;
    /// after that a use costs coins.
    enum Booster: String, CaseIterable, Sendable {
        /// Turns the board right now, without using up a move.
        case flip
        /// Clears every 2 and 4 off the board.
        case sweep
        /// Starts double points.
        case fever
        /// Turns up to three ordinary tiles into bombs.
        case arm

        var price: Int {
            switch self {
            case .flip: return 150
            case .sweep: return 250
            case .fever: return 200
            case .arm: return 200
            }
        }
    }

    /// How many tiles the bombs booster arms.
    static let armedTiles = 3
    /// A merge that makes a tile this big (or bigger) shakes the board.
    static let bigMerge = 64

    static let freeBoosters = 3
    /// Points needed to earn one coin.
    static let pointsPerCoin = 20
    /// Merge again within this many seconds to keep the speed streak going.
    static let streakWindow: Double = 4
    static let maxStreak = 4

    /// Coins are earned from points and shared by both game modes.
    private(set) var coins: Int
    private(set) var boosterCounts: [Booster: Int]
    /// Quick merges in a row. Each step adds one to the score multiplier (so 0 is x1).
    private(set) var streak = 0
    /// Go up when a booster is used, when one is refused, and when the board should shake.
    private(set) var boosterEvent = 0
    private(set) var boosterDeniedEvent = 0
    private(set) var shakeEvent = 0
    private(set) var lastBooster = Booster.flip
    /// How many tiles the last sweep cleared.
    private(set) var lastSweepCount = 0
    /// How hard the latest shake is: 1 a nudge, 2 a jolt, 3 a blast.
    private(set) var shakePower = 1
    /// Goes up when the board should flash white (bombs and super combos).
    private(set) var flashEvent = 0
    /// Goes up on a super combo; `lastSuperCount` is how many tiles merged at once.
    private(set) var superEvent = 0
    private(set) var lastSuperCount = 0
    /// How many bombs went off in the latest blast (more than one is a chain reaction).
    private(set) var lastBombCount = 0
    /// How many tiles the last bombs booster armed.
    private(set) var lastArmCount = 0

    // MARK: Levels

    /// The level this game has reached. It goes up with the score, and the game gets
    /// harder as it does: stone blocks from level 3, extra tiles from level 4.
    private(set) var level: Int
    /// Goes up each time a level is reached.
    private(set) var levelEvent = 0
    /// Seconds a new level adds to the clock in the timed game.
    static let levelTimeBonus: Double = 10

    /// What a new level wins. A reel spins on screen and stops on it.
    enum Prize: Equatable, Sendable {
        case coins(Int)
        case gems(Int)
        /// One free use of a booster.
        case booster(Booster)
    }

    /// The top prize.
    static let jackpot = Prize.gems(5)
    /// The faces the reel flicks through before it stops.
    static let reelFaces: [Prize] = [
        .coins(50), .gems(1), .booster(.arm), .coins(100), .gems(2), .booster(.sweep), jackpot, .booster(.fever),
    ]
    /// Goes up each time a prize is won; `lastPrize` is the prize.
    private(set) var prizeEvent = 0
    private(set) var lastPrize = Prize.coins(50)

    /// Picks the prize for a new level and hands it over. Out of 100: 40 are 50 coins,
    /// 25 are 100 coins, 15 a free booster, 14 one gem, 5 two gems and 1 the jackpot.
    private func awardLevelPrize() {
        let roll = Int.random(in: 0..<100, using: &rng)
        let prize: Prize
        if roll < 40 {
            prize = .coins(50)
        } else if roll < 65 {
            prize = .coins(100)
        } else if roll < 80 {
            prize = .booster(Booster.allCases.randomElement(using: &rng) ?? .flip)
        } else if roll < 94 {
            prize = .gems(1)
        } else if roll < 99 {
            prize = .gems(2)
        } else {
            prize = Self.jackpot
        }
        switch prize {
        case .coins(let count):
            coins += count
        case .gems(let count):
            gems += count
        case .booster(let booster):
            boosterCounts[booster, default: 0] += 1
        }
        lastPrize = prize
        prizeEvent += 1
    }

    /// True when the board is nearly full: the screen glows red and the music speeds up.
    var isDanger: Bool {
        !isGameOver && GameEngine.emptyCells(state.tiles, blocked: blockedSet).count <= 2
    }

    // MARK: Board shapes

    /// The cells no tile can enter right now.
    private var blockedSet: Set<Cell> {
        Set(state.blocks.map(\.cell))
    }

    /// Goes up each time the board changes shape.
    private(set) var shapeEvent = 0
    /// Goes up when crates are smashed; `lastCrateCount` is how many.
    private(set) var crateEvent = 0
    private(set) var lastCrateCount = 0
    /// Points for smashing a crate.
    static let cratePoints = 20
    /// True between a swipe and the end of its move, so only swipes count toward
    /// the next change of shape.
    @ObservationIgnored private var swipeInFlight = false

    /// Puts a new shape on the board. A tile standing where an obstacle now is
    /// jumps to an empty cell (the biggest tiles first); if there is none, it goes.
    private func reshape(to index: Int, turns: Int) {
        var blocks = GameEngine.layouts[index]
        for _ in 0..<turns {
            blocks = GameEngine.rotateClockwise(blocks)
        }
        state.shapeID = index
        state.blocks = blocks
        let blocked = Set(blocks.map(\.cell))
        let displaced = state.tiles
            .filter { blocked.contains(Cell(row: $0.row, col: $0.col)) }
            .sorted { $0.value > $1.value }
        for tile in displaced {
            guard let at = state.tiles.firstIndex(where: { $0.id == tile.id }) else { continue }
            if let cell = GameEngine.emptyCells(state.tiles, blocked: blocked).randomElement(using: &rng) {
                state.tiles[at].row = cell.row
                state.tiles[at].col = cell.col
            } else {
                state.tiles.remove(at: at)
            }
        }
        shapeEvent += 1
    }

    /// Changes the board's shape when it is time to: on a new level in the timed and
    /// endless games, and every few moves, at random, in the Shape Shift game.
    private func reshapeIfNeeded(afterSwipe: Bool) {
        var target: Int?
        var turns = 0
        if mode == .shift {
            guard afterSwipe else { return }
            state.movesUntilShift -= 1
            guard state.movesUntilShift <= 0 else { return }
            state.movesUntilShift = GameEngine.movesPerShift
            // A new outline for the board: a triangle, a ring, a cup and so on. Never
            // the one it already has.
            let first = GameEngine.firstSilhouette
            let count = GameEngine.silhouetteNames.count
            var pick = first + Int.random(in: 0..<count, using: &rng)
            if pick == state.shapeID {
                pick = first + (pick - first + 1) % count
            }
            target = pick
            turns = Int.random(in: 0..<4, using: &rng)
        } else {
            let wanted = GameEngine.layoutIndex(forLevel: level, signature: Skin.current.boards)
            if wanted != state.shapeID {
                target = wanted
            }
        }
        guard let target else { return }
        if animated {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                reshape(to: target, turns: turns)
            }
        } else {
            reshape(to: target, turns: turns)
        }
    }

    // MARK: The Fusion game

    /// Goes up each time a tile changes by itself.
    private(set) var mutateEvent = 0

    /// The Fusion game: one ordinary tile, picked at random, changes by itself. Six
    /// times in ten it doubles; otherwise it halves (a 2 stays a 2).
    private func mutateTile() {
        guard let pick = state.tiles.indices.filter({ state.tiles[$0].kind == .normal }).randomElement(using: &rng) else { return }
        let old = state.tiles[pick].value
        let new = Int.random(in: 0..<10, using: &rng) < 6 ? old * 2 : max(2, old / 2)
        guard new != old else { return }
        let tile = state.tiles[pick]
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                state.tiles[pick].value = new
            }
        } else {
            state.tiles[pick].value = new
        }
        nextBurstID += 1
        bursts.append(Burst(id: nextBurstID, row: tile.row, col: tile.col, value: new))
        mutateEvent += 1
    }

    // MARK: The shark and the monkey

    /// Goes up each time the board is stirred; `lastStirDropped` is how many tiles
    /// were knocked off it.
    private(set) var stirEvent = 0
    private(set) var lastStirDropped = 0

    /// Throws every tile to a new cell and knocks up to `drop` of them off the board
    /// (stone blocks first, then the smallest tiles, never leaving fewer than two).
    private func scatterTiles(dropping drop: Int) {
        func scatter() {
            let count = max(0, min(drop, state.tiles.count - 2))
            let doomed = state.tiles.sorted { first, second in
                if (first.kind == .stone) != (second.kind == .stone) {
                    return first.kind == .stone
                }
                return first.value < second.value
            }.prefix(count)
            for tile in doomed {
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: tile.row, col: tile.col, value: tile.value))
            }
            let gone = Set(doomed.map(\.id))
            state.tiles.removeAll { gone.contains($0.id) }
            // Every cell a tile may stand on, in a random order.
            var cells = GameEngine.emptyCells([], blocked: blockedSet).shuffled(using: &rng)
            for index in state.tiles.indices {
                guard let cell = cells.popLast() else { break }
                state.tiles[index].row = cell.row
                state.tiles[index].col = cell.col
            }
            lastStirDropped = doomed.count
            stirEvent += 1
            shake(3)
        }

        if animated {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scatter()
            }
        } else {
            scatter()
        }
    }

    /// The Ocean theme's shark hits the board: the tiles are scattered and up to
    /// `drop` are knocked off. Returns false, and does nothing, while a move is
    /// still playing or the game is over.
    @discardableResult
    func stirBoard(dropping drop: Int = 2) -> Bool {
        guard !isAnimating, !isGameOver, state.tiles.count > 1 else { return false }
        bursts.removeAll()
        scatterTiles(dropping: drop)
        finishMove()
        return true
    }

    // MARK: Opening crates

    /// What was inside a crate. Some finds are prizes; some are trouble.
    enum CrateFind: Equatable, Sendable {
        case coins(Int)
        case gem
        /// One free use of a booster.
        case booster(Booster)
        /// Double points for a while.
        case fever
        /// Seconds on the clock (the timed game only).
        case time
        /// A monkey jumps out and mixes the tiles up.
        case monkey
        /// A shark comes out, mixes the tiles up and eats two.
        case shark
        /// Two stone blocks fall onto the board.
        case stones

        /// True for the finds the player is glad of.
        var isPrize: Bool {
            switch self {
            case .monkey, .shark, .stones: return false
            default: return true
            }
        }
    }

    /// Goes up each time a crate is opened; `lastCrateFind` is what was in it.
    private(set) var crateOpenEvent = 0
    private(set) var lastCrateFind = CrateFind.coins(100)

    /// Picks what is in a crate. Out of 100: 22 are 100 coins, 12 a gem, 12 a free
    /// booster, 8 double points, 8 ten seconds (100 coins when there is no clock);
    /// then 16 a monkey, 12 a shark and 10 two stone blocks.
    private func rollCrate() -> CrateFind {
        let roll = Int.random(in: 0..<100, using: &rng)
        switch roll {
        case ..<22: return .coins(100)
        case ..<34: return .gem
        case ..<46: return .booster(Booster.allCases.randomElement(using: &rng) ?? .flip)
        case ..<54: return .fever
        case ..<62: return mode == .timed ? .time : .coins(100)
        case ..<78: return .monkey
        case ..<90: return .shark
        default: return .stones
        }
    }

    /// Opens the crate in a cell (a tap on it). Opening a crate is a move: it counts
    /// toward the next turn of the board, so it is a gamble even before the lid comes
    /// off. Returns false, and does nothing, when there is no crate there, a move is
    /// still playing, or the game is over. `forcing` fixes what is found (tests).
    @discardableResult
    func openCrate(row: Int, col: Int, forcing forced: CrateFind? = nil) -> Bool {
        guard !isAnimating, !isGameOver,
              let at = state.blocks.firstIndex(where: { $0.kind == .crate && $0.row == row && $0.col == col })
        else { return false }

        bursts.removeAll()
        isTimerRunning = true
        swipeInFlight = true
        let find = forced ?? rollCrate()

        func lift() {
            state.blocks.remove(at: at)
        }
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                lift()
            }
        } else {
            lift()
        }
        nextBurstID += 1
        bursts.append(Burst(id: nextBurstID, row: row, col: col, value: 64, isSuper: true))

        switch find {
        case .coins(let count):
            coins += count
        case .gem:
            gems += 1
        case .booster(let booster):
            boosterCounts[booster, default: 0] += 1
        case .fever:
            isFever = true
            feverLeft = Self.feverSeconds
            feverEvent += 1
        case .time:
            secondsLeft = min(Self.roundSeconds, secondsLeft + Self.timeBonus)
            wholeSecondsLeft = Int(secondsLeft.rounded(.up))
        case .monkey:
            scatterTiles(dropping: 0)
        case .shark:
            scatterTiles(dropping: 2)
        case .stones:
            spawnTile(forcing: .stone)
            spawnTile(forcing: .stone)
            shake(2)
        }
        lastCrateFind = find
        crateOpenEvent += 1

        state.movesUntilRotation -= 1
        if state.movesUntilRotation <= 0 {
            if animated {
                isAnimating = true
                Task { [weak self] in
                    await self?.pause(0.6)
                    await self?.rotateAnimated()
                    self?.finishMove()
                    self?.isAnimating = false
                }
            } else {
                rotateImmediately()
                finishMove()
            }
        } else {
            finishMove()
        }
        return true
    }

    // MARK: Keep going

    /// Gems it costs to carry on with a game that has ended, once per game.
    static let continueCost = 5
    /// What carrying on gives: this much time, and this many tiles cleared off a
    /// board with no move left.
    static let continueSeconds: Double = 30
    static let continueClears = 6
    private(set) var continuesUsed = 0
    /// Goes up each time a finished game is carried on.
    private(set) var continueEvent = 0

    /// True when the game has ended and has not been carried on yet.
    var canContinue: Bool {
        isGameOver && !isAnimating && continuesUsed == 0 && state.score > 0
    }

    /// Spends gems to carry on with a game that has ended. Time's up: the clock gets
    /// more time. No move left: the smallest tiles (stone blocks first) are cleared.
    /// Returns false (and changes nothing) when it cannot be done or the gems are short.
    @discardableResult
    func continueGame() -> Bool {
        guard canContinue, gems >= Self.continueCost else { return false }
        gems -= Self.continueCost
        continuesUsed += 1
        bursts.removeAll()
        if isTimeUp {
            secondsLeft = Self.continueSeconds
            wholeSecondsLeft = Int(Self.continueSeconds.rounded(.up))
        }
        if !GameEngine.hasMove(state.tiles, blocked: blockedSet) {
            let doomed = state.tiles.sorted { first, second in
                if (first.kind == .stone) != (second.kind == .stone) {
                    return first.kind == .stone
                }
                return first.value < second.value
            }.prefix(Self.continueClears)
            for tile in doomed {
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: tile.row, col: tile.col, value: tile.value))
            }
            let ids = Set(doomed.map(\.id))
            state.tiles.removeAll { ids.contains($0.id) }
            shake(2)
        }
        isGameOver = false
        // The next swipe starts the clock again.
        isTimerRunning = false
        continueEvent += 1
        save()
        return true
    }

    // MARK: Gems and themes

    /// Gems are the rare prize: super combos, chains, big scores and new bests earn
    /// them, and they buy themes. Shared by both game modes.
    private(set) var gems: Int
    /// The ids of the themes the player has.
    private(set) var ownedSkins: Set<String>
    /// Goes up when gems are earned; `lastGemGain` is how many.
    private(set) var gemEvent = 0
    private(set) var lastGemGain = 0
    /// Goes up when play unlocks a theme; `lastUnlockedSkin` is its name.
    private(set) var unlockEvent = 0
    private(set) var lastUnlockedSkin = ""

    /// Gems for a super combo of three tiles, of four, and for a chain.
    static let gemsForSuper = 1
    static let gemsForMega = 3
    static let gemsForChain = 1
    /// At the end of a game: one gem for every this many points, and more for a new best.
    static let pointsPerGem = 500
    static let gemsForBest = 2

    /// The Shape Shift game opens with the player's first theme beyond the free one,
    /// bought or won.
    func isUnlocked(_ mode: Mode) -> Bool {
        ownedSkins.count >= Self.themesNeeded(for: mode)
    }

    /// How many themes beyond the free one a game needs: none for the first two
    /// games, one for Shape Shift, two for Twist.
    nonisolated static func themesNeeded(for mode: Mode) -> Int {
        switch mode {
        case .timed, .endless, .fruit: return 0
        case .shift: return 1
        case .twist: return 2
        case .fusion: return 3
        }
    }

    /// True when the theme is the player's to use.
    func owns(_ skin: Skin) -> Bool {
        skin.unlock == .free || ownedSkins.contains(skin.id)
    }

    /// Buys a theme with gems. Returns false (and changes nothing) when it is not
    /// for sale, is already owned, or costs more gems than the player has.
    @discardableResult
    func buy(_ skin: Skin) -> Bool {
        guard case .gems(let price) = skin.unlock, !owns(skin), gems >= price else { return false }
        gems -= price
        ownedSkins.insert(skin.id)
        save()
        return true
    }

    /// Adds gems bought from the App Store. Each purchase counts once: the same
    /// `purchaseID` a second time adds nothing and returns false.
    @discardableResult
    func addPurchasedGems(_ count: Int, purchaseID: String) -> Bool {
        var seen = defaults.stringArray(forKey: Key.purchases) ?? []
        guard count > 0, !seen.contains(purchaseID) else { return false }
        seen.append(purchaseID)
        defaults.set(Array(seen.suffix(200)), forKey: Key.purchases)
        earnGems(count)
        save()
        return true
    }

    private func earnGems(_ count: Int) {
        guard count > 0 else { return }
        gems += count
        lastGemGain = count
        gemEvent += 1
    }

    /// Hands over any theme that play has just earned.
    private func unlockSkins(where earned: (Skin.Unlock) -> Bool) {
        for skin in Skin.all where !owns(skin) && earned(skin.unlock) {
            ownedSkins.insert(skin.id)
            lastUnlockedSkin = skin.name
            unlockEvent += 1
        }
    }

    /// The best score when this game began (or was reopened): beating it earns gems.
    @ObservationIgnored private var bestAtStart = 0

    /// What this game has already been paid, so a game that is carried on and ends a
    /// second time is only paid for the points made since.
    @ObservationIgnored private var paidScoreGems = 0
    @ObservationIgnored private var paidBestBonus = false

    /// The prizes handed out when a game ends.
    private func rewardFinishedGame() {
        let earned = state.score / Self.pointsPerGem
        var prize = max(0, earned - paidScoreGems)
        paidScoreGems = max(paidScoreGems, earned)
        if !paidBestBonus, state.score > bestAtStart, state.score > 0 {
            prize += Self.gemsForBest
            paidBestBonus = true
        }
        earnGems(prize)
    }

    @ObservationIgnored private var streakLeft: Double = 0
    @ObservationIgnored private var coinBank = 0

    /// What every point is multiplied by right now.
    var scoreMultiplier: Int { (1 + streak) * (isFever ? 2 : 1) }

    /// The two ways to play. Each keeps its own game in progress and its own best score.
    enum Mode: String, Sendable {
        /// Two minutes on the clock.
        case timed
        /// No clock: play until no move is left. An extra tile lands after every
        /// rotation, so the board does fill up.
        case endless
        /// No clock, and the board changes shape at random every few moves.
        case shift
        /// No clock, and the board may turn left or right: the arrow shows which.
        case twist
        /// No clock, and every tile shows a fruit in place of its number.
        case fruit
        /// No clock, and after every move one tile changes by itself.
        case fusion
    }

    private(set) var mode: Mode

    var isTimeUp: Bool { mode == .timed && secondsLeft <= 0 }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let animated: Bool
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var nextBurstID = 0

    private enum Key {
        static let merged = "ff.merged"
        static let time = "ff.time"
        static let mode = "ff.mode"
        static let coins = "ff.coins"
        static let gems = "ff.gems"
        static let skins = "ff.skins"
        static let purchases = "ff.purchases"

        static func booster(_ booster: Booster) -> String {
            "ff.booster." + booster.rawValue
        }

        static func state(_ mode: Mode) -> String {
            switch mode {
            case .timed: return "ff.state"
            case .endless: return "ff.endless.state"
            case .shift: return "ff.shift.state"
            case .twist: return "ff.twist.state"
            case .fruit: return "ff.fruit.state"
            case .fusion: return "ff.fusion.state"
            }
        }

        static func best(_ mode: Mode) -> String {
            switch mode {
            case .timed: return "ff.best"
            case .endless: return "ff.endless.best"
            case .shift: return "ff.shift.best"
            case .twist: return "ff.twist.best"
            case .fruit: return "ff.fruit.best"
            case .fusion: return "ff.fusion.best"
            }
        }
    }

    /// A game read back from storage (or a fresh one when nothing usable was saved).
    private struct Loaded {
        var state: GameState
        var best: Int
        var seconds: Double
    }

    private static func load(_ mode: Mode, from defaults: UserDefaults) -> Loaded {
        var best = max(0, defaults.integer(forKey: Key.best(mode)))
        var restored: GameState?
        if let data = defaults.data(forKey: Key.state(mode)),
           let saved = try? JSONDecoder().decode(GameState.self, from: data),
           GameEngine.isValid(saved) {
            restored = saved
        }
        // A restored timed game keeps its clock; anything else starts with a full one.
        var seconds = roundSeconds
        if mode == .timed, restored != nil, let saved = defaults.object(forKey: Key.time) as? Double {
            seconds = min(max(saved, 0), roundSeconds)
        }
        var state: GameState
        if let restored {
            state = restored
        } else {
            var generator = SystemRandomNumberGenerator()
            state = GameEngine.newGame(using: &generator)
        }
        if state.score > best {
            best = state.score
        }
        return Loaded(state: state, best: best, seconds: seconds)
    }

    private enum Timing {
        static let slide = 0.14
        static let pop = 0.12
        static let beforeRotation = 0.25
        static let rotation = 0.45
        static let fall = 0.18
    }

    init(defaults: UserDefaults = .standard, animated: Bool = true) {
        self.defaults = defaults
        self.animated = animated
        self.hasMergedOnce = defaults.bool(forKey: Key.merged)
        self.coins = max(0, defaults.integer(forKey: Key.coins))
        var counts: [Booster: Int] = [:]
        for booster in Booster.allCases {
            let saved = defaults.object(forKey: Key.booster(booster)) as? Int
            counts[booster] = max(0, saved ?? GameStore.freeBoosters)
        }
        self.boosterCounts = counts
        self.gems = max(0, defaults.integer(forKey: Key.gems))
        let owned = Set(defaults.stringArray(forKey: Key.skins) ?? [])
        self.ownedSkins = owned

        var mode = Mode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .timed
        if owned.count < GameStore.themesNeeded(for: mode) {
            mode = .timed
        }
        let loaded = GameStore.load(mode, from: defaults)
        self.mode = mode
        self.state = loaded.state
        self.level = GameEngine.level(forScore: loaded.state.score)
        self.best = loaded.best
        self.bestAtStart = loaded.best
        self.secondsLeft = loaded.seconds
        self.wholeSecondsLeft = Int(loaded.seconds.rounded(.up))
        self.isGameOver = !GameEngine.hasMove(loaded.state.tiles, blocked: Set(loaded.state.blocks.map(\.cell))) || (mode == .timed && loaded.seconds <= 0)
    }

    /// Changes the way to play. The game left behind is saved and waits for you.
    func switchMode(_ newMode: Mode) {
        guard !isAnimating, newMode != mode, isUnlocked(newMode) else { return }
        save()
        mode = newMode
        defaults.set(newMode.rawValue, forKey: Key.mode)

        let loaded = GameStore.load(newMode, from: defaults)
        state = loaded.state
        level = GameEngine.level(forScore: loaded.state.score)
        continuesUsed = 0
        paidScoreGems = 0
        paidBestBonus = false
        best = loaded.best
        bestAtStart = loaded.best
        secondsLeft = loaded.seconds
        wholeSecondsLeft = Int(loaded.seconds.rounded(.up))
        ghosts = []
        poppedIDs = []
        bursts = []
        lastCombo = 0
        turnMerges = 0
        boardAngle = 0
        isFever = false
        feverLeft = 0
        streak = 0
        streakLeft = 0
        isTimerRunning = false
        isGameOver = !GameEngine.hasMove(state.tiles, blocked: blockedSet) || isTimeUp
        save()
    }

    // MARK: Boosters

    /// True when the booster can be used now: a free use is left or the coins cover it.
    func canAfford(_ booster: Booster) -> Bool {
        (boosterCounts[booster] ?? 0) > 0 || coins >= booster.price
    }

    /// Uses a booster. Returns false (and changes nothing) when it cannot be used:
    /// a move is still playing, the game is over, there is nothing for it to do,
    /// or there are no free uses and not enough coins.
    @discardableResult
    func useBooster(_ booster: Booster) -> Bool {
        guard !isAnimating, !isGameOver else { return false }
        guard canAfford(booster) else {
            lastBooster = booster
            boosterDeniedEvent += 1
            return false
        }
        if booster == .sweep, !state.tiles.contains(where: { $0.value <= 4 }) {
            lastBooster = booster
            boosterDeniedEvent += 1
            return false
        }
        if booster == .arm, !state.tiles.contains(where: { $0.kind == .normal }) {
            lastBooster = booster
            boosterDeniedEvent += 1
            return false
        }

        if let count = boosterCounts[booster], count > 0 {
            boosterCounts[booster] = count - 1
        } else {
            coins -= booster.price
        }
        lastBooster = booster
        boosterEvent += 1
        bursts.removeAll()
        isTimerRunning = true

        switch booster {
        case .flip:
            if animated {
                isAnimating = true
                Task { [weak self] in
                    await self?.rotateAnimated()
                    self?.finishMove()
                    self?.isAnimating = false
                }
            } else {
                rotateImmediately()
                finishMove()
            }
        case .sweep:
            let swept = state.tiles.filter { $0.value <= 4 }
            lastSweepCount = swept.count
            state.tiles.removeAll { $0.value <= 4 }
            for tile in swept {
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: tile.row, col: tile.col, value: tile.value))
            }
            addPoints(swept.map(\.value).reduce(0, +))
            shake(2)
            // Never leave an empty board: there would be nothing to swipe.
            while state.tiles.count < 2 {
                spawnTile()
            }
            finishMove()
        case .fever:
            isFever = true
            feverLeft = Self.feverSeconds
            feverEvent += 1
            save()
        case .arm:
            let chosen = state.tiles.filter { $0.kind == .normal }.shuffled(using: &rng).prefix(Self.armedTiles)
            let ids = Set(chosen.map(\.id))
            for index in state.tiles.indices where ids.contains(state.tiles[index].id) {
                state.tiles[index].kind = .bomb
                let tile = state.tiles[index]
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: tile.row, col: tile.col, value: 64))
            }
            lastArmCount = ids.count
            shake(1)
            save()
        }
        return true
    }

    private func shake(_ power: Int) {
        shakePower = power
        shakeEvent += 1
    }

    /// The tiles to draw: the live ones plus any being merged away this step.
    var displayTiles: [Tile] {
        state.tiles + ghosts
    }

    func isGhost(_ tile: Tile) -> Bool {
        ghosts.contains { $0.id == tile.id }
    }

    // MARK: Playing

    func swipe(_ dir: Direction) {
        guard !isAnimating, !isGameOver else { return }
        let result = GameEngine.slide(state.tiles, dir, blocked: blockedSet)
        guard result.changed else { return }

        bursts.removeAll()
        slidePulse += 1
        isTimerRunning = true
        swipeInFlight = true

        if animated {
            isAnimating = true
            Task { [weak self] in
                await self?.playAnimated(result)
            }
        } else {
            playImmediately(result)
        }
    }

    func newGame() {
        guard !isAnimating else { return }
        // Keep counting tile ids upward so the new tiles are new to the screen
        // and pop in, instead of sliding over from where old tiles sat.
        var fresh = GameState(
            tiles: [],
            score: 0,
            movesUntilRotation: GameEngine.movesPerRotation,
            nextID: state.nextID
        )
        GameEngine.spawn(in: &fresh, using: &rng, allowTime: mode == .timed)
        GameEngine.spawn(in: &fresh, using: &rng, allowTime: mode == .timed)
        state = fresh
        level = 1
        continuesUsed = 0
        paidScoreGems = 0
        paidBestBonus = false
        bestAtStart = best
        ghosts = []
        poppedIDs = []
        lastCombo = 0
        turnMerges = 0
        boardAngle = 0
        isGameOver = false
        bursts = []
        isFever = false
        feverLeft = 0
        streak = 0
        streakLeft = 0
        secondsLeft = Self.roundSeconds
        wholeSecondsLeft = Int(Self.roundSeconds)
        isTimerRunning = false
        save()
    }

    // MARK: The clock

    /// Takes time off the clock. The screen calls this several times a second.
    func tick(_ seconds: Double) {
        guard isTimerRunning, !isGameOver, seconds > 0 else { return }
        if isFever {
            feverLeft -= seconds
            if feverLeft <= 0 {
                isFever = false
            }
        }
        if streakLeft > 0 {
            streakLeft -= seconds
            if streakLeft <= 0 {
                streak = 0
            }
        }
        // Only the timed game has a clock to run down.
        guard mode == .timed, secondsLeft > 0 else { return }
        secondsLeft = max(0, secondsLeft - seconds)
        let whole = Int(secondsLeft.rounded(.up))
        if whole != wholeSecondsLeft {
            wholeSecondsLeft = whole
        }
        // A move in flight finishes first; `finishMove` then ends the game.
        if secondsLeft <= 0, !isAnimating {
            isTimerRunning = false
            isGameOver = true
            rewardFinishedGame()
            save()
        }
    }

    /// Stops the clock (the app left the screen). The next swipe starts it again.
    func pauseTimer() {
        guard isTimerRunning else { return }
        isTimerRunning = false
        save()
    }

    // MARK: The move sequence

    private func playImmediately(_ result: StepResult) {
        apply(result, isSwipe: true)
        ghosts = []
        spawnTile()
        spawnExtraTile()
        state.movesUntilRotation -= 1
        if state.movesUntilRotation <= 0 {
            rotateImmediately()
        }
        finishMove()
    }

    /// Goes up each time the Twist game changes the way the board turns.
    private(set) var directionEvent = 0

    /// Moves every tile and block to where a quarter turn puts it: to the right,
    /// or to the left when the Twist game says so.
    private func turnBoard() {
        if state.counterClockwise {
            state.tiles = GameEngine.rotateCounterClockwise(state.tiles)
            state.blocks = GameEngine.rotateCounterClockwise(state.blocks)
        } else {
            state.tiles = GameEngine.rotateClockwise(state.tiles)
            state.blocks = GameEngine.rotateClockwise(state.blocks)
        }
    }

    /// The quarter turn and the gravity that follows, with no animation (tests).
    private func rotateImmediately() {
        rotatePulse += 1
        turnBoard()
        let passes = GameEngine.settle(state.tiles, blocked: blockedSet)
        for pass in passes {
            apply(pass)
            ghosts = []
        }
        finishRotation(passes)
    }

    private func playAnimated(_ result: StepResult) async {
        withAnimation(.easeOut(duration: Timing.slide)) {
            apply(result, isSwipe: true)
        }
        await pause(Timing.slide)
        // One animated update: the merged-away tiles go, the survivors pulse,
        // the new tile arrives and the countdown ticks.
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            ghosts = []
            poppedIDs = result.mergedIDs
            spawnTile()
            spawnExtraTile()
            state.movesUntilRotation -= 1
        }
        await pause(Timing.pop)
        withAnimation(.easeOut(duration: 0.15)) {
            poppedIDs = []
        }

        if state.movesUntilRotation <= 0 {
            await pause(Timing.beforeRotation)
            await rotateAnimated()
        }

        finishMove()
        isAnimating = false
    }

    /// The quarter turn and the gravity that follows, animated.
    private func rotateAnimated() async {
        rotatePulse += 1
        withAnimation(.easeInOut(duration: Timing.rotation)) {
            boardAngle = state.counterClockwise ? -90 : 90
        }
        await pause(Timing.rotation + 0.03)
        // Swap to the turned coordinates and snap the board back upright in one
        // un-animated update: the picture on screen does not change.
        turnBoard()
        boardAngle = 0
        // Let that swap reach the screen before gravity starts animating.
        await pause(0.05)

        let passes = GameEngine.settle(state.tiles, blocked: blockedSet)
        for pass in passes {
            withAnimation(.easeIn(duration: Timing.fall)) {
                apply(pass)
            }
            await pause(Timing.fall)
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                ghosts = []
                poppedIDs = pass.mergedIDs
            }
            if !pass.mergedIDs.isEmpty {
                await pause(Timing.pop)
                withAnimation(.easeOut(duration: 0.15)) {
                    poppedIDs = []
                }
            }
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            finishRotation(passes)
        }
    }

    /// Adds points (times the current multiplier) and turns them into coins.
    private func addPoints(_ gained: Int) {
        let points = gained * scoreMultiplier
        guard points > 0 else { return }
        state.score += points
        if state.score > best {
            best = state.score
        }
        lastGain = points
        gainEvent += 1
        coinBank += points
        coins += coinBank / Self.pointsPerCoin
        coinBank %= Self.pointsPerCoin
        let score = state.score
        unlockSkins { unlock in
            if case .score(let target) = unlock {
                return score >= target
            }
            return false
        }
        let reached = GameEngine.level(forScore: score)
        if reached > level {
            level = reached
            levelEvent += 1
            if mode == .timed {
                secondsLeft = min(Self.roundSeconds, secondsLeft + Self.levelTimeBonus)
                wholeSecondsLeft = Int(secondsLeft.rounded(.up))
            }
            awardLevelPrize()
            unlockSkins { unlock in
                if case .level(let target) = unlock {
                    return reached >= target
                }
                return false
            }
        }
    }

    /// Puts a slide or a gravity pass on the board and adds its points.
    /// `isSwipe` marks the player's own slide, which is what the speed streak counts.
    private func apply(_ result: StepResult, isSwipe: Bool = false) {
        state.tiles = result.tiles
        ghosts = result.ghosts
        if isSwipe, !result.mergedIDs.isEmpty {
            // A merge soon after the last one builds the streak (and already counts
            // at the higher rate); every merge restarts the countdown.
            if streakLeft > 0 {
                streak = min(Self.maxStreak, streak + 1)
            }
            streakLeft = Self.streakWindow
        }
        let multiplier = scoreMultiplier
        addPoints(result.gained)
        // The hardest thing that happened in this step decides how the board shakes.
        var power = 0
        var bombs = 0
        for effect in result.effects {
            switch effect.kind {
            case .time:
                secondsLeft = min(Self.roundSeconds, secondsLeft + Self.timeBonus)
                wholeSecondsLeft = Int(secondsLeft.rounded(.up))
                timeBonusEvent += 1
            case .bomb:
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: effect.row, col: effect.col, value: 64, isBlast: true))
                bombs += 1
            case .normal, .stone:
                break
            }
        }
        if bombs > 0 {
            lastBombCount = bombs
            bombEvent += 1
            flashEvent += 1
            power = 3
        }
        if isSwipe, !result.mergedIDs.isEmpty {
            turnMerges += result.mergedIDs.count
            if turnMerges >= Self.heatCombo {
                heatEvent += 1
                power = max(power, turnMerges >= 5 ? 2 : 1)
            }
        }
        if !result.mergedIDs.isEmpty {
            let merged = result.tiles.filter { result.mergedIDs.contains($0.id) }
            lastMergeValue = merged.map(\.value).max() ?? 0
            for tile in merged {
                nextBurstID += 1
                bursts.append(Burst(
                    id: nextBurstID,
                    row: tile.row,
                    col: tile.col,
                    value: tile.value,
                    isSuper: result.supers[tile.id] != nil,
                    points: tile.value * multiplier,
                    heat: isSwipe ? turnMerges : 0
                ))
            }
            mergePulse += 1
            if lastMergeValue >= Self.bigMerge {
                power = max(power, 1)
            }
            if !hasMergedOnce {
                hasMergedOnce = true
                defaults.set(true, forKey: Key.merged)
            }
        }
        if let biggest = result.supers.values.max() {
            lastSuperCount = biggest
            superEvent += 1
            earnGems(biggest >= 4 ? Self.gemsForMega : Self.gemsForSuper)
            if biggest >= 4 {
                unlockSkins { $0 == .megaCombo }
            }
            flashEvent += 1
            power = max(power, 2)
        }
        let broken = GameEngine.cratesBroken(by: result, blocks: state.blocks)
        if !broken.isEmpty {
            state.blocks.removeAll { broken.contains($0) }
            for crate in broken {
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: crate.row, col: crate.col, value: 64))
            }
            lastCrateCount = broken.count
            crateEvent += 1
            addPoints(Self.cratePoints * broken.count)
            power = max(power, 2)
        }
        if power > 0 {
            shake(power)
        }
    }

    /// Adds the new tile of a move, and notes it when it is a special one.
    /// Clock tiles only make sense when there is a clock, so the endless game has none.
    private func spawnTile(forcing kind: TileKind? = nil) {
        let tile = GameEngine.spawn(
            in: &state,
            using: &rng,
            allowTime: mode == .timed,
            forcedKind: kind,
            stonesPerHundred: GameEngine.stonesPerHundred(level: level)
        )
        if let tile, tile.kind != .normal {
            lastSpecialKind = tile.kind
            specialSpawnEvent += 1
        }
    }

    /// From level 4 a move sometimes drops a second new tile, more often the higher
    /// the level. Never onto a board that is already nearly full.
    private func spawnExtraTile() {
        let chance = GameEngine.extraTilePerHundred(level: level)
        guard chance > 0, GameEngine.emptyCells(state.tiles, blocked: blockedSet).count > 2 else { return }
        if Int.random(in: 0..<100, using: &rng) < chance {
            spawnTile()
        }
    }

    private func finishRotation(_ passes: [StepResult]) {
        lastCombo = passes.filter { !$0.mergedIDs.isEmpty }.count
        if lastCombo >= Self.feverChain {
            isFever = true
            feverLeft = Self.feverSeconds
            feverEvent += 1
        }
        if lastCombo >= 2 {
            comboEvent += 1
            earnGems(Self.gemsForChain)
            shake(2)
            // A chain is rewarded with a power-up tile: a clock or a bomb in the timed
            // game, always a bomb in the endless one.
            let coin = Bool.random(using: &rng)
            let reward: TileKind = (mode == .timed && coin) ? .time : .bomb
            let before = state.tiles.count
            spawnTile(forcing: reward)
            // The reward lands with a big burst and a flash.
            if state.tiles.count > before, let tile = state.tiles.last {
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: tile.row, col: tile.col, value: 128, isSuper: true))
                flashEvent += 1
            }
        }
        // The endless game gets an extra tile after every rotation, so the board fills.
        // Every game without a clock, bar Shape Shift, gets an extra tile after a turn.
        if mode != .timed, mode != .shift {
            spawnTile()
        }
        // In the Twist game, any turn may be followed by one the other way.
        if mode == .twist, Bool.random(using: &rng) {
            state.counterClockwise.toggle()
            directionEvent += 1
        }
        state.movesUntilRotation = GameEngine.movesPerRotation
        turnMerges = 0
    }

    private func finishMove() {
        let wasSwipe = swipeInFlight
        swipeInFlight = false
        reshapeIfNeeded(afterSwipe: wasSwipe)
        if wasSwipe, mode == .fusion {
            mutateTile()
        }
        let wasOver = isGameOver
        isGameOver = !GameEngine.hasMove(state.tiles, blocked: blockedSet) || isTimeUp
        if isGameOver {
            isTimerRunning = false
            if !wasOver {
                rewardFinishedGame()
            }
        }
        save()
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }

    // MARK: Saving

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Key.state(mode))
        }
        defaults.set(best, forKey: Key.best(mode))
        if mode == .timed {
            defaults.set(secondsLeft, forKey: Key.time)
        }
        defaults.set(coins, forKey: Key.coins)
        defaults.set(gems, forKey: Key.gems)
        defaults.set(ownedSkins.sorted(), forKey: Key.skins)
        for (booster, count) in boosterCounts {
            defaults.set(count, forKey: Key.booster(booster))
        }
    }
}
