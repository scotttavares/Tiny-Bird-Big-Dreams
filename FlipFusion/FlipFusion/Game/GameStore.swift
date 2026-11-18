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
    }

    @ObservationIgnored private var feverLeft: Double = 0

    /// The two ways to play. Each keeps its own game in progress and its own best score.
    enum Mode: String, Sendable {
        /// Two minutes on the clock.
        case timed
        /// No clock: play until no move is left. An extra tile lands after every
        /// rotation, so the board does fill up.
        case endless
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

        static func state(_ mode: Mode) -> String {
            mode == .timed ? "ff.state" : "ff.endless.state"
        }

        static func best(_ mode: Mode) -> String {
            mode == .timed ? "ff.best" : "ff.endless.best"
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

        let mode = Mode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .timed
        let loaded = GameStore.load(mode, from: defaults)
        self.mode = mode
        self.state = loaded.state
        self.best = loaded.best
        self.secondsLeft = loaded.seconds
        self.wholeSecondsLeft = Int(loaded.seconds.rounded(.up))
        self.isGameOver = !GameEngine.hasMove(loaded.state.tiles) || (mode == .timed && loaded.seconds <= 0)
    }

    /// Changes the way to play. The game left behind is saved and waits for you.
    func switchMode(_ newMode: Mode) {
        guard !isAnimating, newMode != mode else { return }
        save()
        mode = newMode
        defaults.set(newMode.rawValue, forKey: Key.mode)

        let loaded = GameStore.load(newMode, from: defaults)
        state = loaded.state
        best = loaded.best
        secondsLeft = loaded.seconds
        wholeSecondsLeft = Int(loaded.seconds.rounded(.up))
        ghosts = []
        poppedIDs = []
        bursts = []
        lastCombo = 0
        boardAngle = 0
        isFever = false
        feverLeft = 0
        isTimerRunning = false
        isGameOver = !GameEngine.hasMove(state.tiles) || isTimeUp
        save()
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
        let result = GameEngine.slide(state.tiles, dir)
        guard result.changed else { return }

        bursts.removeAll()
        slidePulse += 1
        isTimerRunning = true

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
        ghosts = []
        poppedIDs = []
        lastCombo = 0
        boardAngle = 0
        isGameOver = false
        bursts = []
        isFever = false
        feverLeft = 0
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
        apply(result)
        ghosts = []
        spawnTile()
        state.movesUntilRotation -= 1
        if state.movesUntilRotation <= 0 {
            rotatePulse += 1
            state.tiles = GameEngine.rotateClockwise(state.tiles)
            let passes = GameEngine.settle(state.tiles)
            for pass in passes {
                apply(pass)
                ghosts = []
            }
            finishRotation(passes)
        }
        finishMove()
    }

    private func playAnimated(_ result: StepResult) async {
        withAnimation(.easeOut(duration: Timing.slide)) {
            apply(result)
        }
        await pause(Timing.slide)
        // One animated update: the merged-away tiles go, the survivors pulse,
        // the new tile arrives and the countdown ticks.
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            ghosts = []
            poppedIDs = result.mergedIDs
            spawnTile()
            state.movesUntilRotation -= 1
        }
        await pause(Timing.pop)
        withAnimation(.easeOut(duration: 0.15)) {
            poppedIDs = []
        }

        if state.movesUntilRotation <= 0 {
            await pause(Timing.beforeRotation)
            rotatePulse += 1
            withAnimation(.easeInOut(duration: Timing.rotation)) {
                boardAngle = 90
            }
            await pause(Timing.rotation + 0.03)
            // Swap to the turned coordinates and snap the board back upright in one
            // un-animated update: the picture on screen does not change.
            state.tiles = GameEngine.rotateClockwise(state.tiles)
            boardAngle = 0
            // Let that swap reach the screen before gravity starts animating.
            await pause(0.05)

            let passes = GameEngine.settle(state.tiles)
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

        finishMove()
        isAnimating = false
    }

    /// Puts a slide or a gravity pass on the board and adds its points.
    private func apply(_ result: StepResult) {
        state.tiles = result.tiles
        ghosts = result.ghosts
        let points = result.gained * (isFever ? 2 : 1)
        state.score += points
        if state.score > best {
            best = state.score
        }
        if points > 0 {
            lastGain = points
            gainEvent += 1
        }
        for effect in result.effects {
            switch effect.kind {
            case .time:
                secondsLeft = min(Self.roundSeconds, secondsLeft + Self.timeBonus)
                wholeSecondsLeft = Int(secondsLeft.rounded(.up))
                timeBonusEvent += 1
            case .bomb:
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: effect.row, col: effect.col, value: 64, isBlast: true))
                bombEvent += 1
            case .normal:
                break
            }
        }
        if !result.mergedIDs.isEmpty {
            let merged = result.tiles.filter { result.mergedIDs.contains($0.id) }
            lastMergeValue = merged.map(\.value).max() ?? 0
            for tile in merged {
                nextBurstID += 1
                bursts.append(Burst(id: nextBurstID, row: tile.row, col: tile.col, value: tile.value))
            }
            mergePulse += 1
            if !hasMergedOnce {
                hasMergedOnce = true
                defaults.set(true, forKey: Key.merged)
            }
        }
    }

    /// Adds the new tile of a move, and notes it when it is a special one.
    /// Clock tiles only make sense when there is a clock, so the endless game has none.
    private func spawnTile(forcing kind: TileKind? = nil) {
        let tile = GameEngine.spawn(in: &state, using: &rng, allowTime: mode == .timed, forcedKind: kind)
        if let tile, tile.kind != .normal {
            lastSpecialKind = tile.kind
            specialSpawnEvent += 1
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
            // A chain is rewarded with a power-up tile: a clock or a bomb in the timed
            // game, always a bomb in the endless one.
            let coin = Bool.random(using: &rng)
            let reward: TileKind = (mode == .timed && coin) ? .time : .bomb
            spawnTile(forcing: reward)
        }
        // The endless game gets an extra tile after every rotation, so the board fills.
        if mode == .endless {
            spawnTile()
        }
        state.movesUntilRotation = GameEngine.movesPerRotation
    }

    private func finishMove() {
        isGameOver = !GameEngine.hasMove(state.tiles) || isTimeUp
        if isGameOver {
            isTimerRunning = false
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
    }
}
