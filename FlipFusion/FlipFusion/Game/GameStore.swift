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

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let animated: Bool
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()

    private enum Key {
        static let state = "ff.state"
        static let best = "ff.best"
        static let merged = "ff.merged"
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
        self.best = max(0, defaults.integer(forKey: Key.best))
        self.hasMergedOnce = defaults.bool(forKey: Key.merged)

        var restored: GameState?
        if let data = defaults.data(forKey: Key.state),
           let saved = try? JSONDecoder().decode(GameState.self, from: data),
           GameEngine.isValid(saved) {
            restored = saved
        }
        if let restored {
            self.state = restored
        } else {
            var generator = SystemRandomNumberGenerator()
            self.state = GameEngine.newGame(using: &generator)
        }
        self.isGameOver = !GameEngine.hasMove(state.tiles)
        if state.score > best {
            best = state.score
        }
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
        state = GameEngine.newGame(using: &rng)
        ghosts = []
        poppedIDs = []
        lastCombo = 0
        boardAngle = 0
        isGameOver = false
        save()
    }

    // MARK: The move sequence

    private func playImmediately(_ result: StepResult) {
        apply(result)
        ghosts = []
        GameEngine.spawn(in: &state, using: &rng)
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
        ghosts = []
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            poppedIDs = result.mergedIDs
        }
        GameEngine.spawn(in: &state, using: &rng)
        withAnimation(.easeInOut(duration: 0.2)) {
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

            let passes = GameEngine.settle(state.tiles)
            for pass in passes {
                withAnimation(.easeIn(duration: Timing.fall)) {
                    apply(pass)
                }
                await pause(Timing.fall)
                ghosts = []
                if !pass.mergedIDs.isEmpty {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                        poppedIDs = pass.mergedIDs
                    }
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
        state.score += result.gained
        if state.score > best {
            best = state.score
        }
        if !result.mergedIDs.isEmpty {
            mergePulse += 1
            if !hasMergedOnce {
                hasMergedOnce = true
                defaults.set(true, forKey: Key.merged)
            }
        }
    }

    private func finishRotation(_ passes: [StepResult]) {
        lastCombo = passes.filter { !$0.mergedIDs.isEmpty }.count
        if lastCombo >= 2 {
            comboEvent += 1
        }
        state.movesUntilRotation = GameEngine.movesPerRotation
    }

    private func finishMove() {
        isGameOver = !GameEngine.hasMove(state.tiles)
        save()
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }

    // MARK: Saving

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Key.state)
        }
        defaults.set(best, forKey: Key.best)
    }
}
