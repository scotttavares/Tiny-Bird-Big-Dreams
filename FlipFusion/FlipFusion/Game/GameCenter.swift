import GameKit
import UIKit

/// Apple's Game Center: signs the player in and keeps the worldwide leaderboards,
/// one for each game mode, holding every player's best score.
@MainActor
final class GameCenter: NSObject, @preconcurrency GKGameCenterControllerDelegate {
    static let shared = GameCenter()

    /// The leaderboard for a game mode, as it is named in App Store Connect, or nil
    /// for a mode that has none yet. So far the 2 Minutes and Endless games have one.
    nonisolated static func boardID(for mode: GameStore.Mode) -> String? {
        switch mode {
        case .timed, .endless: return "flipfusion.best." + mode.rawValue
        default: return nil
        }
    }

    private var hasAsked = false

    /// True when the player is signed in to Game Center on this device.
    var isSignedIn: Bool {
        GKLocalPlayer.local.isAuthenticated
    }

    /// Signs the player in. Game Center shows its own screen if it needs one; a
    /// player who is already signed in on the device sees only a small banner.
    func signIn() {
        // The unit tests have no Game Center to talk to.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard !hasAsked else { return }
        hasAsked = true
        GKLocalPlayer.local.authenticateHandler = { screen, _ in
            MainActor.assumeIsolated {
                if let screen {
                    GameCenter.topController()?.present(screen, animated: true)
                }
            }
        }
    }

    /// Sends a finished game's score to its mode's leaderboard. Game Center keeps
    /// each player's best, so a lower score changes nothing.
    func report(score: Int, mode: GameStore.Mode) {
        guard isSignedIn, score > 0, let board = GameCenter.boardID(for: mode) else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [board]) { _ in }
    }

    /// Opens the worldwide leaderboard of a game mode. Returns false when the
    /// player is not signed in to Game Center (it asks them to sign in instead).
    @discardableResult
    func showBoard(for mode: GameStore.Mode) -> Bool {
        guard isSignedIn else {
            hasAsked = false
            signIn()
            return false
        }
        let screen = GKGameCenterViewController(
            leaderboardID: GameCenter.boardID(for: mode) ?? "flipfusion.best.timed",
            playerScope: .global,
            timeScope: .allTime
        )
        screen.gameCenterDelegate = self
        GameCenter.topController()?.present(screen, animated: true)
        return true
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }

    /// Asks the player to sign in again (they turned it down, or were signed out).
    func askAgain() {
        hasAsked = false
        signIn()
    }

    /// The screen on top right now, to present Game Center's screens from.
    static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.flatMap(\.windows).first
        var top = window?.rootViewController
        while let next = top?.presentedViewController {
            top = next
        }
        return top
    }
}
