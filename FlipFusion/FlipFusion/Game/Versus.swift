import GameKit
import Observation
import UIKit

/// A live head-to-head game over Game Center: two players are matched, start from
/// the same board with the same two minutes, see each other's score as they play,
/// and the higher score wins.
@MainActor
@Observable
final class Versus: NSObject, @preconcurrency GKMatchmakerViewControllerDelegate, @preconcurrency GKMatchDelegate {
    static let shared = Versus()

    enum Phase: Equatable {
        /// No head-to-head game.
        case idle
        /// Matched, and agreeing the starting board.
        case starting
        /// Both playing.
        case playing
    }

    /// What goes between the two phones.
    private struct Packet: Codable {
        /// 0 hello (with a roll to pick who deals), 1 the starting tiles, 2 a score.
        var kind: Int
        var roll: UInt32 = 0
        var tiles: [Tile] = []
        var score = 0
        var over = false
    }

    private(set) var phase = Phase.idle
    private(set) var rivalName = "Rival"
    private(set) var rivalScore = 0
    /// True once the other player's game has ended, or they have left.
    private(set) var rivalDone = false
    private(set) var rivalLeft = false
    /// Goes up when a head-to-head game starts; `startTiles` is the board to start from.
    private(set) var startEvent = 0
    private(set) var startTiles: [Tile] = []
    /// A line to show when matching fails.
    private(set) var notice: String?

    @ObservationIgnored private var match: GKMatch?
    @ObservationIgnored private var myRoll: UInt32 = 0
    @ObservationIgnored private var lastSent = -1

    /// Opens Game Center's matchmaking screen. Returns false when the player is not
    /// signed in to Game Center.
    @discardableResult
    func find() -> Bool {
        guard GKLocalPlayer.local.isAuthenticated else {
            GameCenter.shared.askAgain()
            return false
        }
        leave()
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        guard let screen = GKMatchmakerViewController(matchRequest: request) else { return false }
        screen.matchmakerDelegate = self
        GameCenter.topController()?.present(screen, animated: true)
        return true
    }

    /// Ends the head-to-head game and drops the connection.
    func leave() {
        match?.delegate = nil
        match?.disconnect()
        match = nil
        phase = .idle
        rivalScore = 0
        rivalDone = false
        rivalLeft = false
        lastSent = -1
    }

    /// Tells the other player this player's score, and whether their game is over.
    func send(score: Int, over: Bool) {
        guard phase == .playing, over || score != lastSent else { return }
        lastSent = score
        post(Packet(kind: 2, score: score, over: over))
    }

    private func post(_ packet: Packet) {
        guard let match, let data = try? JSONEncoder().encode(packet) else { return }
        try? match.sendData(toAllPlayers: data, with: .reliable)
    }

    private func begin(with tiles: [Tile]) {
        startTiles = tiles
        rivalScore = 0
        rivalDone = false
        rivalLeft = false
        lastSent = -1
        phase = .playing
        startEvent += 1
    }

    // MARK: Matchmaking

    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        viewController.dismiss(animated: true)
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: any Error) {
        viewController.dismiss(animated: true)
        notice = "Could not find a match. Try again in a moment."
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        viewController.dismiss(animated: true)
        self.match = match
        match.delegate = self
        rivalName = match.players.first?.displayName ?? "Rival"
        phase = .starting
        notice = nil
        // Each side rolls; the higher roll deals the starting board.
        myRoll = UInt32.random(in: 1...UInt32.max)
        post(Packet(kind: 0, roll: myRoll))
    }

    // MARK: The match

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let packet = try? JSONDecoder().decode(Packet.self, from: data) else { return }
        switch packet.kind {
        case 0:
            rivalName = player.displayName
            // The higher roll deals; on a tie both roll again.
            if packet.roll == myRoll {
                myRoll = UInt32.random(in: 1...UInt32.max)
                post(Packet(kind: 0, roll: myRoll))
            } else if myRoll > packet.roll, phase == .starting {
                var dice = SystemRandomNumberGenerator()
                let tiles = GameEngine.newGame(using: &dice).tiles
                post(Packet(kind: 1, tiles: tiles))
                begin(with: tiles)
            }
        case 1:
            if phase == .starting {
                begin(with: packet.tiles)
            }
        default:
            rivalScore = packet.score
            if packet.over {
                rivalDone = true
            }
        }
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        if state == .disconnected, phase != .idle {
            rivalDone = true
            rivalLeft = true
        }
    }

    func match(_ match: GKMatch, didFailWithError error: (any Error)?) {
        if phase != .idle {
            rivalDone = true
            rivalLeft = true
        }
    }
}
