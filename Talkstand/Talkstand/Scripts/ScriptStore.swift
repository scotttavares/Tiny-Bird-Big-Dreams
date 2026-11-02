import Foundation
import Observation

/// Saves scripts as one JSON file on the device. Small, private, no account.
@MainActor
@Observable
final class ScriptStore {
    private(set) var scripts: [Script] = []
    private let fileURL: URL

    init(fileURL: URL = ScriptStore.defaultURL) {
        self.fileURL = fileURL
        load()
        if scripts.isEmpty && !FileManager.default.fileExists(atPath: fileURL.path) {
            scripts = [.sample]
            save()
        }
    }

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "scripts.json")
    }

    /// Newest first.
    var sorted: [Script] {
        scripts.sorted { $0.updatedAt > $1.updatedAt }
    }

    func script(id: Script.ID) -> Script? {
        scripts.first { $0.id == id }
    }

    @discardableResult
    func create() -> Script {
        let script = Script()
        scripts.append(script)
        save()
        return script
    }

    func update(_ script: Script) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        guard scripts[index] != script else { return }
        var changed = script
        changed.updatedAt = .now
        scripts[index] = changed
        save()
    }

    func delete(id: Script.ID) {
        scripts.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        scripts = (try? JSONDecoder().decode([Script].self, from: data)) ?? []
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(scripts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Could not save scripts: \(error)")
        }
    }
}
