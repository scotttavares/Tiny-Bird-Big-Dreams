import Foundation
import GameKit
import UIKit

/// Who is in the Game Center match right now, kept apart from GameKit so it can be unit tested.
/// Turns connection changes into the page's events: a new person → `people`; a drop → `left` + `people`;
/// the same gamePlayerID coming back into the match → `back` + `people`.
struct GameCenterRoster {
    /// The player on this phone: never listed and never a recipient.
    var me: String?
    private(set) var people: [GameBridge.GameCenterPerson] = []
    private var gone: Set<String> = []

    mutating func connected(_ person: GameBridge.GameCenterPerson) -> [GameBridge.GameCenterEvent] {
        guard person.gamePlayerID != me, !people.contains(where: { $0.gamePlayerID == person.gamePlayerID }) else { return [] }
        people.append(person)
        let back = gone.remove(person.gamePlayerID) != nil
        return (back ? [.back(person.gamePlayerID)] : []) + [.people(people)]
    }

    mutating func disconnected(_ id: String) -> [GameBridge.GameCenterEvent] {
        guard let index = people.firstIndex(where: { $0.gamePlayerID == id }) else { return [] }
        people.remove(at: index)
        gone.insert(id)
        return [.left(id), .people(people)]
    }

    /// The ids a send may reach: only people connected to the match right now, each once. Anyone else
    /// (a stranger, someone who has left, this phone's own player) is dropped.
    func recipients(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { id in people.contains { $0.gamePlayerID == id } && seen.insert(id).inserted }
    }

    mutating func reset() {
        people = []
        gone = []
    }
}

/// What a host / invite request does, decided apart from GameKit so it can be unit tested.
/// `host` starts a match (or adds people to the one running); `invite` only adds people to a running match, so it can
/// never start one: hosting is checked (Full Arsenal) on the page's `host` path.
enum GameCenterMatchmaking: Equatable {
    case start(maxPlayers: Int)
    case addPeople
    case ignore

    static func plan(for op: GameBridge.GameCenterOp, hasMatch: Bool) -> GameCenterMatchmaking {
        switch op {
        case .host(let maxPlayers): hasMatch ? .addPeople : .start(maxPlayers: maxPlayers)
        case .invite: hasMatch ? .addPeople : .ignore
        default: .ignore
        }
    }
}

/// What losing the Game Center sign-in does to a running match, decided apart from GameKit so it can be unit tested.
/// Signed out (in Settings) or newly restricted mid-match, GameKit stops passing this phone's events on but the `GKMatch`
/// stays connected, so the others would never hear `left` and their battle would freeze. So the match is left (the others
/// hear `left` and, after their 60 s wait, win by forfeit) and the page is told, so it leaves the battle with the sign-in help.
struct GameCenterSignIn: Equatable {
    let dropMatch: Bool
    let events: [GameBridge.GameCenterEvent]

    static func changed(signedIn: Bool, hasMatch: Bool) -> GameCenterSignIn {
        guard hasMatch, !signedIn else { return GameCenterSignIn(dropMatch: false, events: []) }
        return GameCenterSignIn(dropMatch: true, events: [.matchmaker(ok: false, reason: "signed-out")])
    }
}

/// Hands GameKit's callbacks (which may come on any thread) to the main actor one after another, in the order GameKit made
/// them: the main queue is first in, first out, where a separate `Task` per callback could let a player's connect and
/// disconnect swap places (and leave a false 60 s wait on the other phone).
enum GameCenterHop {
    static func toMain(_ body: @escaping @MainActor @Sendable () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated { body() } }
    }
}

/// Game Center for two-phone multiplayer: signs the player in, opens Apple's invite screen (friends only, no strangers),
/// keeps the real-time `GKMatch`, sends the page's messages to the people it names (reliable mode) and hands
/// everything that arrives back to the page as `gcEvent` scripts. No server of ours and nothing stored.
@MainActor
final class GameCenter {
    /// Called with a script for the page (`window.gcEvent(...)`).
    var onEvent: ((String) -> Void)?
    /// The view controller to show Game Center's screens over.
    var presenter: (() -> UIViewController?)?

    private enum Status {
        case unknown
        case ready
        case needsSignIn(UIViewController)
        case failed(String)
    }

    private var status = Status.unknown
    private var started = false
    private var registered = false
    /// The page asked to sign in ("Play friends online"); until then sign-in results aren't pushed to it.
    private var pageAsked = false
    /// The page has been told `auth ok` (it hears nothing about a match before that).
    private var pageKnowsAuth = false
    /// host / invite waiting for sign-in to finish.
    private var queued: GameBridge.GameCenterOp?
    private var match: GKMatch?
    private var roster = GameCenterRoster()
    private var matchmaker: GKMatchmakerViewController?
    private let relay = GameCenterRelay()

    init() {
        relay.owner = self
    }

