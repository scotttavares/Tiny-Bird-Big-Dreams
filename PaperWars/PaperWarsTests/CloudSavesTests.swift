import Foundation
import Testing
@testable import PaperWars

@MainActor
final class MemoryBacking: SaveBacking {
    var storage: [String: String]
    init(_ storage: [String: String] = [:]) { self.storage = storage }
    func string(forKey key: String) -> String? { storage[key] }
    func set(_ value: String?, forKey key: String) { storage[key] = value }
    var keys: [String] { Array(storage.keys) }
}

@MainActor
struct CloudSavesTests {
    @Test func iCloudWinsOverTheDeviceCopyOnLaunch() {
        let cloud = MemoryBacking(["paperWarsInk": "[\"#1f4fa8\",\"#1e7a46\"]"])
        let local = MemoryBacking(["paperWarsInk": "[\"#000000\",\"#ffffff\"]", "paperWarsVoices": "off"])
        let saves = CloudSaves(cloud: cloud, local: local)
        #expect(saves.values["paperWarsInk"] == "[\"#1f4fa8\",\"#1e7a46\"]")
        #expect(saves.values["paperWarsVoices"] == "off")
        #expect(local.storage["paperWarsInk"] == "[\"#1f4fa8\",\"#1e7a46\"]")
    }

    @Test func savesGoToBothICloudAndTheDevice() {
        let cloud = MemoryBacking(), local = MemoryBacking()
        let saves = CloudSaves(cloud: cloud, local: local)
        saves.set("on", forKey: "paperWarsVoices")
        #expect(cloud.storage["paperWarsVoices"] == "on")
        #expect(local.storage["paperWarsVoices"] == "on")
        saves.set(nil, forKey: "paperWarsVoices")
        #expect(cloud.storage["paperWarsVoices"] == nil)
        #expect(saves.values["paperWarsVoices"] == nil)
    }

    @Test func onlyTheGamesOwnKeysAreKept() {
        let cloud = MemoryBacking(["somethingElse": "x"]), local = MemoryBacking(["AppleLanguages": "en"])
        let saves = CloudSaves(cloud: cloud, local: local)
        #expect(saves.values.isEmpty)
        saves.set("1", forKey: "notOurs")
        #expect(cloud.storage["notOurs"] == nil)
    }

    @Test func changesFromAnotherDeviceReachThePage() {
        let cloud = MemoryBacking(), local = MemoryBacking()
        let saves = CloudSaves(cloud: cloud, local: local)
        var heard: [(String, String?)] = []
        saves.onExternalChange = { heard.append(($0, $1)) }
        cloud.storage["paperWarsStats"] = "{\"wins\":3}"
        saves.cloudChanged(keys: ["paperWarsStats", "otherApp"])
        #expect(heard.count == 1)
        #expect(heard.first?.0 == "paperWarsStats")
        #expect(local.storage["paperWarsStats"] == "{\"wins\":3}")
        saves.cloudChanged(keys: ["paperWarsStats"]) // unchanged: no second call
        #expect(heard.count == 1)
    }
}

struct GameBridgeTests {
    @Test func readsSavesFromThePage() {
        #expect(GameBridge.Save(["key": "paperWarsInk", "value": "x"])?.value == "x")
        #expect(GameBridge.Save(["key": "paperWarsInk", "value": NSNull()])?.value == nil)
        #expect(GameBridge.Save(["key": "stranger", "value": "x"]) == nil)
        #expect(GameBridge.Save("nonsense") == nil)
    }

    @Test func startScriptCarriesSavesAndPosture() {
        let script = GameBridge.startScript(saved: ["paperWarsVoices": "off\u{2028}"], posture: .tent)
        #expect(script.contains("\"paperWarsVoices\":\"off\\u2028\""))
        #expect(script.contains("posture: \"tent\""))
        #expect(script.contains("messageHandlers.paperWars"))
    }

    @Test func storedScriptEscapes() {
        #expect(GameBridge.storedScript(key: "paperWarsX", value: nil).contains("(\"paperWarsX\", null)"))
        #expect(GameBridge.storedScript(key: "paperWarsX", value: "a\"b").contains("\"a\\\"b\""))
    }
}

struct StoreBridgeTests {
    @Test func readsStoreRequests() {
        #expect(GameBridge.StoreRequest(["store": "buy"]) == .buy)
        #expect(GameBridge.StoreRequest(["store": "restore"]) == .restore)
        #expect(GameBridge.StoreRequest(["store": "status"]) == .status)
        #expect(GameBridge.StoreRequest(["store": "steal"]) == nil)
        #expect(GameBridge.StoreRequest(["key": "paperWarsInk", "value": "x"]) == nil)
    }

    @Test func arsenalScriptsTellThePage() {
        #expect(GameBridge.arsenalScript(owned: true, price: "$4.99").contains("set(true, \"$4.99\")"))
        #expect(GameBridge.arsenalScript(owned: false, price: nil).contains("set(false, null)"))
        #expect(GameBridge.arsenalFailedScript("No \"luck\"").contains("failed(\"No \\\"luck\\\"\")"))
    }

    @Test func storeMessagesAreNotSaves() {
        #expect(GameBridge.Save(["store": "buy"]) == nil)
    }
}

struct PostureMapperTests {
    @Test func tentWhenAHorizontalFoldIsHalfOpen() {
        let inputs = PostureInputs(hingeStatus: .partiallyOpen, hingeAngleDegrees: 70,
                                   activeDivision: CGRect(x: 0, y: 400, width: 400, height: 20),
                                   containerSize: CGSize(width: 400, height: 820))
        #expect(PostureMapper.posture(for: inputs) == .tent)
    }

    @Test func laptopWhenOpenedWider() {
        let inputs = PostureInputs(hingeStatus: .partiallyOpen, hingeAngleDegrees: 120,
                                   activeDivision: CGRect(x: 0, y: 400, width: 400, height: 20),
                                   containerSize: CGSize(width: 400, height: 820))
        #expect(PostureMapper.posture(for: inputs) == .laptop)
    }

    @Test func plainPhoneIsClosed() {
        #expect(PostureMapper.posture(for: PostureInputs(containerSize: CGSize(width: 390, height: 844))) == .closed)
    }
}
