import Foundation
import Testing
@testable import GameHost

@MainActor
@Suite("GameStore")
struct GameStoreTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "GameHostTests.\(UUID().uuidString)")!
    }

    @Test func freshStoreStartsWithTwoPlayers() {
        let store = GameStore(defaults: makeDefaults(), arguments: [])
        #expect(store.state.players.map(\.name) == ["Player 1", "Player 2"])
        #expect(store.state.isTimerRunning)
    }

    @Test func seedDemoArgumentLoadsTheDemo() {
        let store = GameStore(defaults: makeDefaults(), arguments: ["-GHSeedDemo"])
        #expect(store.state.players.count == 4)
        #expect(store.state.rulesGameID == "hearts")
    }

    @Test func changesAreSavedAndReloaded() {
        let defaults = makeDefaults()
        let store = GameStore(defaults: defaults, arguments: [])
        store.state.addScore(12, to: store.state.players[0].id)
        let reopened = GameStore(defaults: defaults, arguments: [])
        #expect(reopened.state.players[0].score == 12)
    }

    @Test func shakeUndoesThenASecondShakeRedoes() {
        let store = GameStore(defaults: makeDefaults(), arguments: [])
        let id = store.state.players[1].id
        store.state.addScore(10, to: id)

        store.shake()
        #expect(store.state.players[1].score == 0)
        #expect(store.toast == "Undid +10 for Player 2. Shake again to redo.")

        store.shake()
        #expect(store.state.players[1].score == 10)
        #expect(store.toast == "Redid +10 for Player 2")

        // After a redo, the next shake undoes again.
        store.shake()
        #expect(store.state.players[1].score == 0)
    }

    @Test func shakeWithNothingToUndoSaysSo() {
        let store = GameStore(defaults: makeDefaults(), arguments: [])
        store.shake()
        #expect(store.toast == "Nothing to undo")
    }
}
