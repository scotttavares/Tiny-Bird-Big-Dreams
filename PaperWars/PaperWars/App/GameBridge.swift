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
