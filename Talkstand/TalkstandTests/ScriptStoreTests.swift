import Foundation
import Testing
@testable import Talkstand

@MainActor
@Suite("ScriptStore")
struct ScriptStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "scripts-\(UUID().uuidString).json")
    }

    @Test func firstLaunchHasTheSample() {
        let store = ScriptStore(fileURL: tempURL())
        #expect(store.scripts.count == 1)
        #expect(store.scripts.first?.body == Script.sample.body)
    }

    @Test func savesAndReloads() {
        let url = tempURL()
        let store = ScriptStore(fileURL: url)
        var script = store.create()
        script.body = "Hello there."
        store.update(script)

        let reopened = ScriptStore(fileURL: url)
        #expect(reopened.script(id: script.id)?.body == "Hello there.")
        #expect(reopened.scripts.count == 2)
    }

    @Test func deletingTheLastScriptStaysEmpty() {
        let url = tempURL()
        let store = ScriptStore(fileURL: url)
        for script in store.scripts { store.delete(id: script.id) }
        #expect(ScriptStore(fileURL: url).scripts.isEmpty)
    }

    @Test func displayTitleFallsBackToFirstLine() {
        #expect(Script(body: "  Hey Grandma\nIt's me").displayTitle == "Hey Grandma")
        #expect(Script().displayTitle == "Untitled")
        #expect(Script(title: "Team news", body: "x").displayTitle == "Team news")
    }

    @Test func durationFollowsPace() {
        let script = Script(body: Array(repeating: "word", count: 140).joined(separator: " "))
        #expect(script.duration(wordsPerMinute: 140) == 60)
    }
}
