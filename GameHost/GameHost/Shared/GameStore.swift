import Foundation
import Observation

/// Owns the live `GameState`, saves it after every change, and keeps the undo toast.
@MainActor
@Observable
final class GameStore {
    static let defaultsKey = "GHGameState"

    var state: GameState {
        didSet { save() }
    }

    /// The latest "Undid …" / "Redid …" line, cleared after a few seconds.
    private(set) var toast: String?

    private let defaults: UserDefaults
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.defaults = defaults
        if arguments.contains("-GHSeedDemo") {
            state = .demo()
        } else if let data = defaults.data(forKey: Self.defaultsKey),
                  let saved = try? JSONDecoder().decode(GameState.self, from: data) {
            state = saved
        } else {
            var fresh = GameState()
            fresh.addPlayer(named: "Player 1")
            fresh.addPlayer(named: "Player 2")
            fresh.restartTurn(now: .now)
            state = fresh
        }
    }

    /// Shake: undo the newest change. A second shake right after puts it back.
    func shake(now: Date = .now) {
        let isRedo = toast?.hasPrefix("Undid") == true && !state.redoStack.isEmpty
        if isRedo, let edit = state.redo(now: now) {
            show(state.describe(edit, verb: "Redid"))
        } else if let edit = state.undo(now: now) {
            show(state.describe(edit, verb: "Undid") + ". Shake again to redo.")
        } else {
            show("Nothing to undo")
        }
    }

    private func show(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
