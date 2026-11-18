import SpriteKit
import SwiftUI

/// The SwiftUI-facing state of one play session. Owns the SpriteKit scene.
@MainActor
final class GameModel: ObservableObject, GameSceneDelegate {
    enum Phase: Equatable {
        case playing
        case won(stars: Int, moves: Int)
        case failed
    }

    @Published private(set) var level: LevelData
    @Published var selectedMood: Mood
    @Published private(set) var moves = 0
    @Published private(set) var phase: Phase = .playing
    @Published private(set) var nestsDone = 0
    @Published private(set) var nestsTotal = 0
    @Published var showingHint = false
    /// Live moods of every body, for the companion page's cast list.
    @Published private(set) var cast: [CastMember] = []

    struct CastMember: Identifiable, Equatable {
        let id: String
        let mood: Mood
        let swappable: Bool
        let isStone: Bool
    }

    let scene: GameScene
    private weak var progress: ProgressStore?

    init(level: LevelData, progress: ProgressStore?) {
        self.level = level
        self.progress = progress
        selectedMood = level.palette.first ?? .happy
        scene = GameScene(level: level)
        nestsTotal = level.nests.count
        scene.gameDelegate = self
        refreshCast()
    }

    var palette: [Mood] { level.palette }

    /// Hooks up progress saving once the environment is available.
    func attach(_ store: ProgressStore) {
        progress = store
    }

    func restart() {
        phase = .playing
        moves = 0
        showingHint = false
        scene.reset()
        refreshCast()
    }

    func load(_ next: LevelData) {
        level = next
        selectedMood = next.palette.first ?? .happy
        nestsTotal = next.nests.count
        nestsDone = 0
        phase = .playing
        moves = 0
        showingHint = false
        scene.load(next)
        refreshCast()
    }

    func hint() {
        showingHint = true
        if let first = level.solution.first {
            selectedMood = first.mood
            scene.highlight(first.target)
        }
    }

    func setPaused(_ paused: Bool) {
        scene.isRunning = !paused
    }

    private func refreshCast() {
        let next = scene.sim.jellies.map { CastMember(id: $0.id, mood: $0.mood, swappable: $0.swappable, isStone: false) }
            + scene.sim.pegs.map { CastMember(id: $0.id, mood: $0.mood, swappable: $0.swappable, isStone: true) }
        if next != cast { cast = next }
    }

    // MARK: GameSceneDelegate

    func scene(_ scene: GameScene, didChangeMoves moves: Int) {
        self.moves = moves
        refreshCast()
    }

    func scene(_ scene: GameScene, didWinWithMoves moves: Int) {
        let stars = level.stars(forMoves: moves)
        progress?.record(level, stars: stars)
        phase = .won(stars: stars, moves: moves)
    }

    func sceneMoodsChanged(_ scene: GameScene) {
        refreshCast()
    }

    func sceneDidFail(_ scene: GameScene) {
        phase = .failed
    }

    func scene(_ scene: GameScene, nestsChanged satisfied: Int, of total: Int) {
        nestsDone = satisfied
        nestsTotal = total
    }
}
