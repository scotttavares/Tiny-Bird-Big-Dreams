import Foundation

/// A rules write-up for one game. Every text here is our own summary of a public-domain
/// classic; commercial rulebooks are never bundled.
struct RulesGame: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case cards = "Card games"
        case dice = "Dice games"
        case board = "Board games"
    }

    struct Section: Identifiable, Equatable, Sendable {
        var title: String
        var body: String
        var id: String { title }
    }

    var id: String
    var name: String
    var kind: Kind
    var players: String
    var summary: String
    var sections: [Section]
}

enum RulesLibrary {
    static func game(id: String?) -> RulesGame? {
        games.first { $0.id == id }
    }

    static func games(of kind: RulesGame.Kind) -> [RulesGame] {
        games.filter { $0.kind == kind }
    }

    static let games: [RulesGame] = [
        RulesGame(
            id: "hearts", name: "Hearts", kind: .cards, players: "4 players",
            summary: "Avoid taking hearts and the queen of spades. Lowest score wins.",
            sections: [
                .init(title: "Setup", body: "Use a standard 52-card deck. Deal all the cards, 13 to each player. Aces are high."),
                .init(title: "Passing", body: "Before each hand, everyone passes three cards. Hand 1 passes left, hand 2 right, hand 3 across, and hand 4 keeps its cards. Then the cycle repeats."),
                .init(title: "Play", body: "Whoever holds the 2 of clubs leads it to the first trick. Follow suit if you can; if you can't, play any card. The highest card of the suit that was led wins the trick, and the winner leads next. You can't lead a heart until a heart has been played on an earlier trick, unless you hold nothing but hearts."),
                .init(title: "Scoring", body: "Each heart you take is 1 point and the queen of spades is 13. If one player takes all 13 hearts and the queen of spades, they score 0 and everyone else scores 26."),
                .init(title: "End", body: "Play until someone reaches 100 points. The player with the lowest score wins."),
            ]
        ),
        RulesGame(
            id: "spades", name: "Spades", kind: .cards, players: "4 players in two teams",
            summary: "Bid the tricks your team will take, then make your bid. Spades are always trump.",
            sections: [
                .init(title: "Setup", body: "Partners sit across from each other. Deal all 52 cards, 13 each. Aces are high and spades are trump."),
                .init(title: "Bidding", body: "Each player bids how many tricks they expect to win. Partners add their bids into one team bid. Bidding \"nil\" means you promise to win no tricks at all."),
                .init(title: "Play", body: "The player left of the dealer leads. Follow suit if you can; if you can't, play any card, including a spade. The highest spade wins the trick, or the highest card of the suit led if no spade was played. You can't lead spades until a spade has been played, unless you hold only spades."),
                .init(title: "Scoring", body: "Make your team bid: 10 points per bid trick, plus 1 point for each extra trick (a \"bag\"). Miss it: lose 10 points per bid trick. Every 10 bags costs 100 points. A made nil is worth 100 points; a failed nil loses 100."),
                .init(title: "End", body: "The first team to reach 500 points wins."),
            ]
        ),
        RulesGame(
            id: "crazy-eights", name: "Crazy Eights", kind: .cards, players: "2 to 7 players",
            summary: "Match the suit or the number to get rid of your cards. Eights are wild.",
            sections: [
                .init(title: "Setup", body: "Deal 7 cards each with 2 players, or 5 each with more. Put the rest face down as the stock and turn the top card up to start the discard pile."),
                .init(title: "Play", body: "On your turn, play a card that matches the top discard by suit or by number. If you can't, draw from the stock until you can play, or until the stock runs out."),
                .init(title: "Eights", body: "An 8 can be played on anything. When you play one, name the suit the next player must follow."),
                .init(title: "Scoring", body: "The first player out of cards wins the hand and scores the cards left in everyone else's hands: 50 for each 8, 10 for each king, queen or jack, 1 for an ace, and face value for the rest."),
                .init(title: "End", body: "Agree a target before you start, such as 100 points. The first player to reach it wins."),
            ]
        ),
        RulesGame(
            id: "rummy", name: "Rummy", kind: .cards, players: "2 to 6 players",
            summary: "Build sets and runs, and be first to get rid of your hand.",
            sections: [
                .init(title: "Setup", body: "Deal 10 cards each with 2 players, 7 each with 3 or 4, and 6 each with 5 or 6. Put the rest face down as the stock and turn one card up to start the discard pile. Aces are low."),
                .init(title: "Melds", body: "A set is three or four cards of the same rank, like three 9s. A run is three or more cards of one suit in order, like the 4, 5 and 6 of hearts."),
                .init(title: "Play", body: "On your turn, draw the top card of the stock or the discard pile. Then you may lay down melds, or add cards to melds already on the table. End your turn by discarding one card."),
                .init(title: "Scoring", body: "The first player to get rid of every card wins the hand. They score the cards left in the other hands: 10 for each face card, 1 for each ace, and face value for the rest."),
                .init(title: "End", body: "Play to an agreed target, such as 100 points."),
            ]
        ),
        RulesGame(
            id: "farkle", name: "Farkle", kind: .dice, players: "2 or more players",
            summary: "Roll six dice, bank scoring dice, and stop before you roll nothing.",
            sections: [
                .init(title: "Setup", body: "You need six dice. Set the dice tray to 6."),
                .init(title: "Play", body: "Roll all six dice. Set aside at least one scoring die, then either bank your points for the turn or roll the dice that are left. If all six dice end up scoring, you may pick them all up and keep rolling."),
                .init(title: "Farkle", body: "If a roll has no scoring dice, that's a farkle: you lose every point from this turn and play passes."),
                .init(title: "Scoring", body: "Each 1 is 100 and each 5 is 50. Three of a kind is 100 times the number, except three 1s, which is 1,000. Many groups play extra combos, like 1,500 for a straight. Agree yours before you start."),
                .init(title: "End", body: "When a player reaches 10,000, everyone else gets one last turn. The highest score wins."),
            ]
        ),
        RulesGame(
            id: "liars-dice", name: "Liar's Dice", kind: .dice, players: "2 to 6 players",
            summary: "Bid on what's under everyone's cups, and call out the liar.",
            sections: [
                .init(title: "Setup", body: "Each player has five dice and a cup. Everyone shakes their dice and peeks at their own, keeping them hidden from everyone else."),
                .init(title: "Bidding", body: "The first player bids on how many dice of one face are on the whole table, like \"four 3s\". Each next player must raise the bid, with more dice of any face or the same number of dice with a higher face, or call \"liar\"."),
                .init(title: "Calling", body: "When someone calls liar, everyone reveals. If the bid was true, the caller loses a die. If it was false, the bidder loses a die. Some groups count 1s as wild; agree before you start."),
                .init(title: "End", body: "Players with no dice left are out. The last player with dice wins."),
            ]
        ),
        RulesGame(
            id: "chess", name: "Chess", kind: .board, players: "2 players",
            summary: "Trap the other king so it can't escape: checkmate.",
            sections: [
                .init(title: "Setup", body: "Set the board with a light square at each player's bottom right. On the back row, from the corners in: rooks, knights, bishops, then the queen on her own color and the king beside her. Pawns fill the second row. White moves first."),
                .init(title: "Moves", body: "The king moves one square in any direction. The queen moves any distance in a straight line or diagonal. A rook moves straight, a bishop moves diagonally, and a knight jumps in an L shape. A pawn moves forward one square, or two on its first move, and captures one square diagonally forward."),
                .init(title: "Special moves", body: "Castling: the king moves two squares toward a rook, and the rook jumps to the king's other side, if neither has moved and nothing is between them. A pawn reaching the far row becomes any other piece. En passant: a pawn can capture a pawn that just moved two squares past it, as if it had moved one."),
                .init(title: "Check", body: "A king under attack is in check, and its player must get it out of check. You can never make a move that leaves your own king in check."),
                .init(title: "End", body: "Checkmate wins: the king is in check and nothing can save it. If a player can't move but isn't in check, it's a stalemate and a draw."),
            ]
        ),
        RulesGame(
            id: "checkers", name: "Checkers", kind: .board, players: "2 players",
            summary: "Jump and capture every one of the other player's pieces.",
            sections: [
                .init(title: "Setup", body: "Each player puts 12 pieces on the dark squares of the three rows nearest them. Dark moves first."),
                .init(title: "Moves", body: "Pieces move one square diagonally forward onto an empty dark square."),
                .init(title: "Jumps", body: "Capture by jumping diagonally over an opposing piece onto the empty square beyond it. If a jump is possible you must take it, and if you can keep jumping with the same piece, you must."),
                .init(title: "Kings", body: "A piece reaching the far row becomes a king, marked with a second piece on top. Kings move and jump diagonally forward and backward."),
                .init(title: "End", body: "You win when the other player has no pieces left or no legal move."),
            ]
        ),
        RulesGame(
            id: "backgammon", name: "Backgammon", kind: .board, players: "2 players",
            summary: "Race your 15 checkers around the board and bear them off first.",
            sections: [
                .init(title: "Setup", body: "Each player has 15 checkers. From your own home side: 2 on the 24-point, 5 on the 13-point, 3 on the 8-point and 5 on the 6-point. You move toward your home board, points 1 to 6."),
                .init(title: "Moves", body: "Roll two dice and move checkers by each number, either one checker for both or two checkers for one number each. Doubles are played four times. You can't land on a point holding two or more of the other player's checkers."),
                .init(title: "Hitting", body: "Landing on a point with a single opposing checker hits it. It goes to the bar, and its owner must bring it back into your home board before moving anything else."),
                .init(title: "Bearing off", body: "Once all 15 of your checkers are in your home board, you can bear them off with rolls that move them past the edge."),
                .init(title: "End", body: "The first player to bear off all 15 checkers wins."),
            ]
        ),
        RulesGame(
            id: "dominoes", name: "Dominoes", kind: .board, players: "2 to 4 players",
            summary: "The block game: match ends and be first to play every tile.",
            sections: [
                .init(title: "Setup", body: "Use a double-six set of 28 tiles, face down. With 2 players each takes 7 tiles; with 3 or 4, each takes 5. Leftover tiles stay out of play."),
                .init(title: "Play", body: "The player with the highest double plays it first. Then, in turn, play a tile that matches the number on either open end of the line. If you can't play, pass."),
                .init(title: "Blocked", body: "If nobody can play, the game is blocked. The player with the fewest pips left in hand wins the hand."),
                .init(title: "Scoring", body: "The winner of a hand scores the pips left in the other players' hands."),
                .init(title: "End", body: "Play to an agreed target, such as 100 points."),
            ]
        ),
    ]
}
