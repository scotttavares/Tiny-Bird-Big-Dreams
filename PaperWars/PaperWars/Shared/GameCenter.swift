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

    /// Nobody else is connected. A match in this state is dead weight: GameKit doesn't bring a dropped player back into it
    /// (logs, 2026-11-23: the other phone's match fails outright), and while this phone holds it, a fresh invite hangs on
    /// "Connecting" and Invite friends adds people to it instead of starting a new match.
    var isEmpty: Bool { people.isEmpty }

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

/// A short on-device diary of what Game Center did (sign-in, invites, screens shown, errors), so a failed invite can be
/// traced: the page's "Game Center log" button shows it. Kept across launches (an invite can cold-launch the app), never sent anywhere.
@MainActor
enum GameCenterLog {
    private static let key = "gameCenterLog"
    private static let limit = 300
    private static var lines: [String] = UserDefaults.standard.stringArray(forKey: key) ?? []

    static func add(_ text: String) {
        let stamp = Date.now.formatted(.dateTime.month(.abbreviated).day().hour().minute().second())
        lines.append("\(stamp)  \(text)")
        if lines.count > limit { lines.removeFirst(lines.count - limit) }
        UserDefaults.standard.set(lines, forKey: key)
    }

    static var text: String { lines.isEmpty ? "Nothing logged yet." : lines.joined(separator: "\n") }

    static func clear() {
        lines = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// An error as "domain code: message", e.g. "GKErrorDomain 3: The requested operation could not be completed".
    nonisolated static func describe(_ error: (any Error)?) -> String {
        guard let error else { return "no error" }
        let ns = error as NSError
        return "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
    }
}

/// Shows the Game Center log with Copy and Clear, so it can be pasted into a message.
@MainActor
final class GameCenterLogController: UIViewController {
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Game Center log"
        view.backgroundColor = .systemBackground
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.text = GameCenterLog.text
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(title: "Copy", primaryAction: UIAction { _ in UIPasteboard.general.string = GameCenterLog.text }),
            UIBarButtonItem(title: "Clear", primaryAction: UIAction { [weak self] _ in
                GameCenterLog.clear()
                self?.textView.text = GameCenterLog.text
            }),
        ]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.scrollRangeToVisible(NSRange(location: (textView.text as NSString).length, length: 0))
    }
}

extension GameBridge.GameCenterOp {
    /// For the log: the op without its data.
    var logName: String {
        switch self {
        case .auth: "sign in"
        case .host(let maxPlayers): "host (up to \(maxPlayers))"
        case .invite: "invite"
        case .send: "send"
        case .leave: "leave"
        case .log: "show log"
        }
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

        var logName: String {
            switch self {
            case .unknown: "not known yet"
            case .ready: "signed in"
            case .needsSignIn: "needs sign-in"
            case .failed(let reason): "can't use Game Center (\(reason))"
            }
        }
    }

    private var status = Status.unknown {
        didSet { GameCenterLog.add("status: \(status.logName)") }
    }
    private var started = false
    private var registered = false
    /// The page asked to sign in ("Play friends online"); until then sign-in results aren't pushed to it.
    private var pageAsked = false
    /// The page has been told `auth ok` (it hears nothing about a match before that).
    private var pageKnowsAuth = false
    /// host / invite waiting for sign-in to finish.
    private var queued: GameBridge.GameCenterOp?
    private var match: GKMatch?
    /// Matches this phone has let go of, kept alive a while. GameKit keeps working on a match after it's disconnected (crash,
    /// 1.1 (59), 2026-11-26: -[GKMatch conditionallyReinvitePlayer:sessionToken:] ran on a match already freed, a moment
    /// after this phone let it go), so a dropped match is never freed straight away. A few at most.
    private var retired: [GKMatch] = []
    private var roster = GameCenterRoster()
    private var matchmaker: GKMatchmakerViewController?
    private let relay = GameCenterRelay()

    init() {
        relay.owner = self
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?", build = info?["CFBundleVersion"] as? String ?? "?"
        GameCenterLog.add("app launched, \(version) (\(build)), \(UIDevice.current.model) iOS \(UIDevice.current.systemVersion)")
    }

