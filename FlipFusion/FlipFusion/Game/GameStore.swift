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
    static let pointsPerCoin = 50
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
        .coins(20), .gems(1), .booster(.arm), .coins(40), .gems(2), .booster(.sweep), jackpot, .booster(.fever),
    ]
    /// Goes up each time a prize is won; `lastPrize` is the prize.
    private(set) var prizeEvent = 0
    private(set) var lastPrize = Prize.coins(20)

    /// Picks the prize for a new level and hands it over. Out of 100: 40 are 50 coins,
    /// 25 are 100 coins, 15 a free booster, 14 one gem, 5 two gems and 1 the jackpot.
    private func awardLevelPrize() {
        let roll = Int.random(in: 0..<100, using: &rng)
        let prize: Prize
        if roll < 55 {
            prize = .coins(20)
        } else if roll < 80 {
            prize = .coins(40)
        } else if roll < 91 {
            prize = .booster(Booster.allCases.randomElement(using: &rng) ?? .flip)
        } else if roll < 97 {
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

    // MARK: Stages

    /// What clearing a stage wins.
    struct StageLoot: Equatable, Sendable {
        var stage = 0
        var coins = 0
        var gems = 0
        var booster: Booster?
        /// One to three, for the time left on the clock.
        var stars = 0
        /// Every fifth stage is a big chest.
        var isChest = false
        /// How many stages in a row have been cleared, this one included.
        var streak = 0
        /// What clearing this stage opened, in words, or nil.
        var opened: String?
        /// Coins for the time or the moves left over.
        var bonus = 0
        /// Coins out of the jar, which opens at a chest stage.
        var jar = 0
        /// A star chest, when this stage's stars reached one.
        var starCoins = 0
        var starGems = 0
    }

    // MARK: The coin jar, winning runs and star chests

    /// Every coin scored in the stage game drops another into the jar. It opens at
    /// each chest stage.
    private(set) var jar = 0
    static let jarLimit = 500
    /// Coins for each move left over when a stage played against moves is cleared.
    static let coinsPerMoveLeft = 5

    /// A winning run starts each stage with a bomb; a run of five, with two.
    nonisolated static func streakBombs(_ streak: Int) -> Int {
        streak >= 5 ? 2 : (streak >= 3 ? 1 : 0)
    }

    /// The star totals that open a star chest, and what each chest holds.
    static let starMarks = [10, 25, 50, 100, 150, 200]
    static let starCoins = [150, 300, 500, 800, 1000, 1500]
    static let starGems = [3, 5, 8, 12, 15, 20]
    /// How many star chests have been opened.
    private(set) var starChests = 0

    var starTotal: Int { stageStars.reduce(0, +) }

    /// The star total of the next star chest, or nil when all are open.
    var nextStarMark: Int? {
        starChests < Self.starMarks.count ? Self.starMarks[starChests] : nil
    }

    /// The stage of the two-minute game the player is on. Every stage has a score
    /// to reach before the clock runs out; reaching it wins loot and opens the next,
    /// harder one. Missing it means trying the same stage again.
    private(set) var stage: Int
    /// Stages cleared in a row without a miss. A run of them pays more coins.
    private(set) var stageStreak: Int
    /// True once this game has reached its stage's score.
    private(set) var isStageWon = false
    /// Goes up each time a stage is cleared; `lastLoot` is what it won.
    private(set) var stageEvent = 0
    private(set) var lastLoot = StageLoot()
    @ObservationIgnored private var stagePaid = false

    /// What a stage asks for. Stages take turns, so no two in a row play alike.
    enum StageGoal: Equatable, Sendable {
        /// Reach a score before the clock runs out.
        case score(Int)
        /// Make a tile this big before the clock runs out.
        case tile(Int)
        /// Make this many merges before the clock runs out.
        case merges(Int)
        /// Make this many chains: merges that follow one another as the board turns.
        case chains(Int)
        /// Reach a score in a number of moves. There is no clock.
        case moves(score: Int, moves: Int)
    }

    /// True for the stages played against a count of moves, with no clock.
    nonisolated static func isMovesStage(_ stage: Int) -> Bool {
        stage >= 4 && stage % 5 != 0 && stage % 4 == 2
    }

    /// The goal of a stage. The first three are plain scores, to learn on; every
    /// fifth (a chest stage) is a score too; the rest take turns.
    nonisolated static func goal(forStage stage: Int) -> StageGoal {
        let score = stageGoal(stage)
        if stage < 4 || stage % 5 == 0 || isBossStage(stage) {
            return .score(score)
        }
        switch stage % 4 {
        case 0:
            return .merges(min(70, 16 + 2 * stage))
        case 1:
            return .tile(stage < 12 ? 128 : (stage < 28 ? 256 : 512))
        case 2:
            return .moves(score: max(300, score / 4 / 50 * 50), moves: min(80, 36 + stage))
        default:
            return .chains(min(8, 2 + stage / 6))
        }
    }

    /// A goal as a sentence: "Reach 1,200 points".
    nonisolated static func goalWords(_ goal: StageGoal) -> String {
        switch goal {
        case .score(let score):
            return "Reach " + score.formatted(.number.grouping(.automatic)) + " points"
        case .tile(let value):
            return "Make a \(value) tile"
        case .merges(let count):
            return "Make \(count) merges"
        case .chains(let count):
            return "Make \(count) chains"
        case .moves(let score, let moves):
            return "Score " + score.formatted(.number.grouping(.automatic)) + " in \(moves) moves"
        }
    }

    /// What a tile is called in a stage: its number in the first world, its picture
    /// in the worlds that show pictures.
    nonisolated static func tileName(_ value: Int, stage: Int) -> String {
        let theme = worldSkin(world(ofStage: stage))
        return theme == "neon" ? String(value) : Fruit.face(for: value, theme: theme)
    }

    /// A stage's goal as a sentence, and in a word or two.
    nonisolated static func goalWords(forStage stage: Int) -> String {
        let goal = goal(forStage: stage)
        if case .tile(let value) = goal {
            return "Make a " + tileName(value, stage: stage) + " tile"
        }
        return goalWords(goal)
    }

    nonisolated static func goalShort(forStage stage: Int) -> String {
        let goal = goal(forStage: stage)
        if case .tile(let value) = goal {
            return tileName(value, stage: stage) + " tile"
        }
        return goalShort(goal)
    }

    /// A goal in a word or two, for the stage map.
    nonisolated static func goalShort(_ goal: StageGoal) -> String {
        switch goal {
        case .score(let score):
            return score.formatted(.number.grouping(.automatic))
        case .tile(let value):
            return "\(value) tile"
        case .merges(let count):
            return "\(count) merges"
        case .chains(let count):
            return "\(count) chains"
        case .moves(let score, let moves):
            return score.formatted(.number.grouping(.automatic)) + " in \(moves)"
        }
    }

    /// A line of teaching for the first three stages, or nil.
    nonisolated static func stageHint(_ stage: Int) -> String? {
        switch stage {
        case 1: return "Swipe to slide the tiles. Two the same merge!"
        case 2: return "Every 2 moves the board turns and the tiles fall"
        case 3: return "Stuck? Tap a booster under the board"
        default: return nil
        }
    }

    /// What reaching a stage opens, in words, or nil.
    nonisolated static func opens(atStage stage: Int) -> String? {
        switch stage {
        case 5: return "Endless game unlocked! Find it in the menu"
        case 8: return "Fruit Salad game unlocked! Find it in the menu"
        case 10: return "Head to head unlocked! Tap the two players up top"
        default: return nil
        }
    }

    /// The merges or chains made in this game, or its biggest tile, whichever the
    /// stage is counting.
    private(set) var stageCount = 0
    /// Moves left in a stage played against a count of moves.
    private(set) var movesLeft = 0

    /// The stage of the game on the board: the one just cleared, until the next begins.
    var playedStage: Int { stagePaid ? max(1, stage - 1) : stage }
    var playedGoal: StageGoal { Self.goal(forStage: playedStage) }

    var isMovesGoal: Bool {
        if case .moves = playedGoal {
            return true
        }
        return false
    }

    /// How far the game has come toward its goal, and how far it has to go.
    var stageProgress: Int {
        switch playedGoal {
        case .score, .moves: return state.score
        case .tile, .merges, .chains: return stageCount
        }
    }

    var stageTarget: Int {
        switch playedGoal {
        case .score(let score): return score
        case .tile(let value): return value
        case .merges(let count): return count
        case .chains(let count): return count
        case .moves(let score, _): return score
        }
    }

    /// The same as a share from 0 to 1. Tiles double, so a 64 is most of the way to a 128.
    var stageFraction: Double {
        let target = Double(max(1, stageTarget))
        if case .tile = playedGoal {
            return min(1, log2(Double(max(1, stageCount))) / max(1, log2(target)))
        }
        return min(1, max(0, Double(stageProgress) / target))
    }

    /// True while a clock is running the game down.
    var hasClock: Bool { mode == .timed && !(hasStages && isMovesGoal) }

    /// True when a stage played against a count of moves has used them all.
    var isOutOfMoves: Bool { hasStages && !isStageWon && isMovesGoal && movesLeft <= 0 }

    /// The score that clears the stage being played, when it is a score that does.
    private var scoreTarget: Int? {
        switch Self.goal(forStage: stage) {
        case .score(let score): return score
        case .moves(let score, _): return score
        case .tile, .merges, .chains: return nil
        }
    }

    /// Counts what the stage is asking for, and clears the stage when there is enough.
    private func advanceStage(merges: Int = 0, chains: Int = 0, tile: Int = 0) {
        guard hasStages, !isStageWon else { return }
        let target: Int
        switch Self.goal(forStage: stage) {
        case .score, .moves:
            return
        case .tile(let value):
            stageCount = max(stageCount, tile)
            target = value
        case .merges(let count):
            stageCount += merges
            target = count
        case .chains(let count):
            stageCount += chains
            target = count
        }
        if stageCount >= target {
            isStageWon = true
        }
    }

    /// A move in a stage played against a count of moves uses one up.
    private func spendStageMove() {
        if hasStages, !isStageWon, Self.isMovesStage(stage) {
            movesLeft -= 1
        }
    }

    /// What makes a stage play differently from the one before it.
    enum Twist: String, Sendable {
        case plain
        /// A rest after hard stages: a lower score to reach and a bomb to start with.
        case breather
        /// Two blockers are on the board from the start.
        case rocky
        /// The board turns after every move.
        case quickTurn
        /// Less time on the clock.
        case sprint
    }

    /// A sprint stage's clock.
    static let sprintSeconds: Double = 90

    /// The twist of a stage. The first two are plain; every fourth is a breather;
    /// every fifth is a plain stage with a big chest; the rest take turns.
    nonisolated static func twist(forStage stage: Int) -> Twist {
        if stage < 3 { return .plain }
        // A boss is twist enough.
        if isBossStage(stage) { return .plain }
        if stage % 4 == 0 { return .breather }
        if stage % 5 == 0 { return .plain }
        switch stage % 3 {
        case 0: return .rocky
        case 1: return stage >= 7 ? .quickTurn : .plain
        // A stage with no clock cannot be a sprint.
        default: return stage >= 6 && !isMovesStage(stage) ? .sprint : .plain
        }
    }

    /// The twist of the game being played.
    var twist: Twist { hasStages ? Self.twist(forStage: stage) : .plain }

    /// A twist in a few words, or nil for a plain stage.
    nonisolated static func twistWords(_ twist: Twist) -> String? {
        switch twist {
        case .plain: return nil
        case .breather: return "Breather: an easier goal and a free bomb"
        case .rocky: return "Rocky start: two blockers on the board"
        case .quickTurn: return "The board turns after every move"
        case .sprint: return "Sprint: only 90 seconds"
        }
    }

    /// The stars won on each stage cleared so far, stage 1 first.
    private(set) var stageStars: [Int]

    // MARK: The daily chest

    /// What the daily chest holds. It grows over seven days in a row, then starts again.
    struct DailyGift: Equatable, Sendable {
        var day = 1
        var coins = 0
        var gems = 0
        var booster: Booster?
    }

    /// Days in a row the chest has been opened.
    private(set) var dailyStreak: Int
    /// Goes up each time the chest is opened; `lastGift` is what was in it.
    private(set) var dailyEvent = 0
    private(set) var lastGift = DailyGift()

    /// A number that goes up by one each calendar day.
    nonisolated static func dayNumber(_ date: Date = Date()) -> Int {
        Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    /// The chest of day 1 to 7 of a run.
    nonisolated static func dailyGift(day: Int) -> DailyGift {
        let index = min(7, max(1, day))
        let coins = [30, 40, 50, 60, 80, 100, 150][index - 1]
        var gift = DailyGift(day: index, coins: coins, gems: index == 7 ? 5 : (index >= 4 ? 1 : 0))
        if index == 3 {
            gift.booster = .sweep
        } else if index == 7 {
            gift.booster = .arm
        }
        return gift
    }

    /// True when today's chest has not been opened yet.
    func isDailyReady(today: Int = GameStore.dayNumber()) -> Bool {
        defaults.integer(forKey: Key.dailyDay) != today
    }

    /// Which day of the run today's chest is: the next one when yesterday's was
    /// opened, otherwise day 1 again.
    func dailyDay(today: Int = GameStore.dayNumber()) -> Int {
        defaults.integer(forKey: Key.dailyDay) == today - 1 ? dailyStreak % 7 + 1 : 1
    }

    /// Opens today's chest. Returns nil when it has been opened already.
    @discardableResult
    func claimDaily(today: Int = GameStore.dayNumber()) -> DailyGift? {
        guard isDailyReady(today: today) else { return nil }
        let day = dailyDay(today: today)
        let gift = Self.dailyGift(day: day)
        dailyStreak = defaults.integer(forKey: Key.dailyDay) == today - 1 ? dailyStreak + 1 : 1
        coins += gift.coins
        gems += gift.gems
        if let booster = gift.booster {
            boosterCounts[booster, default: 0] += 1
        }
        lastGift = gift
        dailyEvent += 1
        defaults.set(today, forKey: Key.dailyDay)
        defaults.set(dailyStreak, forKey: Key.dailyStreak)
        save()
        return gift
    }

    // MARK: Daily quests

    /// What a quest counts.
    enum QuestKind: String, CaseIterable, Sendable {
        case merges, chains, stages, boosters, bigTile
    }

    /// One of the day's three small jobs. Doing it earns coins to collect.
    struct Quest: Equatable, Identifiable, Sendable {
        let kind: QuestKind
        let target: Int
        let coins: Int

        var id: String { kind.rawValue }

        var words: String {
            switch kind {
            case .merges: return "Make \(target) merges"
            case .chains: return "Make \(target) chains"
            case .stages: return target == 1 ? "Clear a stage" : "Clear \(target) stages"
            case .boosters: return "Use \(target) boosters"
            case .bigTile: return "Make a \(target) tile"
            }
        }
    }

    /// Collecting all three of a day's quests adds this many coins, and a gem.
    static let questBonus = 100

    /// The three quests of a day. They change every day.
    nonisolated static func quests(day: Int) -> [Quest] {
        let kinds = QuestKind.allCases
        var list: [Quest] = []
        for index in 0..<3 {
            switch kinds[(abs(day) + index) % kinds.count] {
            case .merges: list.append(Quest(kind: .merges, target: 60, coins: 40))
            case .chains: list.append(Quest(kind: .chains, target: 4, coins: 40))
            case .stages: list.append(Quest(kind: .stages, target: 2, coins: 50))
            case .boosters: list.append(Quest(kind: .boosters, target: 2, coins: 30))
            case .bigTile: list.append(Quest(kind: .bigTile, target: 128, coins: 40))
            }
        }
        return list
    }

    /// Today's day number. The tests put their own day here.
    @ObservationIgnored var today: () -> Int = { GameStore.dayNumber() }

    private(set) var questCounts = [0, 0, 0]
    private(set) var questClaimed = [false, false, false]
    private(set) var questDay = 0
    /// Goes up each time a quest is finished.
    private(set) var questEvent = 0
    private(set) var lastQuestWords = ""

    var quests: [Quest] { Self.quests(day: today()) }

    /// How far each of today's quests has come.
    var questProgress: [Int] { questDay == today() ? questCounts : [0, 0, 0] }

    /// Which of today's quests have been collected.
    var questsCollected: [Bool] { questDay == today() ? questClaimed : [false, false, false] }

    /// How many finished quests are waiting to be collected.
    var questsWaiting: Int {
        let list = quests
        let counts = questProgress
        let claimed = questsCollected
        var waiting = 0
        for index in 0..<3 where counts[index] >= list[index].target && !claimed[index] {
            waiting += 1
        }
        return waiting
    }

    private func saveQuests() {
        defaults.set(questDay, forKey: Key.questDay)
        defaults.set(questCounts, forKey: Key.questCounts)
        defaults.set(questClaimed, forKey: Key.questClaimed)
    }

    /// Counts something toward today's quests.
    private func noteQuest(_ kind: QuestKind, _ amount: Int) {
        guard amount > 0 else { return }
        let day = today()
        if questDay != day {
            questDay = day
            questCounts = [0, 0, 0]
            questClaimed = [false, false, false]
        }
        let list = Self.quests(day: day)
        guard let index = list.firstIndex(where: { $0.kind == kind }) else { return }
        let quest = list[index]
        guard questCounts[index] < quest.target else { return }
        questCounts[index] = kind == .bigTile ? max(questCounts[index], amount) : questCounts[index] + amount
        if questCounts[index] >= quest.target {
            lastQuestWords = "Quest done: " + quest.words
            questEvent += 1
        }
        saveQuests()
    }

    /// Collects a finished quest's coins. The third one of the day adds the bonus.
    /// Returns false (and changes nothing) when there is nothing to collect.
    @discardableResult
    func claimQuest(_ index: Int) -> Bool {
        let list = quests
        guard index >= 0, index < 3, questDay == today(),
              questCounts[index] >= list[index].target, !questClaimed[index]
        else { return false }
        questClaimed[index] = true
        coins += list[index].coins
        if !questClaimed.contains(false) {
            coins += Self.questBonus
            earnGems(1)
        }
        saveQuests()
        save()
        return true
    }

    /// The two-minute game is played in stages; a head-to-head game is not.
    var hasStages: Bool { mode == .timed && !isVersus }

    /// The score that clears a score stage: 250, 750, 1,200, 1,750 and on up.
    nonisolated static func stageGoal(_ stage: Int) -> Int {
        // The first stage is a quick win.
        if stage <= 1 {
            return 250
        }
        let steps = max(1, stage) - 1
        let goal = 400 + 300 * steps + 50 * steps * steps
        // A boss fights back, so its stage asks for a fifth less.
        if isBossStage(stage) {
            return (goal * 4 / 5) / 50 * 50
        }
        // A breather asks for a quarter less, to the nearest 50.
        return twist(forStage: stage) == .breather ? (goal * 3 / 4) / 50 * 50 : goal
    }

    /// The score this game has to reach.
    var stageGoal: Int { Self.stageGoal(stage) }

    /// The coins and gems a stage pays, before stars and streaks. Later stages pay
    /// more, and every fifth stage is a big chest.
    nonisolated static func stageLoot(_ stage: Int) -> StageLoot {
        let isChest = stage > 0 && stage % 5 == 0
        let coins = min(300, 30 + 15 * stage)
        let gems = min(8, 1 + stage / 3)
        // A boss pays like a chest.
        let isBig = isChest || isBossStage(stage)
        return StageLoot(stage: stage, coins: isBig ? coins * 2 : coins, gems: isBig ? gems + 3 : gems, isChest: isChest)
    }

    /// Stars for the time left when the stage was cleared.
    nonisolated static func stageStars(secondsLeft: Double) -> Int {
        secondsLeft >= 60 ? 3 : (secondsLeft >= 25 ? 2 : 1)
    }

    /// How hard the board plays: the level of this game, raised by the stage.
    private var hazardLevel: Int {
        level + (hasStages && twist != .breather ? (stage - 1) / 2 : 0)
    }

    /// Hands over the loot of the stage just cleared and opens the next one.
    private func winStage() {
        guard !stagePaid else { return }
        stagePaid = true
        var loot = Self.stageLoot(stage)
        if case .moves(_, let moves) = Self.goal(forStage: stage) {
            // No clock: the stars are for the moves left over.
            loot.stars = movesLeft * 3 >= moves ? 3 : (movesLeft * 6 >= moves ? 2 : 1)
        } else {
            loot.stars = Self.stageStars(secondsLeft: secondsLeft)
        }
        stageStreak += 1
        loot.streak = stageStreak
        // Three stars pay half as much again; a winning run adds a tenth a stage, up to half.
        var percent = 100 + 10 * min(5, stageStreak - 1)
        if loot.stars == 3 {
            percent += 50
        } else if loot.stars == 2 {
            percent += 20
        }
        loot.coins = loot.coins * percent / 100
        // What was left on the clock, or of the moves, is paid out in coins.
        if case .moves = Self.goal(forStage: stage) {
            loot.bonus = max(0, movesLeft) * Self.coinsPerMoveLeft
        } else {
            loot.bonus = Int(max(0, secondsLeft)) / 2
        }
        if loot.isChest {
            loot.jar = jar
            jar = 0
        }
        let booster = Booster.allCases.randomElement(using: &rng) ?? .flip
        loot.booster = booster
        coins += loot.coins + loot.bonus + loot.jar
        gems += loot.gems
        boosterCounts[booster, default: 0] += loot.isChest ? 2 : 1
        lastLoot = loot
        while stageStars.count < stage {
            stageStars.append(0)
        }
        stageStars[stage - 1] = max(stageStars[stage - 1], loot.stars)
        defaults.set(stageStars, forKey: Key.stageStars)
        // Enough stars open a star chest.
        let total = stageStars.reduce(0, +)
        while starChests < Self.starMarks.count, total >= Self.starMarks[starChests] {
            lastLoot.starCoins += Self.starCoins[starChests]
            lastLoot.starGems += Self.starGems[starChests]
            coins += Self.starCoins[starChests]
            gems += Self.starGems[starChests]
            starChests += 1
        }
        defaults.set(starChests, forKey: Key.starChests)
        noteQuest(.stages, 1)
        stage += 1
        lastLoot.opened = Self.opens(atStage: stage)
        // The last stage of a world opens the next world, and its theme with it.
        let world = Self.world(ofStage: stage)
        if world != Self.world(ofStage: stage - 1) {
            let skin = Skin.named(Self.worldSkin(world))
            if world < Self.worldSkins.count, !owns(skin) {
                ownedSkins.insert(skin.id)
            }
            lastWorldSkin = skin.id
            worldEvent += 1
            if lastLoot.opened == nil {
                lastLoot.opened = "New world! The " + skin.name + " theme is yours"
            }
        }
        stageEvent += 1
        defaults.set(stage, forKey: Key.stage)
        defaults.set(stageStreak, forKey: Key.stageStreak)
        defaults.set(true, forKey: Key.stageWon)
    }

    /// A stage was missed: the winning run is over.
    private func loseStage() {
        guard hasStages, !isStageWon, stageStreak != 0 else { return }
        stageStreak = 0
        defaults.set(0, forKey: Key.stageStreak)
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

    /// The holes that swallow tiles. The outlines of the Shape Shift game are cut
    /// from holes too, but those are the edge of the board and swallow nothing.
    private var holeSet: Set<Cell> {
        guard GameEngine.silhouetteName(state.shapeID) == nil else { return [] }
        return Set(state.blocks.filter { $0.kind == .hole }.map(\.cell))
    }

    /// A board has at most this many holes that swallow tiles.
    static let maxHoles = 2
    /// A hole closes up once it has swallowed this many tiles.
    static let holeAppetite = 3
    /// Goes up each time a hole swallows something; `lastSwallowCount` is how many.
    private(set) var swallowEvent = 0
    private(set) var lastSwallowCount = 0
    /// Goes up each time a hole has had its fill and closes.
    private(set) var holeClosedEvent = 0
    /// The value of every tile lost down a hole since the app started (tests).
    private(set) var swallowedValue = 0

    /// Tiles have fallen down holes: each hole counts what it ate and closes when full.
    /// The tiles going down a hole in the step being shown: the board draws them
    /// spinning and shrinking as they slide in.
    private(set) var swallowedIDs: Set<Int> = []

    private func feedHoles(_ fallen: [Tile]) {
        for tile in fallen {
            swallowedValue += tile.value
            guard let at = state.blocks.firstIndex(where: { $0.kind == .hole && $0.row == tile.row && $0.col == tile.col }) else { continue }
            let eaten = (state.blocks[at].fed ?? 0) + 1
            if eaten >= Self.holeAppetite {
                state.blocks.remove(at: at)
                holeClosedEvent += 1
            } else {
                state.blocks[at].fed = eaten
            }
        }
        lastSwallowCount = fallen.count
        swallowEvent += 1
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
        // Holes swallow tiles, so a board has two at most: any more open on it are
        // left out. The outlines of the Shape Shift game are all holes and keep them.
        if GameEngine.silhouetteName(index) == nil {
            var holes = 0
            blocks.removeAll { block in
                guard block.kind == .hole else { return false }
                holes += 1
                return holes > Self.maxHoles
            }
        }
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
    private func scatterTiles(dropping drop: Int, chewing bites: Int = 0) {
        func scatter() {
            // A bite out of the board: a cell becomes a hole until the board next
            // changes shape. Never on a board that already has its fill of obstacles.
            var bitten = 0
            for _ in 0..<bites where state.blocks.count < GameEngine.maxBlocks {
                // Two holes on a board are plenty.
                guard state.blocks.filter({ $0.kind == .hole }).count < Self.maxHoles else { break }
                guard let cell = GameEngine.emptyCells([], blocked: blockedSet).randomElement(using: &rng) else { break }
                state.blocks.append(Block(row: cell.row, col: cell.col, kind: .hole))
                bitten += 1
            }
            lastChewCount = bitten
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
    func stirBoard(dropping drop: Int = 2, chewing bites: Int = 1) -> Bool {
        guard !isAnimating, !isGameOver, state.tiles.count > 1 else { return false }
        bursts.removeAll()
        scatterTiles(dropping: drop, chewing: bites)
        finishMove()
        return true
    }

    // MARK: Wild weather

    /// What a theme's weather can do to the board, in the themes that have any.
    enum Storm: Equatable, Sendable {
        /// Rainforest: a downpour washes every tile to a new cell.
        case downpour
        /// Jurassic: a falling star smashes a tile and leaves a crater.
        case meteors
        /// Galaxy: an asteroid shower knocks two tiles off the board.
        case asteroids
        /// Frost: a blizzard blows every tile to a new cell.
        case blizzard
        /// Lava: the volcano throws two lumps of rock onto the board.
        case eruption
    }

    nonisolated static func storm(forTheme id: String) -> Storm? {
        switch id {
        case "rainforest": return .downpour
        case "jurassic": return .meteors
        case "galaxy": return .asteroids
        case "frost": return .blizzard
        case "lava": return .eruption
        default: return nil
        }
    }

    /// Goes up each time the weather hits the board; `lastStorm` is what it was.
    private(set) var stormEvent = 0
    private(set) var lastStorm = Storm.downpour
    /// The weather's chance, in a hundred, of turning on the board at a big moment.
    static let stormPerHundred = 25

    /// Asks whether the theme's weather turns on the board now. Like the shark, it
    /// is rare: once a game at most, and then one time in four that it could.
    func stormComes() -> Bool {
        guard !sharkHasCome, !isGameOver, Self.storm(forTheme: Skin.current.id) != nil else { return false }
        guard Int.random(in: 0..<100, using: &rng) < Self.stormPerHundred else { return false }
        sharkHasCome = true
        return true
    }

    /// The weather hits the board. Returns false, and does nothing, while a move is
    /// still playing, the game is over, or the theme has no weather. `forcing`
    /// picks the weather whatever the theme (tests).
    @discardableResult
    func stormStrikes(forcing forced: Storm? = nil) -> Bool {
        guard !isAnimating, !isGameOver, state.tiles.count > 1,
              let storm = forced ?? Self.storm(forTheme: Skin.current.id)
        else { return false }
        bursts.removeAll()
        switch storm {
        case .downpour, .blizzard:
            scatterTiles(dropping: 0)
        case .meteors:
            scatterTiles(dropping: 1, chewing: 1)
        case .asteroids:
            scatterTiles(dropping: 2)
        case .eruption:
            spawnTile(forcing: .stone)
            spawnTile(forcing: .stone)
            shake(3)
        }
        lastStorm = storm
        stormEvent += 1
        finishMove()
        return true
    }

    /// How many cells the shark bit out of the board last time.
    private(set) var lastChewCount = 0

    /// True once the Ocean theme's shark has come in this game: it comes once at most.
    @ObservationIgnored private var sharkHasCome = false
    /// The shark's chance, in a hundred, of coming when the game earns a big moment.
    static let sharkPerHundred = 20

    /// Asks whether the Ocean theme's shark comes now. It is rare on purpose: once a
    /// game at most, and then only one time in five that it could.
    func sharkComes() -> Bool {
        guard !sharkHasCome, !isGameOver else { return false }
        guard Int.random(in: 0..<100, using: &rng) < Self.sharkPerHundred else { return false }
        sharkHasCome = true
        return true
    }

    /// How many tiles the flying saucer took, or the T-rex stamped on, last time.
    private(set) var lastHazardCount = 0

    /// The flying saucer beams up `count` tiles picked at random, never leaving
    /// fewer than two on the board.
    private(set) var lastAbducted: [Tile] = []

    private func abductTiles(_ count: Int) {
        let take = max(0, min(count, state.tiles.count - 2))
        let chosen = state.tiles.shuffled(using: &rng).prefix(take)
        let gone = Set(chosen.map(\.id))
        // The screen shows these rising up the beam, from where they stood.
        lastAbducted = Array(chosen)
        if animated {
            withAnimation(.easeIn(duration: 0.3)) {
                state.tiles.removeAll { gone.contains($0.id) }
            }
        } else {
            state.tiles.removeAll { gone.contains($0.id) }
        }
        lastHazardCount = chosen.count
        shake(2)
    }

    /// The T-rex stamps on up to `count` ordinary tiles worth 4 or more, picked at
    /// random: each drops to half its value.
    private func stompTiles(_ count: Int) {
        let picks = state.tiles.indices
            .filter { state.tiles[$0].kind == .normal && state.tiles[$0].value >= 4 }
            .shuffled(using: &rng)
            .prefix(count)
        for index in picks {
            state.tiles[index].value /= 2
            let tile = state.tiles[index]
            nextBurstID += 1
            bursts.append(Burst(id: nextBurstID, row: tile.row, col: tile.col, value: tile.value, isBlast: true))
        }
        lastHazardCount = picks.count
        shake(3)
    }

    /// Shakes the board. The creatures on screen call this in time with each bite,
    /// landing and stomp.
    func rattle(_ power: Int = 2) {
        shake(min(3, max(1, power)))
    }

    /// Throws the tiles to new cells without taking any: the monkey does this as it
    /// bounces about. Does nothing while a move is playing or the game is over.
    @discardableResult
    func jumble() -> Bool {
        guard !isAnimating, !isGameOver, state.tiles.count > 1 else { return false }
        scatterTiles(dropping: 0)
        save()
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

        /// True for the animals and aliens.
        var isCreature: Bool {
            switch self {
            case .monkey, .shark, .ufo, .trex, .beast: return true
            default: return false
            }
        }

        /// One of the creatures that belong to a single theme: the robot, the crab,
        /// the gum monster, the dragon, the yeti, the mole or the pinata.
        case beast(Critter)
        /// A flying saucer hovers over the board and its aliens beam two tiles up.
        case ufo
        /// A T-rex stamps across, mixing the tiles up and stamping three down a size.
        case trex
        /// Two stone blocks fall onto the board.
        case stones

        /// True for the finds the player is glad of.
        var isPrize: Bool {
            switch self {
            case .monkey, .shark, .ufo, .trex, .stones: return false
            // The pinata is the one creature that is good news.
            case .beast(let kind): return kind == .pinata
            default: return true
            }
        }
    }

    /// Goes up each time a crate is opened; `lastCrateFind` is what was in it.
    private(set) var crateOpenEvent = 0
    private(set) var lastCrateFind = CrateFind.coins(100)

    /// Picks what is in a crate. Out of 100: 22 are 100 coins, 12 a gem, 12 a free
    /// booster, 8 double points, 8 ten seconds (100 coins when there is no clock);
    /// then 12 a monkey, 9 a shark, 6 a flying saucer, 6 a T-rex and 5 two stone blocks.
    /// After a creature comes out of a crate, this many crates hold none.
    static let creatureRest = 4
    /// Crates opened since the last creature.
    @ObservationIgnored private var cratesSinceCreature = GameStore.creatureRest

    private func rollCrate() -> CrateFind {
        let roll = Int.random(in: 0..<100, using: &rng)
        switch roll {
        case ..<26: return .coins(100)
        case ..<40: return .gem
        case ..<54: return .booster(Booster.allCases.randomElement(using: &rng) ?? .flip)
        case ..<64: return .fever
        case ..<74: return mode == .timed ? .time : .coins(100)
        case ..<92: break
        default: return .stones
        }
        // A creature: 18 crates in 100 hold one, and never one of the next few crates
        // after a creature has been out, so they stay a surprise.
        guard cratesSinceCreature >= Self.creatureRest else { return .coins(100) }
        return Self.creatures(forTheme: Skin.current.id).randomElement(using: &rng) ?? .coins(100)
    }

    /// The creatures that live in a theme's crates: the shark in the sea, the flying
    /// saucer in space. Themes with no creature of their own yet share the monkey
    /// and the T-rex.
    nonisolated static func creatures(forTheme id: String) -> [CrateFind] {
        switch id {
        case "ocean": return [.shark]
        case "galaxy": return [.ufo]
        case "rainforest": return [.monkey]
        case "jurassic": return [.trex]
        case "neon": return [.beast(.robot)]
        case "sunset": return [.beast(.crab)]
        case "bubblegum": return [.beast(.gummy)]
        case "lava": return [.beast(.dragon)]
        case "frost": return [.beast(.yeti)]
        case "gold": return [.beast(.mole)]
        case "party": return [.beast(.pinata)]
        default: return [.monkey]
        }
    }

    /// Coins the pinata showers when it bursts.
    static let pinataCoins = 150

    /// What each theme's own creature does to the board.
    private func unleash(_ kind: Critter) {
        switch kind {
        case .robot:
            // It wires up two ordinary tiles as bombs.
            let picks = state.tiles.indices
                .filter { state.tiles[$0].kind == .normal }
                .shuffled(using: &rng)
                .prefix(2)
            for index in picks {
                state.tiles[index].kind = .bomb
                let tile = state.tiles[index]
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: tile.row, col: tile.col, value: 64))
            }
            lastHazardCount = picks.count
            shake(2)
        case .crab:
            // It pinches one tile and scuttles through the rest.
            scatterTiles(dropping: 1)
        case .gummy:
            // It leaves two sticky lumps that will not merge.
            spawnTile(forcing: .stone)
            spawnTile(forcing: .stone)
            shake(2)
        case .dragon:
            // It burns three tiles away.
            scatterTiles(dropping: 3)
        case .yeti:
            // It stamps four tiles down a size.
            stompTiles(4)
        case .mole:
            // It digs two holes in the board.
            scatterTiles(dropping: 0, chewing: 2)
        case .pinata:
            // It bursts: coins and a gem, and the tiles are thrown about.
            coins += Self.pinataCoins
            gems += 1
            scatterTiles(dropping: 0)
        case .shark, .monkey, .ufo, .trex:
            break
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
        spendStageMove()
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
            scatterTiles(dropping: 2, chewing: 1)
        case .ufo:
            abductTiles(2)
        case .trex:
            // It throws the tiles about, bites a piece out of the board and stamps
            // three tiles down.
            scatterTiles(dropping: 0, chewing: 1)
            stompTiles(3)
        case .stones:
            spawnTile(forcing: .stone)
            spawnTile(forcing: .stone)
            shake(2)
        case .beast(let kind):
            unleash(kind)
        }
        lastCrateFind = find
        crateOpenEvent += 1
        cratesSinceCreature = find.isCreature ? 0 : cratesSinceCreature + 1

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
    static let continueMoves = 10
    private(set) var continuesUsed = 0
    /// Goes up each time a finished game is carried on.
    private(set) var continueEvent = 0

    /// True when the game has ended and has not been carried on yet.
    var canContinue: Bool {
        isGameOver && !isAnimating && continuesUsed == 0 && state.score > 0 && !isVersus && !isStageWon
    }

    // MARK: Head to head

    /// True while a head-to-head game against another player is on. Such a game
    /// cannot be carried on with gems: both players get the same two minutes.
    private(set) var isVersus = false

    /// Starts a head-to-head game: the two-minute game, from the tiles both players
    /// were dealt, with the clock running from the start.
    func startVersus(with dealt: [Tile]) {
        if mode != .timed {
            switchMode(.timed)
        }
        newGame()
        // No stage twist in a head-to-head game: both players get the plain game.
        state.movesUntilRotation = GameEngine.movesPerRotation
        state.tiles.removeAll { $0.kind == .stone || $0.kind == .bomb }
        secondsLeft = Self.roundSeconds
        wholeSecondsLeft = Int(Self.roundSeconds)
        var next = state.nextID
        var tiles: [Tile] = []
        for tile in dealt {
            tiles.append(Tile(id: next, value: tile.value, row: tile.row, col: tile.col, kind: tile.kind))
            next += 1
        }
        if !tiles.isEmpty {
            state.tiles = tiles
            state.nextID = next
        }
        isVersus = true
        isTimerRunning = true
        save()
    }

    /// Ends the head-to-head game; the board is left as it is.
    func endVersus() {
        isVersus = false
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
        if isOutOfMoves {
            movesLeft = Self.continueMoves
        }
        if !GameEngine.hasMove(state.tiles, blocked: blockedSet, holes: holeSet) {
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
    static let gemsForSuper = 0
    static let gemsForMega = 1
    static let gemsForChain = 1
    /// At the end of a game: one gem for every this many points, and more for a new best.
    static let pointsPerGem = 2000
    static let gemsForBest = 1

    /// The Shape Shift game opens with the player's first theme beyond the free one,
    /// bought or won.
    func isUnlocked(_ mode: Mode) -> Bool {
        Self.isOpen(mode, stage: stage, themes: ownedSkins.count)
    }

    /// A game is open once the player has reached its stage and has its themes.
    nonisolated static func isOpen(_ mode: Mode, stage: Int, themes: Int) -> Bool {
        stage >= stageNeeded(for: mode) && themes >= themesNeeded(for: mode)
    }

    /// The stage a game opens at: the stage game is all there is to begin with.
    nonisolated static func stageNeeded(for mode: Mode) -> Int {
        switch mode {
        case .endless: return 5
        case .fruit: return 8
        case .timed, .shift, .twist, .fusion: return 1
        }
    }

    // MARK: Bosses

    /// What a boss does to the board when its turn comes.
    enum BossMove: Sendable {
        /// Bites a hole out of the board.
        case bite
        /// Makes off with a tile, and now and then a booster.
        case steal
        /// Drops a boulder on the board.
        case stomp
    }

    /// The last stage of every world is its boss.
    nonisolated static func isBossStage(_ stage: Int) -> Bool {
        stage > 0 && stage % worldSize == 0
    }

    /// The creature that guards a stage's world.
    nonisolated static func boss(forStage stage: Int) -> Critter {
        switch worldSkin(world(ofStage: stage)) {
        case "sunset": return .crab
        case "ocean": return .shark
        case "bubblegum": return .gummy
        case "rainforest": return .monkey
        case "lava": return .dragon
        case "jurassic": return .trex
        case "frost": return .yeti
        case "gold": return .mole
        case "party": return .pinata
        case "galaxy": return .ufo
        default: return .robot
        }
    }

    nonisolated static func bossMove(_ critter: Critter) -> BossMove {
        switch critter {
        case .shark, .crab, .mole, .dragon: return .bite
        case .monkey, .ufo, .pinata: return .steal
        case .trex, .yeti, .robot, .gummy: return .stomp
        }
    }

    /// A boss stage in a line, or nil for any other stage.
    nonisolated static func bossWords(forStage stage: Int) -> String? {
        guard isBossStage(stage) else { return nil }
        let critter = boss(forStage: stage)
        switch bossMove(critter) {
        case .bite: return "Boss: the " + critter.title + " bites holes in the board"
        case .steal: return "Boss: the " + critter.title + " steals tiles and boosters"
        case .stomp: return "Boss: the " + critter.title + " drops boulders on the board"
        }
    }

    /// The boss strikes after every this many moves.
    static let bossEvery = 6
    /// A boss never leaves more than this many holes in the board at once.
    static let bossMaxHoles = 4
    /// Goes up each time the boss strikes; `lastBossWords` says what it did.
    private(set) var bossEvent = 0
    private(set) var lastBossWords = ""
    private(set) var bossMovesLeft = GameStore.bossEvery

    /// True while the game on the board is a boss stage still being fought.
    var isBossGame: Bool { hasStages && !stagePaid && Self.isBossStage(stage) }
    /// The boss of the stage on the board.
    var boss: Critter { Self.boss(forStage: playedStage) }

    /// Counts a move toward the boss's next strike, and strikes when it is due.
    private func bossTurn() {
        guard isBossGame, !isStageWon else { return }
        bossMovesLeft -= 1
        guard bossMovesLeft <= 0 else { return }
        bossMovesLeft = Self.bossEvery
        let critter = Self.boss(forStage: stage)
        switch Self.bossMove(critter) {
        case .bite:
            guard state.blocks.count < GameEngine.maxBlocks,
                  state.blocks.filter({ $0.kind == .hole }).count < Self.bossMaxHoles
            else { return }
            // An empty cell when there is one, otherwise the smallest tile's.
            var cell = GameEngine.emptyCells(state.tiles, blocked: blockedSet).randomElement(using: &rng)
            if cell == nil, state.tiles.count > 2, let victim = state.tiles.min(by: { $0.value < $1.value }) {
                state.tiles.removeAll { $0.id == victim.id }
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: victim.row, col: victim.col, value: victim.value))
                cell = Cell(row: victim.row, col: victim.col)
            }
            guard let cell else { return }
            state.blocks.append(Block(row: cell.row, col: cell.col, kind: .hole))
            lastBossWords = "The " + critter.title + " bit a hole in the board!"
        case .steal:
            guard state.tiles.count > 2, let victim = state.tiles.filter({ $0.kind != .stone }).randomElement(using: &rng) else { return }
            state.tiles.removeAll { $0.id == victim.id }
            nextBurstID += 1
            bursts.append(Burst(id: nextBurstID, row: victim.row, col: victim.col, value: victim.value))
            lastBossWords = "The " + critter.title + " stole a tile!"
            // One time in two it takes a booster as well, if the player has any.
            let held = Booster.allCases.filter { (boosterCounts[$0] ?? 0) > 0 }
            if Bool.random(using: &rng), let taken = held.randomElement(using: &rng) {
                boosterCounts[taken, default: 1] -= 1
                lastBossWords = "The " + critter.title + " stole a tile and a booster!"
            }
        case .stomp:
            let before = state.tiles.count
            spawnTile(forcing: .stone)
            guard state.tiles.count > before else { return }
            lastBossWords = "The " + critter.title + " dropped a boulder!"
        }
        bossEvent += 1
        shake(3)
    }

    // MARK: Worlds

    /// Stages to a world. Every world is one theme's land on the map.
    nonisolated static let worldSize = 8
    /// The themes in the order their worlds are met. Reaching a world unlocks its
    /// theme; after the last world they come round again.
    nonisolated static let worldSkins = [
        "neon", "sunset", "ocean", "bubblegum", "rainforest", "lava",
        "jurassic", "frost", "gold", "party", "galaxy",
    ]

    /// The world a stage is in, counting from 0.
    nonisolated static func world(ofStage stage: Int) -> Int {
        (max(1, stage) - 1) / worldSize
    }

    /// The id of a world's theme.
    nonisolated static func worldSkin(_ world: Int) -> String {
        worldSkins[max(0, world) % worldSkins.count]
    }

    /// Goes up each time a new world is reached; `lastWorldSkin` is its theme's id.
    private(set) var worldEvent = 0
    private(set) var lastWorldSkin = ""

    /// The world whose pictures the tiles show in place of numbers, or nil for
    /// numbers: the first world, and any game that is not the adventure.
    var symbolTheme: String? {
        guard hasStages else { return nil }
        let theme = Self.worldSkin(Self.world(ofStage: playedStage))
        return theme == "neon" ? nil : theme
    }

    /// Head-to-head games open at this stage.
    static let versusStage = 10
    var isVersusOpen: Bool { stage >= Self.versusStage }

    // MARK: The coin shop

    /// Something coins buy.
    enum ShopItem: String, CaseIterable, Identifiable, Sendable {
        case flips, sweeps, fevers, bombs, mixed, gem

        var id: String { rawValue }

        /// The booster a pack of three is made of, or nil.
        var booster: Booster? {
            switch self {
            case .flips: return .flip
            case .sweeps: return .sweep
            case .fevers: return .fever
            case .bombs: return .arm
            case .mixed, .gem: return nil
            }
        }

        /// Three boosters for the price of two; one of each for less than that; a gem.
        var price: Int {
            switch self {
            case .flips, .sweeps, .fevers, .bombs: return (booster?.price ?? 0) * 2
            case .mixed: return 550
            case .gem: return 500
            }
        }
    }

    /// Goes up each time something is bought with coins.
    private(set) var shopEvent = 0

    /// Buys something with coins. Returns false (and changes nothing) when the
    /// coins are short.
    @discardableResult
    func buy(_ item: ShopItem) -> Bool {
        guard coins >= item.price else { return false }
        coins -= item.price
        if let booster = item.booster {
            boosterCounts[booster, default: 0] += 3
        } else if item == .mixed {
            for booster in Booster.allCases {
                boosterCounts[booster, default: 0] += 1
            }
        } else {
            earnGems(1)
        }
        shopEvent += 1
        save()
        return true
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
        static let stage = "ff.stage"
        static let stageStreak = "ff.stage.streak"
        static let stageWon = "ff.stage.won"
        static let stageStars = "ff.stage.stars"
        static let dailyDay = "ff.daily.day"
        static let dailyStreak = "ff.daily.streak"
        static let stageCount = "ff.stage.count"
        static let stageMoves = "ff.stage.moves"
        static let jar = "ff.jar"
        static let starChests = "ff.star.chests"
        static let questDay = "ff.quest.day"
        static let questCounts = "ff.quest.counts"
        static let questClaimed = "ff.quest.claimed"

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
        self.stage = max(1, defaults.integer(forKey: Key.stage))
        self.stageStreak = max(0, defaults.integer(forKey: Key.stageStreak))
        self.stageStars = (defaults.array(forKey: Key.stageStars) as? [Int]) ?? []
        self.dailyStreak = max(0, defaults.integer(forKey: Key.dailyStreak))
        var owned = Set(defaults.stringArray(forKey: Key.skins) ?? [])
        // Every world reached so far has handed over its theme (the first is free).
        let reached = min(GameStore.world(ofStage: defaults.integer(forKey: Key.stage)), GameStore.worldSkins.count - 1)
        if reached >= 1 {
            for world in 1...reached {
                owned.insert(GameStore.worldSkin(world))
            }
        }
        self.ownedSkins = owned

        var mode = Mode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .timed
        let savedStage = max(1, defaults.integer(forKey: Key.stage))
        if !GameStore.isOpen(mode, stage: savedStage, themes: owned.count) {
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
        // A game that cleared its stage stays finished until the next stage is begun.
        let wasWon = mode == .timed && defaults.bool(forKey: Key.stageWon)
        self.isGameOver = !GameEngine.hasMove(loaded.state.tiles, blocked: Set(loaded.state.blocks.map(\.cell))) || (mode == .timed && loaded.seconds <= 0) || wasWon
        self.isStageWon = wasWon
        self.stagePaid = wasWon
        self.stageCount = max(0, defaults.integer(forKey: Key.stageCount))
        if case .moves(_, let moves) = GameStore.goal(forStage: wasWon ? max(1, savedStage - 1) : savedStage) {
            self.movesLeft = (defaults.object(forKey: Key.stageMoves) as? Int) ?? moves
        }
        if self.isOutOfMoves {
            self.isGameOver = true
        }
        self.jar = min(GameStore.jarLimit, max(0, defaults.integer(forKey: Key.jar)))
        self.starChests = max(0, defaults.integer(forKey: Key.starChests))
        self.questDay = defaults.integer(forKey: Key.questDay)
        if let counts = defaults.array(forKey: Key.questCounts) as? [Int], counts.count == 3 {
            self.questCounts = counts
        }
        if let claimed = defaults.array(forKey: Key.questClaimed) as? [Bool], claimed.count == 3 {
            self.questClaimed = claimed
        }
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
        isStageWon = newMode == .timed && defaults.bool(forKey: Key.stageWon)
        stagePaid = isStageWon
        isGameOver = !GameEngine.hasMove(state.tiles, blocked: blockedSet, holes: holeSet) || isTimeUp || isStageWon || isOutOfMoves
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
        noteQuest(.boosters, 1)
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

    // MARK: Moving one tile

    /// Every game starts with this many moves of a single tile; after that one costs coins.
    static let freeSingleMoves = 3
    static let singleMovePrice = 100
    private(set) var singleMovesLeft = GameStore.freeSingleMoves
    /// Goes up each time a single tile is moved.
    private(set) var singleMoveEvent = 0

    var canMoveOne: Bool {
        !isGameOver && (singleMovesLeft > 0 || coins >= Self.singleMovePrice)
    }

    /// Slides the tile in one cell on its own, leaving every other tile where it is.
    /// It counts as a move. Returns false (and costs nothing) when there is no tile
    /// there or it cannot go that way.
    @discardableResult
    func moveOne(row: Int, col: Int, _ dir: Direction) -> Bool {
        guard !isAnimating, canMoveOne else { return false }
        guard let tile = state.tiles.first(where: { $0.row == row && $0.col == col }) else { return false }
        let result = GameEngine.slideOne(state.tiles, id: tile.id, dir, blocked: blockedSet, holes: holeSet)
        guard result.changed else { return false }
        if singleMovesLeft > 0 {
            singleMovesLeft -= 1
        } else {
            coins -= Self.singleMovePrice
        }
        singleMoveEvent += 1

        bursts.removeAll()
        slidePulse += 1
        isTimerRunning = true
        swipeInFlight = true
        spendStageMove()

        if animated {
            isAnimating = true
            Task { [weak self] in
                await self?.playAnimated(result)
            }
        } else {
            playImmediately(result)
        }
        return true
    }

    func swipe(_ dir: Direction) {
        guard !isAnimating, !isGameOver else { return }
        // A board with nothing on it has nothing to swipe: deal new tiles instead.
        if refillEmptyBoard() {
            save()
            return
        }
        let result = GameEngine.slide(state.tiles, dir, blocked: blockedSet, holes: holeSet)
        guard result.changed else { return }

        bursts.removeAll()
        slidePulse += 1
        isTimerRunning = true
        swipeInFlight = true
        spendStageMove()

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
        // The stage's twist sets the board and the clock up.
        var clock = Self.roundSeconds
        if mode == .timed {
            switch Self.twist(forStage: stage) {
            case .plain:
                break
            case .breather:
                GameEngine.spawn(in: &fresh, using: &rng, forcedKind: .bomb)
            case .rocky:
                GameEngine.spawn(in: &fresh, using: &rng, forcedKind: .stone)
                GameEngine.spawn(in: &fresh, using: &rng, forcedKind: .stone)
            case .quickTurn:
                fresh.movesUntilRotation = 1
            case .sprint:
                clock = Self.sprintSeconds
            }
            // A winning run starts the stage with a bomb or two.
            for _ in 0..<Self.streakBombs(stageStreak) {
                GameEngine.spawn(in: &fresh, using: &rng, forcedKind: .bomb)
            }
        }
        state = fresh
        level = 1
        singleMovesLeft = Self.freeSingleMoves
        stageCount = 0
        movesLeft = 0
        bossMovesLeft = Self.bossEvery
        if mode == .timed, case .moves(_, let moves) = Self.goal(forStage: stage) {
            movesLeft = moves
        }
        if mode == .timed {
            isStageWon = false
            stagePaid = false
            defaults.set(false, forKey: Key.stageWon)
        }
        sharkHasCome = false
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
        secondsLeft = clock
        wholeSecondsLeft = Int(clock)
        isTimerRunning = false
        save()
    }

    // MARK: The clock

    /// Takes time off the clock. The screen calls this several times a second.
    func tick(_ seconds: Double) {
        guard isTimerRunning, !isGameOver, seconds > 0 else { return }
        // The stage's score was reached outside a move: the game ends here.
        if isStageWon, !isAnimating {
            isTimerRunning = false
            isGameOver = true
            winStage()
            rewardFinishedGame()
            save()
            return
        }
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
        guard hasClock, secondsLeft > 0 else { return }
        secondsLeft = max(0, secondsLeft - seconds)
        let whole = Int(secondsLeft.rounded(.up))
        if whole != wholeSecondsLeft {
            wholeSecondsLeft = whole
        }
        // A move in flight finishes first; `finishMove` then ends the game.
        if secondsLeft <= 0, !isAnimating {
            isTimerRunning = false
            isGameOver = true
            loseStage()
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
        let passes = GameEngine.settle(state.tiles, blocked: blockedSet, holes: holeSet)
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

        let passes = GameEngine.settle(state.tiles, blocked: blockedSet, holes: holeSet)
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
        // Crossing the stage's score clears the stage; the move in hand finishes first.
        if hasStages, !isStageWon, let target = scoreTarget, state.score < target, state.score + points >= target {
            isStageWon = true
        }
        state.score += points
        if state.score > best {
            best = state.score
        }
        lastGain = points
        gainEvent += 1
        coinBank += points
        let earned = coinBank / Self.pointsPerCoin
        coins += earned
        if hasStages {
            jar = min(Self.jarLimit, jar + earned)
        }
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
        swallowedIDs = Set(result.swallowed.map(\.id))
        if !result.swallowed.isEmpty {
            feedHoles(result.swallowed)
        }
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
            advanceStage(merges: merged.count, tile: lastMergeValue)
            noteQuest(.merges, merged.count)
            noteQuest(.bigTile, lastMergeValue)
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
            allowTime: hasClock,
            forcedKind: kind,
            stonesPerHundred: GameEngine.stonesPerHundred(level: hazardLevel)
        )
        if let tile, tile.kind != .normal {
            lastSpecialKind = tile.kind
            specialSpawnEvent += 1
        }
    }

    /// From level 4 a move sometimes drops a second new tile, more often the higher
    /// the level. Never onto a board that is already nearly full.
    private func spawnExtraTile() {
        let chance = GameEngine.extraTilePerHundred(level: hazardLevel)
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
            advanceStage(chains: 1)
            noteQuest(.chains, 1)
            // Only a long chain is worth a gem.
            if lastCombo >= 3 {
                earnGems(Self.gemsForChain)
            }
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
        if mode != .shift, mode != .timed || hazardLevel >= GameEngine.turnTileLevel {
            spawnTile()
        }
        // In the Twist game, any turn may be followed by one the other way.
        if mode == .twist, Bool.random(using: &rng) {
            state.counterClockwise.toggle()
            directionEvent += 1
        }
        state.movesUntilRotation = twist == .quickTurn ? 1 : GameEngine.movesPerRotation
        turnMerges = 0
    }

    /// Deals two tiles onto a board that has none left (bombs, a sweep or a creature
    /// can clear it), so there is always something to swipe. Returns true when it did.
    @discardableResult
    private func refillEmptyBoard() -> Bool {
        guard state.tiles.isEmpty else { return false }
        spawnTile(forcing: .normal)
        spawnTile(forcing: .normal)
        return !state.tiles.isEmpty
    }

    private func finishMove() {
        let wasSwipe = swipeInFlight
        swipeInFlight = false
        reshapeIfNeeded(afterSwipe: wasSwipe)
        refillEmptyBoard()
        if wasSwipe, mode == .fusion {
            mutateTile()
        }
        if wasSwipe {
            bossTurn()
        }
        let wasOver = isGameOver
        isGameOver = !GameEngine.hasMove(state.tiles, blocked: blockedSet, holes: holeSet) || isTimeUp || isStageWon || isOutOfMoves
        if isGameOver {
            isTimerRunning = false
            if !wasOver {
                if isStageWon {
                    winStage()
                } else {
                    loseStage()
                }
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
            defaults.set(stageCount, forKey: Key.stageCount)
            defaults.set(movesLeft, forKey: Key.stageMoves)
        }
        defaults.set(coins, forKey: Key.coins)
        defaults.set(jar, forKey: Key.jar)
        defaults.set(gems, forKey: Key.gems)
        defaults.set(ownedSkins.sorted(), forKey: Key.skins)
        for (booster, count) in boosterCounts {
            defaults.set(count, forKey: Key.booster(booster))
        }
    }
}