    /// Signs in at launch (Game Center shows its "Welcome back" banner), so invites from friends can arrive.
    /// If the player isn't signed in, Apple's sign-in screen is kept until they tap "Play friends online".
    func start() {
        guard !started else { return }
        started = true
        // GameKit may call this off the main thread, so it isn't main-actor isolated; it hops over.
        GKLocalPlayer.local.authenticateHandler = { @Sendable [weak self] controller, error in
            let carried = Carry(value: controller), owner = self
            GameCenterHop.toMain { owner?.authChanged(carried.value, error) }
        }
    }

    func handle(_ op: GameBridge.GameCenterOp) {
        switch op {
        case .auth:
            start()
            pageAsked = true
            if case .needsSignIn(let controller) = status {
                if controller.presentingViewController == nil { show(controller) }
            } else {
                tellAuth()
            }
        case .host, .invite:
            openMatchmaker(op)
        case let .send(to, data):
            send(data, to: to)
        case .leave:
            leave()
        }
    }

    /// Why Game Center can't be used, as a short code the page turns into help: notSignedIn, restricted, offline, unavailable.
    nonisolated static func reason(for error: (any Error)?) -> String {
        guard let code = (error as? GKError)?.code else { return "notSignedIn" }
        switch code {
        case .parentalControlsBlocked, .underage: return "restricted"
        case .communicationsFailure: return "offline"
        case .gameUnrecognized, .notSupported: return "unavailable"
        default: return "notSignedIn"
        }
    }

    // MARK: Sign-in

    private func authChanged(_ controller: UIViewController?, _ error: (any Error)?) {
        if let controller {
            status = .needsSignIn(controller)
            signInChanged()
            if pageAsked, controller.presentingViewController == nil { show(controller) }
            return
        }
        let local = GKLocalPlayer.local
        if local.isAuthenticated {
            status = local.isMultiplayerGamingRestricted ? .failed("restricted") : .ready
        } else {
            status = .failed(Self.reason(for: error))
            pageKnowsAuth = false
        }
        if case .ready = status {
            roster.me = local.gamePlayerID
            if !registered {
                registered = true
                local.register(relay) // invites from friends arrive through the relay
            }
        }
        if pageAsked { tellAuth() }
        signInChanged()
        guard let op = queued else { return }
        queued = nil
        if case .ready = status { handle(op) } else { emit(.matchmaker(ok: false, reason: "signed-out")) }
    }

    /// Signed out (or restricted) with a match running: leave it and tell the page (see `GameCenterSignIn`).
    private func signInChanged() {
        var signedIn = false
        if case .ready = status { signedIn = true }
        let plan = GameCenterSignIn.changed(signedIn: signedIn, hasMatch: match != nil)
        guard plan.dropMatch else { return }
        matchmaker?.dismiss(animated: true)
        matchmaker = nil
        dropMatch()
        pageKnowsAuth = false
        // straight to the page: emit() holds match news back while not signed in, and this is the page's cue to leave the battle
        plan.events.forEach { onEvent?(GameBridge.gcEventScript($0)) }
    }

    private func tellAuth() {
        switch status {
        case .ready:
            pageKnowsAuth = true
            emit(.auth(ok: true, gamePlayerID: GKLocalPlayer.local.gamePlayerID, reason: nil))
        case .failed(let reason):
            emit(.auth(ok: false, gamePlayerID: nil, reason: reason))
        case .unknown, .needsSignIn:
            break // the answer comes when GameKit calls back
        }
    }

    private func emit(_ event: GameBridge.GameCenterEvent) {
        switch (event, status) {
        case (.auth, _):
            break
        case (.matchmaker, .failed):
            // "signed-out" comes after the page has heard auth ok:false
            if !pageAsked { pageAsked = true; tellAuth() }
        case (_, .ready):
            if !pageKnowsAuth { tellAuth() } // e.g. a friend's invite accepted before the page asked
        default:
            return // nothing about a match before sign-in
        }
        onEvent?(GameBridge.gcEventScript(event))
    }

    // MARK: Matchmaking

    /// Apple's invite screen. With no match yet it starts one (host); with a match it adds people to it, which is also
    /// how someone who dropped out of a 3–4 person match is brought back.
    private func openMatchmaker(_ op: GameBridge.GameCenterOp) {
        let plan = GameCenterMatchmaking.plan(for: op, hasMatch: match != nil)
        guard plan != .ignore else { return }
        guard case .ready = status else {
            if case .failed = status { emit(.matchmaker(ok: false, reason: "signed-out")) } else { queued = op }
            return
        }
        guard matchmaker == nil else { return }
        let request = GKMatchRequest()
        request.minPlayers = GameBridge.GameCenterOp.playerRange.lowerBound
        if case .start(let maxPlayers) = plan {
            request.maxPlayers = maxPlayers
        } else {
            request.maxPlayers = GameBridge.GameCenterOp.playerRange.upperBound
        }
        guard let controller = GKMatchmakerViewController(matchRequest: request) else {
            emit(.matchmaker(ok: false, reason: "failed"))
            return
        }
        controller.matchmakingMode = .inviteOnly // friends only, never strangers
        controller.matchmakerDelegate = relay
        if plan == .addPeople, let match { controller.addPlayers(to: match) }
        matchmaker = controller
        show(controller)
    }

