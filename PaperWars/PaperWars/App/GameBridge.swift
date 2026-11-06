import Foundation

/// The JavaScript side of the bridge, kept as plain strings so it can be unit tested.
enum GameBridge {
    static let handlerName = "paperWars"

    /// A value the page saved (or removed, when `value` is nil).
    struct Save: Equatable {
        let key: String
        let value: String?

        /// Reads a message body of the form `{key: "paperWarsInk", value: "..." | null}`.
        init?(_ body: Any) {
            guard let dict = body as? [String: Any], let key = dict["key"] as? String,
                  key.hasPrefix(CloudSaves.keyPrefix) else { return nil }
            self.key = key
            self.value = dict["value"] as? String
        }
    }

    /// A Full Arsenal request from the page: `{store: "buy" | "restore" | "status"}`.
    enum StoreRequest: String, Equatable {
        case buy, restore, status

        init?(_ body: Any) {
            guard let dict = body as? [String: Any], let raw = dict["store"] as? String else { return nil }
            self.init(rawValue: raw)
        }
    }

    /// A finished replay video the page wants to save or share: `{video: "<base64 mp4>", name: "paper-wars-replay.mp4"}`.
    struct VideoShare: Equatable {
        let data: Data
        let name: String

        init?(_ body: Any) {
            guard let dict = body as? [String: Any], let base64 = dict["video"] as? String,
                  let data = Data(base64Encoded: base64), !data.isEmpty else { return nil }
            let raw = (dict["name"] as? String) ?? "paper-wars-replay.mp4"
            // Only a plain file name: no folders, and always an .mp4.
            let safe = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
            self.data = data
            self.name = safe.hasSuffix(".mp4") ? safe : safe + ".mp4"
        }
    }

    /// A Game Center request from the page (two-phone multiplayer): `{type: "gc", op, ...}` with op
    /// `auth`, `host {maxPlayers}`, `invite`, `send {to: [gamePlayerID], data: "<JSON string>"}` or `leave`.
    enum GameCenterOp: Equatable {
        case auth
        case host(maxPlayers: Int)
        case invite
        case send(to: [String], data: String)
        case leave

        /// Game Center real-time matches here are 2 players plus up to 2 spectators.
        static let playerRange = 2...4

        init?(_ body: Any) {
            guard let dict = body as? [String: Any], dict["type"] as? String == "gc", let op = dict["op"] as? String else { return nil }
            switch op {
            case "auth": self = .auth
            case "host":
                let asked = dict["maxPlayers"] as? Int ?? Self.playerRange.upperBound
                self = .host(maxPlayers: min(max(asked, Self.playerRange.lowerBound), Self.playerRange.upperBound))
            case "invite": self = .invite
            case "send":
                guard let list = dict["to"] as? [Any], let data = dict["data"] as? String else { return nil }
                let ids = list.compactMap { $0 as? String }
                guard !ids.isEmpty, ids.count == list.count else { return nil }
                self = .send(to: ids, data: data)
            case "leave": self = .leave
            default: return nil
            }
        }
    }

    /// Someone in the Game Center match (never the player on this phone).
    struct GameCenterPerson: Equatable {
        let gamePlayerID: String
        let alias: String
    }

    /// What the app tells the page about Game Center, through `window.gcEvent(...)`.
    enum GameCenterEvent: Equatable {
        case auth(ok: Bool, gamePlayerID: String?, reason: String?)
        case people([GameCenterPerson])
        case message(from: String, data: String)
        case left(String)
        case back(String)

        var payload: [String: Any] {
            switch self {
            case let .auth(ok, gamePlayerID, reason):
                var out: [String: Any] = ["event": "auth", "ok": ok]
                if let gamePlayerID { out["gamePlayerID"] = gamePlayerID }
                if let reason { out["reason"] = reason }
                return out
            case .people(let people):
                return ["event": "people", "players": people.map { ["gamePlayerID": $0.gamePlayerID, "alias": $0.alias] }]
            case let .message(from, data):
                return ["event": "message", "from": from, "data": data]
            case .left(let id):
                return ["event": "left", "id": id, "gamePlayerID": id]
            case .back(let id):
                return ["event": "back", "id": id, "gamePlayerID": id]
            }
        }
    }

    static func gcEventScript(_ event: GameCenterEvent) -> String {
        "window.gcEvent && window.gcEvent(\(json(event.payload)));"
    }

    /// The share sheet closed: `saved` is true when the player picked somewhere for the video.
    static func videoSharedScript(saved: Bool) -> String {
        "window.paperWarsVideo && window.paperWarsVideo.done(\(saved));"
    }

    /// Tells the page whether the Full Arsenal is owned, and its local price.
    static func arsenalScript(owned: Bool, price: String?) -> String {
        "window.paperWarsArsenal && window.paperWarsArsenal.set(\(owned), \(price.map { json($0) } ?? "null"));"
    }

    /// A purchase didn't go through; an empty message means the player cancelled.
    static func arsenalFailedScript(_ message: String) -> String {
        "window.paperWarsArsenal && window.paperWarsArsenal.failed(\(json(message)));"
    }

    /// Runs before the page's own scripts: puts the saved values into localStorage, then wraps
    /// localStorage so every later save of a `paperWars…` key is also sent to the app. Also exposes
    /// `window.paperWarsNative` with the current posture.
    static func startScript(saved: [String: String], posture: Posture) -> String {
        """
        (() => {
          const saved = \(json(saved));
          try { for (const k of Object.keys(saved)) localStorage.setItem(k, saved[k]); } catch (e) {}
          const set = Storage.prototype.setItem, remove = Storage.prototype.removeItem;
          const post = (key, value) => {
            key = String(key);
            if (!key.startsWith("\(CloudSaves.keyPrefix)")) return;
            try { window.webkit.messageHandlers.\(handlerName).postMessage({key, value}); } catch (e) {}
          };
          Storage.prototype.setItem = function (k, v) { set.call(this, k, v); if (this === window.localStorage) post(k, String(v)); };
          Storage.prototype.removeItem = function (k) { remove.call(this, k); if (this === window.localStorage) post(k, null); };
          window.paperWarsNative = {
            app: true,
            posture: \(json(posture.rawValue)),
            setPosture(p) { this.posture = p; window.dispatchEvent(new CustomEvent("paperwarsposture", {detail: p})); },
            stored(k, v) { try { v == null ? remove.call(localStorage, k) : set.call(localStorage, k, v); } catch (e) {} },
          };
        })();
        """
    }

    static func postureScript(_ posture: Posture) -> String {
        "window.paperWarsNative && window.paperWarsNative.setPosture(\(json(posture.rawValue)));"
    }

    /// Another device changed a value in iCloud: update the page's copy without echoing it back.
    static func storedScript(key: String, value: String?) -> String {
        "window.paperWarsNative && window.paperWarsNative.stored(\(json(key)), \(value.map { json($0) } ?? "null"));"
    }

    /// A JSON literal for a string or a string dictionary, safe to drop into JavaScript.
    static func json(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "null" }
        // U+2028/2029 are valid in JSON but end a line in older JavaScript.
        return text.replacingOccurrences(of: "\u{2028}", with: "\\u2028").replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}
