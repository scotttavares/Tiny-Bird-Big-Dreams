import Testing
@testable import GameHost

@Suite("RulesLibrary")
struct RulesLibraryTests {
    @Test func shipsTheTenLaunchGames() {
        let ids = Set(RulesLibrary.games.map(\.id))
        #expect(RulesLibrary.games.count == 10)
        #expect(ids == ["hearts", "spades", "crazy-eights", "rummy", "farkle", "liars-dice",
                        "chess", "checkers", "backgammon", "dominoes"])
    }

    @Test func everyKindHasGames() {
        for kind in RulesGame.Kind.allCases {
            #expect(!RulesLibrary.games(of: kind).isEmpty)
        }
    }

    @Test(arguments: RulesLibrary.games)
    func everyGameIsComplete(game: RulesGame) {
        #expect(!game.name.isEmpty)
        #expect(!game.summary.isEmpty)
        #expect(game.sections.count >= 4)
        #expect(Set(game.sections.map(\.id)).count == game.sections.count, "section titles are scroll ids")
        #expect(game.sections.allSatisfy { !$0.body.isEmpty })
        #expect(game.sections.last?.title == "End")
    }

    @Test func lookupByID() {
        #expect(RulesLibrary.game(id: "chess")?.name == "Chess")
        #expect(RulesLibrary.game(id: "monopoly") == nil)
        #expect(RulesLibrary.game(id: nil) == nil)
    }
}
