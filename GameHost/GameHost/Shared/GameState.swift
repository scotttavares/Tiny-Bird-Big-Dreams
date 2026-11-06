import Foundation

/// A tile color. Each player keeps theirs for the whole game.
enum PlayerColor: String, Codable, CaseIterable, Sendable {
    case amber, teal, violet, rose, blue, olive
}

struct Player: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var color: PlayerColor
    var score = 0
}

/// One change that shake-to-undo can take back.
enum Edit: Codable, Equatable, Sendable {
    case score(playerID: UUID, delta: Int)
    case passTurn(fromIndex: Int, fromRound: Int)

    var scorePlayerID: UUID? {
        if case let .score(playerID, _) = self { playerID } else { nil }
    }
}

/// Everything on the table side: players, scores, whose turn it is, the turn timer and the dice.
/// A plain value so every rule here is testable without SwiftUI.
struct GameState: Codable, Equatable, Sendable {
    static let maxPlayers = 8
    static let maxDice = 6
    static let recentRollLimit = 5

    var players: [Player] = []
    var activeIndex = 0
    var round = 1

    /// Turn time banked before the latest pause.
    var turnBanked: TimeInterval = 0
    /// When the running part of this turn started; `nil` while the timer is paused.
    var turnStartedAt: Date?

    var history: [Edit] = []
    var redoStack: [Edit] = []

    var diceCount = 2
    var dice: [Int] = [1, 1]
    /// Newest first.
    var recentRolls: [[Int]] = []

    /// The rules the host has open, by `RulesGame.id`.
    var rulesGameID: String?

    var activePlayer: Player? {
        players.indices.contains(activeIndex) ? players[activeIndex] : nil
    }

    // MARK: Players

    mutating func addPlayer(named name: String) {
        guard players.count < Self.maxPlayers else { return }
        let used = Set(players.map(\.color))
        let color = PlayerColor.allCases.first { !used.contains($0) }
            ?? PlayerColor.allCases[players.count % PlayerColor.allCases.count]
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        players.append(Player(name: trimmed.isEmpty ? "Player \(players.count + 1)" : trimmed, color: color))
    }

    mutating func renamePlayer(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = players.firstIndex(where: { $0.id == id }) else { return }
        players[index].name = trimmed
    }

    mutating func removePlayer(_ id: UUID) {
        guard let index = players.firstIndex(where: { $0.id == id }) else { return }
        players.remove(at: index)
        // Edits about a player who left can't be undone sensibly.
        history.removeAll { $0.scorePlayerID == id }
        redoStack.removeAll { $0.scorePlayerID == id }
        if index < activeIndex { activeIndex -= 1 }
        if activeIndex >= players.count { activeIndex = 0 }
    }

    /// Same players, scores back to zero, round 1, first player up.
    mutating func newGame(now: Date) {
        for index in players.indices { players[index].score = 0 }
        activeIndex = 0
        round = 1
        history = []
        redoStack = []
        recentRolls = []
        restartTurn(now: now)
    }

    // MARK: Scores and turns

    mutating func addScore(_ delta: Int, to playerID: UUID) {
        guard delta != 0, applyScore(delta, to: playerID) else { return }
        history.append(.score(playerID: playerID, delta: delta))
        redoStack = []
    }

    mutating func passTurn(now: Date) {
        guard !players.isEmpty else { return }
        history.append(.passTurn(fromIndex: activeIndex, fromRound: round))
        redoStack = []
        advanceTurn(now: now)
    }

    /// Takes back the newest edit and returns it, or `nil` when there's nothing to undo.
    @discardableResult
    mutating func undo(now: Date) -> Edit? {
        guard let edit = history.popLast() else { return nil }
        switch edit {
        case let .score(playerID, delta):
            _ = applyScore(-delta, to: playerID)
        case let .passTurn(fromIndex, fromRound):
            activeIndex = min(fromIndex, max(players.count - 1, 0))
            round = fromRound
            restartTurn(now: now)
        }
        redoStack.append(edit)
        return edit
    }

    /// Puts back the newest undone edit and returns it.
    @discardableResult
    mutating func redo(now: Date) -> Edit? {
        guard let edit = redoStack.popLast() else { return nil }
        switch edit {
        case let .score(playerID, delta):
            _ = applyScore(delta, to: playerID)
        case .passTurn:
            advanceTurn(now: now)
        }
        history.append(edit)
        return edit
    }

    /// A short line for the undo toast, e.g. "Undid +10 for Dev".
    func describe(_ edit: Edit, verb: String) -> String {
        switch edit {
        case let .score(playerID, delta):
            let name = players.first { $0.id == playerID }?.name ?? "a player"
            return "\(verb) \(delta > 0 ? "+" : "")\(delta) for \(name)"
        case .passTurn:
            return "\(verb) passing the turn"
        }
    }

    private mutating func applyScore(_ delta: Int, to playerID: UUID) -> Bool {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return false }
        players[index].score += delta
        return true
    }

    private mutating func advanceTurn(now: Date) {
        guard !players.isEmpty else { return }
        activeIndex += 1
        if activeIndex >= players.count {
            activeIndex = 0
            round += 1
        }
        restartTurn(now: now)
    }

    // MARK: Turn timer

    var isTimerRunning: Bool { turnStartedAt != nil }

    func turnElapsed(at now: Date) -> TimeInterval {
        turnBanked + (turnStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    mutating func toggleTimer(now: Date) {
        if let started = turnStartedAt {
            turnBanked += max(0, now.timeIntervalSince(started))
            turnStartedAt = nil
        } else {
            turnStartedAt = now
        }
    }

    mutating func restartTurn(now: Date) {
        turnBanked = 0
        turnStartedAt = now
    }

    // MARK: Dice

    mutating func setDiceCount(_ count: Int) {
        diceCount = min(max(count, 1), Self.maxDice)
        dice = Array(dice.prefix(diceCount)) + Array(repeating: 1, count: max(0, diceCount - dice.count))
    }

    mutating func roll<G: RandomNumberGenerator>(using generator: inout G) {
        dice = (0..<diceCount).map { _ in Int.random(in: 1...6, using: &generator) }
        recentRolls.insert(dice, at: 0)
        if recentRolls.count > Self.recentRollLimit {
            recentRolls.removeLast(recentRolls.count - Self.recentRollLimit)
        }
    }

    mutating func roll() {
        var generator = SystemRandomNumberGenerator()
        roll(using: &generator)
    }
}

extension GameState {
    /// The four-player Hearts game used for previews, screenshots and `-GHSeedDemo`.
    static func demo(now: Date = .now) -> GameState {
        var state = GameState()
        for name in ["Maya", "Dev", "Sam", "Ana"] { state.addPlayer(named: name) }
        for (index, score) in [38, 31, 27, 22].enumerated() { state.players[index].score = score }
        state.round = 4
        state.turnBanked = 42
        state.turnStartedAt = now
        state.dice = [4, 6]
        state.recentRolls = [[4, 6], [3, 5], [2, 2]]
        state.rulesGameID = "hearts"
        return state
    }
}