    /// Signs in at launch (Game Center shows its "Welcome back" banner), so invites from friends can arrive.
    /// If the player isn't signed in, Apple's sign-in screen is kept until they tap "Play friends online".
    func start() {
        guard !started else { return }
        started = true
        GameCenterLog.add("sign-in started")
        // GameKit may call this off the main thread, so it isn't main-actor isolated; it hops over.
        GKLocalPlayer.local.authenticateHandler = { @Sendable [weak self] controller, error in
            let carried = Carry(value: controller), owner = self
            GameCenterHop.toMain { owner?.authChanged(carried.value, error) }
        }
    }

    func handle(_ op: GameBridge.GameCenterOp) {
        switch op {
        case .send, .log: break
        default: GameCenterLog.add("page asked: \(op.logName)")
        }
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
        case .log:
            show(UINavigationController(rootViewController: GameCenterLogController()), label: "log")
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
        let local = GKLocalPlayer.local
        GameCenterLog.add("sign-in callback: \(controller != nil ? "Apple's sign-in screen needed" : "no screen"), authenticated \(local.isAuthenticated), alias \(local.isAuthenticated ? local.alias : "-"), multiplayer restricted \(local.isMultiplayerGamingRestricted), \(GameCenterLog.describe(error))")
        if let controller {
            status = .needsSignIn(controller)
            signInChanged()
            if pageAsked, controller.presentingViewController == nil { show(controller) }
            return
        }
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
                GameCenterLog.add("listening for invites")
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
        let plan = GameCenterMatchmaking.plan(for: op, hasMatch: match != nil && !roster.isEmpty)
        guard plan != .ignore else { GameCenterLog.add("invite screen: nothing to do (no match yet)"); return }
        guard case .ready = status else {
            GameCenterLog.add("invite screen: not signed in yet, \(status.logName)")
            if case .failed = status { emit(.matchmaker(ok: false, reason: "signed-out")) } else { queued = op }
            return
        }
        guard matchmaker == nil else { GameCenterLog.add("invite screen: one is already open"); return }
        let request = GKMatchRequest()
        request.minPlayers = GameBridge.GameCenterOp.playerRange.lowerBound
        if case .start(let maxPlayers) = plan {
            request.maxPlayers = maxPlayers
        } else {
            request.maxPlayers = GameBridge.GameCenterOp.playerRange.upperBound
        }
        guard let controller = GKMatchmakerViewController(matchRequest: request) else {
            GameCenterLog.add("invite screen: GameKit couldn't make one")
            emit(.matchmaker(ok: false, reason: "failed"))
            return
        }
        controller.matchmakingMode = .inviteOnly // friends only, never strangers
        controller.matchmakerDelegate = relay
        if plan == .addPeople, let match { controller.addPlayers(to: match) }
        matchmaker = controller
        GameCenterLog.add("invite screen: opening, \(request.minPlayers)-\(request.maxPlayers) players, \(plan == .addPeople ? "adding to the match" : "new match")")
        show(controller, label: "invite screen")
    }

    fileprivate func accept(_ invite: GKInvite, sender: String) {
        GameCenterLog.add("invite accepted from \(sender), \(status.logName)")
        guard let controller = GKMatchmakerViewController(invite: invite) else {
            GameCenterLog.add("join screen: GameKit couldn't make one for this invite")
            return
        }
        controller.matchmakerDelegate = relay
        if match != nil, roster.isEmpty {
            GameCenterLog.add("join screen: letting go of the old match first (nobody else was in it)")
            dropMatch()
        }
        if let old = matchmaker {
            GameCenterLog.add("join screen: closing the invite screen that was open")
            old.dismiss(animated: false)
        }
        matchmaker = controller
        show(controller, label: "join screen")
    }

    fileprivate func matchmakerFinished(_ found: GKMatch?, reason: String = "cancelled") {
        GameCenterLog.add(found.map { "match found, \($0.players.count) other player(s), waiting for \($0.expectedPlayerCount) more" } ?? "invite/join screen closed: \(reason)")
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

    /// Shows a Game Center screen over the game. At a cold launch from an invite the game may not be on screen yet, and
    /// another screen (one being dismissed, the sign-in sheet) may be mid-animation, when UIKit drops `present` without a
    /// word; so it waits and tries again until the screen is really up, for about 10 seconds, logging each step. If it
    /// never comes up, an invite or join screen is let go (so the next tap can open one) and the page hears "failed".
    private func show(_ controller: UIViewController, label: String = "sign-in screen", tries: Int = 20) {
        guard controller.presentingViewController == nil else { return } // already up
        let first = tries == 20
        let again: @MainActor () -> Void = { [weak self] in
            guard tries > 0 else {
                GameCenterLog.add("\(label): gave up, it never came up")
                guard let self, self.matchmaker === controller else { return }
                self.matchmaker = nil
                self.emit(.matchmaker(ok: false, reason: "failed"))
                return
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.show(controller, label: label, tries: tries - 1)
            }
        }
        guard var top = presenter?() else {
            if first { GameCenterLog.add("\(label): the game isn't on screen yet, waiting") }
            again()
            return
        }
        while let shown = top.presentedViewController, !shown.isBeingDismissed { top = shown }
        guard top !== controller else { return }
        if top.isBeingPresented || top.isBeingDismissed || top.presentedViewController != nil {
            if first { GameCenterLog.add("\(label): another screen is moving (\(type(of: top))), waiting") }
            again()
            return
        }
        GameCenterLog.add("\(label): showing over \(type(of: top))")
        let flag = ShownFlag()
        top.present(controller, animated: true) {
            flag.on = true
            GameCenterLog.add("\(label): on screen")
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            // not up and never was (closed again by the player is fine)
            guard !flag.on, controller.presentingViewController == nil else { return }
            GameCenterLog.add("\(label): didn't come up, trying again")
            again()
        }
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
        GameCenterLog.add("\(person.alias) \(connected ? "connected" : "disconnected")")
        guard isCurrent(matchID) else { return }
        (connected ? roster.connected(person) : roster.disconnected(person.gamePlayerID)).forEach(emit)
        // User, 2026-11-23: after Go AWOL "we both have to close out our apps then re open in order to connect".
        if !connected, roster.isEmpty {
            GameCenterLog.add("everyone else has left: letting the match go")
            dropMatch()
        }
    }

    fileprivate func matchFailed(_ matchID: ObjectIdentifier, _ error: String) {
        GameCenterLog.add("match failed: \(error)")
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
        if let old = match {
            old.delegate = nil
            old.disconnect()
            retired.append(old) // not freed yet: GameKit may still be finishing with it
            if retired.count > 4 { retired.removeFirst(retired.count - 4) }
        }
        match = nil
        roster.reset()
    }
}

/// Set once a screen has finished coming up, so a screen the player has already closed isn't shown again.
@MainActor
private final class ShownFlag {
    var on = false
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
        let owner = self.owner, text = GameCenterLog.describe(error)
        GameCenterHop.toMain {
            GameCenterLog.add("invite/join screen error: \(text)")
            owner?.matchmakerFinished(nil, reason: "failed")
        }
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
        let owner = self.owner, id = ObjectIdentifier(match), text = GameCenterLog.describe(error)
        GameCenterHop.toMain { owner?.matchFailed(id, text) }
    }

    /// No: GameKit's own re-invite never brought anyone back in testing (a dropped phone's match fails outright, logs
    /// 2026-11-23), and its re-invite step crashed the app on a match that had just been let go (1.1 (59), 2026-11-26).
    /// In a match of three or four the host's page offers "Bring them back" instead, which is the `invite` (addPeople) path.
    func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
        false
    }

    // GKInviteEventListener (through GKLocalPlayerListener): a friend's invite was accepted on this phone.
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        let owner = self.owner, carried = Carry(value: invite), sender = invite.sender.alias
        GameCenterHop.toMain { owner?.accept(carried.value, sender: sender) }
    }

    // Started from the Game Center app ("Play with friends"), not from an invite: only logged, to see whether it happens.
    func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
        let count = recipientPlayers.count
        GameCenterHop.toMain { GameCenterLog.add("Game Center asked for a match with \(count) player(s) (not handled)") }
    }
}
