import Foundation
import GameKit
import Testing
@testable import PaperWars

/// Game Center bridge (two-phone multiplayer, Task 5): what the page asks for and what it's told.
struct GameCenterBridgeTests {
    @Test func testParsesGcOps() {
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "auth"]) == .auth)
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "host", "maxPlayers": 4]) == .host(maxPlayers: 4))
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "host"]) == .host(maxPlayers: 4))
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "host", "maxPlayers": 16]) == .host(maxPlayers: 4))
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "host", "maxPlayers": 1]) == .host(maxPlayers: 2))
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "invite"]) == .invite)
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "leave"]) == .leave)
        let data = "{\"v\":1,\"t\":\"hello\"}"
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "send", "to": ["G:2", "G:3"], "data": data]) == .send(to: ["G:2", "G:3"], data: data))
        // a send must name its recipients and carry the page's JSON string unchanged
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "send", "to": [String](), "data": data]) == nil)
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "send", "data": data]) == nil)
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "send", "to": ["G:2", 7] as [Any], "data": data]) == nil)
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "send", "to": ["G:2"], "data": ["t": "hello"]]) == nil)
        // other messages aren't Game Center's, and Game Center's aren't anyone else's
        #expect(GameBridge.GameCenterOp(["type": "gc", "op": "steal"]) == nil)
        #expect(GameBridge.GameCenterOp(["op": "auth"]) == nil)
        #expect(GameBridge.GameCenterOp(["store": "buy"]) == nil)
        #expect(GameBridge.GameCenterOp(["key": "paperWarsInk", "value": "x"]) == nil)
        #expect(GameBridge.GameCenterOp("nonsense") == nil)
        #expect(GameBridge.Save(["type": "gc", "op": "auth"]) == nil)
        #expect(GameBridge.StoreRequest(["type": "gc", "op": "auth"]) == nil)
    }

    @Test func testEventScriptEscapesJSON() throws {
        let data = "{\"t\":\"taunt\",\"line\":\"a\\\"b\u{2028}c</script>\"}"
        let script = GameBridge.gcEventScript(.message(from: "G:2'\"", data: data))
        #expect(script.hasPrefix("window.gcEvent && window.gcEvent({"))
        #expect(script.hasSuffix("});"))
        #expect(!script.contains("\u{2028}"))
        #expect(script.contains("\\u2028"))
        // what's between the parentheses is JSON that gives back exactly what was sent
        let start = try #require(script.range(of: "gcEvent(", options: .backwards)).upperBound
        let end = try #require(script.range(of: ");", options: .backwards)).lowerBound
        let parsed = try #require(try JSONSerialization.jsonObject(with: Data(script[start..<end].utf8)) as? [String: Any])
        #expect(parsed["event"] as? String == "message")
        #expect(parsed["from"] as? String == "G:2'\"")
        #expect(parsed["data"] as? String == data)

        let people = GameBridge.gcEventScript(.people([.init(gamePlayerID: "G:2", alias: "Sam \"The Tank\"")]))
        #expect(people.contains("\"players\":[{\"alias\":\"Sam \\\"The Tank\\\"\",\"gamePlayerID\":\"G:2\"}]"))
        #expect(GameBridge.gcEventScript(.auth(ok: false, gamePlayerID: nil, reason: "notSignedIn"))
            == "window.gcEvent && window.gcEvent({\"event\":\"auth\",\"ok\":false,\"reason\":\"notSignedIn\"});")
        #expect(GameBridge.gcEventScript(.auth(ok: true, gamePlayerID: "G:1", reason: nil)).contains("{\"event\":\"auth\",\"gamePlayerID\":\"G:1\",\"ok\":true}"))
        #expect(GameBridge.gcEventScript(.left("G:2")).contains("\"event\":\"left\""))
        #expect(GameBridge.gcEventScript(.back("G:2")).contains("\"id\":\"G:2\""))
    }

    @Test func testSendRejectsUnknownRecipients() {
        var roster = GameCenterRoster()
        roster.me = "G:1"
        _ = roster.connected(.init(gamePlayerID: "G:2", alias: "B"))
        _ = roster.connected(.init(gamePlayerID: "G:3", alias: "C"))
        #expect(roster.recipients(["G:2"]) == ["G:2"])
        #expect(roster.recipients(["G:3", "G:2", "G:3"]) == ["G:3", "G:2"])
        // strangers, this phone's own player and anyone who has left are never sent to
        #expect(roster.recipients(["G:9"]).isEmpty)
        #expect(roster.recipients(["G:1", "G:9", "G:2"]) == ["G:2"])
        _ = roster.disconnected("G:3")
        #expect(roster.recipients(["G:3"]).isEmpty)
        roster.reset()
        #expect(roster.recipients(["G:2"]).isEmpty)
    }

    @Test func testRosterEventsForDropsAndReturns() {
        var roster = GameCenterRoster()
        roster.me = "G:1"
        let b = GameBridge.GameCenterPerson(gamePlayerID: "G:2", alias: "B")
        #expect(roster.connected(.init(gamePlayerID: "G:1", alias: "Me")).isEmpty) // never lists this phone's player
        #expect(roster.connected(b) == [.people([b])])
        #expect(roster.connected(b).isEmpty) // already here
        #expect(roster.disconnected("G:2") == [.left("G:2"), .people([])])
        #expect(roster.disconnected("G:2").isEmpty)
        #expect(roster.connected(b) == [.back("G:2"), .people([b])]) // the same player back in the match
    }

    @Test func testAuthFailureReasons() {
        #expect(GameCenter.reason(for: nil) == "notSignedIn")
        #expect(GameCenter.reason(for: GKError(.cancelled)) == "notSignedIn")
        #expect(GameCenter.reason(for: GKError(.notAuthenticated)) == "notSignedIn")
        #expect(GameCenter.reason(for: GKError(.parentalControlsBlocked)) == "restricted")
        #expect(GameCenter.reason(for: GKError(.underage)) == "restricted")
        #expect(GameCenter.reason(for: GKError(.communicationsFailure)) == "offline")
        #expect(GameCenter.reason(for: GKError(.gameUnrecognized)) == "unavailable")
    }
}
