import Foundation
import Testing
@testable import GameHost

/// A repeatable random source for dice tests.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Suite("GameState")
struct GameStateTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func threePlayers() -> GameState {
        var state = GameState()
        for name in ["Maya", "Dev", "Sam"] { state.addPlayer(named: name) }
        state.restartTurn(now: start)
        return state
    }

    // MARK: Players

    @Test func playersGetDistinctColorsAndDefaultNames() {
        var state = GameState()
        state.addPlayer(named: "  ")
        state.addPlayer(named: "Dev")
        #expect(state.players.map(\.name) == ["Player 1", "Dev"])
        #expect(Set(state.players.map(\.color)).count == 2)
    }

    @Test func playerCountIsCapped() {
        var state = GameState()
        for index in 0..<12 { state.addPlayer(named: "P\(index)") }
        #expect(state.players.count == GameState.maxPlayers)
    }

    @Test func renameIgnoresBlankNames() {
        var state = threePlayers()
        let id = state.players[0].id
        state.renamePlayer(id, to: "   ")
        #expect(state.players[0].name == "Maya")
        state.renamePlayer(id, to: " Mia ")
        #expect(state.players[0].name == "Mia")
    }

    @Test func removingAPlayerKeepsTheTurnOnTheSamePerson() {
        var state = threePlayers()
        state.passTurn(now: start)
        state.passTurn(now: start)
        #expect(state.activePlayer?.name == "Sam")
        state.removePlayer(state.players[0].id)
        #expect(state.activePlayer?.name == "Sam")
    }

    @Test func removingThePlayerUpLastWrapsToTheFirst() {
        var state = threePlayers()
        state.passTurn(now: start)
        state.passTurn(now: start)
        state.removePlayer(state.players[2].id)
        #expect(state.activeIndex == 0)
    }

    @Test func removingAPlayerDropsTheirUndoHistory() {
        var state = threePlayers()
        let dev = state.players[1].id
        state.addScore(5, to: state.players[0].id)
        state.addScore(3, to: dev)
        state.removePlayer(dev)
        #expect(state.history.count == 1)
        state.undo(now: start)
        #expect(state.players[0].score == 0)
    }

    // MARK: Scores and undo

    @Test func scoresAddAndZeroIsIgnored() {
        var state = threePlayers()
        let maya = state.players[0].id
        state.addScore(1, to: maya)
        state.addScore(10, to: maya)
        state.addScore(0, to: maya)
        state.addScore(-1, to: maya)
        #expect(state.players[0].score == 10)
        #expect(state.history.count == 3)
    }

    @Test func undoAndRedoAScore() {
        var state = threePlayers()
        let dev = state.players[1].id
        state.addScore(10, to: dev)
        #expect(state.undo(now: start) == .score(playerID: dev, delta: 10))
        #expect(state.players[1].score == 0)
        #expect(state.redo(now: start) == .score(playerID: dev, delta: 10))
        #expect(state.players[1].score == 10)
    }

    @Test func aNewChangeClearsRedo() {
        var state = threePlayers()
        let maya = state.players[0].id
        state.addScore(5, to: maya)
        state.undo(now: start)
        state.addScore(2, to: maya)
        #expect(state.redo(now: start) == nil)
        #expect(state.players[0].score == 2)
    }

    @Test func undoWithNothingDoesNothing() {
        var state = threePlayers()
        #expect(state.undo(now: start) == nil)
        #expect(state.redo(now: start) == nil)
    }

    @Test func describeNamesThePlayer() {
        var state = threePlayers()
        let dev = state.players[1].id
        #expect(state.describe(.score(playerID: dev, delta: 10), verb: "Undid") == "Undid +10 for Dev")
        #expect(state.describe(.score(playerID: dev, delta: -1), verb: "Redid") == "Redid -1 for Dev")
        state.removePlayer(dev)
        #expect(state.describe(.passTurn(fromIndex: 0, fromRound: 1), verb: "Undid") == "Undid passing the turn")
    }

    // MARK: Turns

    @Test func passingTheTurnWrapsIntoTheNextRound() {
        var state = threePlayers()
        state.passTurn(now: start)
        state.passTurn(now: start)
        #expect(state.round == 1)
        state.passTurn(now: start)
        #expect(state.activeIndex == 0)
        #expect(state.round == 2)
    }

    @Test func undoingAPassGoesBackARound() {
        var state = threePlayers()
        for _ in 0..<3 { state.passTurn(now: start) }
        state.undo(now: start)
        #expect(state.activeIndex == 2)
        #expect(state.round == 1)
        state.redo(now: start)
        #expect(state.activeIndex == 0)
        #expect(state.round == 2)
    }

    @Test func passingWithNoPlayersDoesNothing() {
        var state = GameState()
        state.passTurn(now: start)
        #expect(state.history.isEmpty)
        #expect(state.activePlayer == nil)
    }

    @Test func newGameKeepsPlayersAndResetsEverythingElse() {
        var state = threePlayers()
        state.addScore(7, to: state.players[1].id)
        state.passTurn(now: start)
        state.roll()
        state.newGame(now: start)
        #expect(state.players.count == 3)
        #expect(state.players.allSatisfy { $0.score == 0 })
        #expect(state.round == 1)
        #expect(state.activeIndex == 0)
        #expect(state.history.isEmpty)
        #expect(state.recentRolls.isEmpty)
    }

    // MARK: Timer

    @Test func timerCountsPausesAndRestartsOnPass() {
        var state = threePlayers()
        #expect(state.turnElapsed(at: start.addingTimeInterval(30)) == 30)
        state.toggleTimer(now: start.addingTimeInterval(30))
        #expect(!state.isTimerRunning)
        #expect(state.turnElapsed(at: start.addingTimeInterval(500)) == 30)
        state.toggleTimer(now: start.addingTimeInterval(500))
        #expect(state.turnElapsed(at: start.addingTimeInterval(510)) == 40)
        state.passTurn(now: start.addingTimeInterval(510))
        #expect(state.turnElapsed(at: start.addingTimeInterval(512)) == 2)
    }

    @Test func timerFormat() {
        #expect(TurnTimer.format(0) == "0:00")
        #expect(TurnTimer.format(42.9) == "0:42")
        #expect(TurnTimer.format(125) == "2:05")
    }

    // MARK: Dice

    @Test func diceCountIsClampedAndResizesTheDice() {
        var state = GameState()
        state.setDiceCount(9)
        #expect(state.diceCount == GameState.maxDice)
        #expect(state.dice.count == GameState.maxDice)
        state.setDiceCount(0)
        #expect(state.diceCount == 1)
        #expect(state.dice.count == 1)
    }

    @Test func rollsStayOnTheFacesAndKeepTheLastFive() {
        var state = GameState()
        state.setDiceCount(6)
        var generator = SeededGenerator(state: 42)
        var seen = Set<Int>()
        for _ in 0..<50 {
            state.roll(using: &generator)
            #expect(state.dice.count == 6)
            #expect(state.dice.allSatisfy { (1...6).contains($0) })
            seen.formUnion(state.dice)
        }
        #expect(seen == Set(1...6))
        #expect(state.recentRolls.count == GameState.recentRollLimit)
        #expect(state.recentRolls.first == state.dice)
    }

    // MARK: Saving

    @Test func stateSurvivesAJSONRoundTrip() throws {
        var state = GameState.demo(now: start)
        state.addScore(3, to: state.players[2].id)
        state.passTurn(now: start)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(GameState.self, from: data) == state)
    }
}