    fileprivate func accept(_ invite: GKInvite) {
        guard let controller = GKMatchmakerViewController(invite: invite) else { return }
        controller.matchmakerDelegate = relay
        matchmaker?.dismiss(animated: false)
        matchmaker = controller
        show(controller)
    }

    fileprivate func matchmakerFinished(_ found: GKMatch?, reason: String = "cancelled") {
        matchmaker?.dismiss(animated: true)
        matchmaker = nil
        guard let found else {
            emit(.matchmaker(ok: false, reason: reason))
            return
        }
        if let old = match, old !== found {
            old.delegate = nil
            old.disconnect()
            roster.reset()
        }
        match = found
        found.delegate = relay
        for player in found.players {
            roster.connected(.init(gamePlayerID: player.gamePlayerID, alias: player.alias)).forEach(emit)
        }
    }

    /// Shows a Game Center screen over the game; at a cold launch from an invite the game may not be on screen yet.
    private func show(_ controller: UIViewController, tries: Int = 10) {
        guard var top = presenter?() else {
            guard tries > 0 else { return }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.show(controller, tries: tries - 1)
            }
            return
        }
        while let shown = top.presentedViewController { top = shown }
        guard top !== controller else { return }
        top.present(controller, animated: true)
    }

    // MARK: The match

    private func isCurrent(_ id: ObjectIdentifier) -> Bool {
        match.map { ObjectIdentifier($0) == id } ?? false
    }

    private func send(_ data: String, to ids: [String]) {
        guard let match else { return }
        let allowed = roster.recipients(ids)
        let players = match.players.filter { allowed.contains($0.gamePlayerID) }
        guard !players.isEmpty else { return }
        do { try match.send(Data(data.utf8), to: players, dataMode: .reliable) } catch {}
    }

    fileprivate func received(_ data: Data, from id: String, in matchID: ObjectIdentifier) {
        guard isCurrent(matchID), let text = String(data: data, encoding: .utf8) else { return }
        emit(.message(from: id, data: text))
    }

    fileprivate func playerChanged(_ person: GameBridge.GameCenterPerson, connected: Bool, in matchID: ObjectIdentifier) {
        guard isCurrent(matchID) else { return }
        (connected ? roster.connected(person) : roster.disconnected(person.gamePlayerID)).forEach(emit)
    }

    fileprivate func matchFailed(_ matchID: ObjectIdentifier) {
        guard isCurrent(matchID) else { return }
        for person in roster.people { roster.disconnected(person.gamePlayerID).forEach(emit) }
        dropMatch()
    }

    private func leave() {
        queued = nil
        matchmaker?.dismiss(animated: true)
        matchmaker = nil
        dropMatch()
    }

    private func dropMatch() {
        match?.delegate = nil
        match?.disconnect()
        match = nil
        roster.reset()
    }
}

/// Carries a GameKit object from a GameKit callback to the main actor, where it's used.
private struct Carry<Value>: @unchecked Sendable {
    let value: Value
}

/// GameKit's delegates. GameKit may call them on any thread, so this isn't main-actor isolated: it copies out plain
/// values (ids, data) and hands them to `GameCenter` on the main actor, in order (`GameCenterHop`).
nonisolated private final class GameCenterRelay: NSObject, GKMatchDelegate, GKMatchmakerViewControllerDelegate, GKLocalPlayerListener, @unchecked Sendable {
    weak var owner: GameCenter?

    // GKMatchmakerViewControllerDelegate
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        let owner = self.owner
        GameCenterHop.toMain { owner?.matchmakerFinished(nil) }
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: any Error) {
        let owner = self.owner
        GameCenterHop.toMain { owner?.matchmakerFinished(nil, reason: "failed") }
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        let owner = self.owner, carried = Carry(value: match)
        GameCenterHop.toMain { owner?.matchmakerFinished(carried.value) }
    }

    // GKMatchDelegate
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        let owner = self.owner, id = ObjectIdentifier(match), from = player.gamePlayerID
        GameCenterHop.toMain { owner?.received(data, from: from, in: id) }
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        let connected: Bool
        switch state {
        case .connected: connected = true
        case .disconnected: connected = false
        default: return
        }
        let owner = self.owner, id = ObjectIdentifier(match)
        let person = GameBridge.GameCenterPerson(gamePlayerID: player.gamePlayerID, alias: player.alias)
        GameCenterHop.toMain { owner?.playerChanged(person, connected: connected, in: id) }
    }

    func match(_ match: GKMatch, didFailWithError error: (any Error)?) {
        let owner = self.owner, id = ObjectIdentifier(match)
        GameCenterHop.toMain { owner?.matchFailed(id) }
    }

    /// Two-person matches only (GameKit's rule): ask Game Center to bring a dropped player back into this same match.
    /// In a match of three or four the host's page offers "Bring them back" instead, which is the `invite` (addPeople) path.
    func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
        true
    }

    // GKInviteEventListener (through GKLocalPlayerListener): a friend's invite was accepted on this phone.
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        let owner = self.owner, carried = Carry(value: invite)
        GameCenterHop.toMain { owner?.accept(carried.value) }
    }
}
