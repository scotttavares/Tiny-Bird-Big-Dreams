import Foundation
import SwiftUI

/// Best stars per level, persisted in UserDefaults.
@MainActor
final class ProgressStore: ObservableObject {
    static let key = "MoodMagnets.stars.v1"

    @Published private(set) var stars: [Int: Int]
    let levels: [LevelData]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, levels: [LevelData] = LevelCatalog.load()) {
        self.defaults = defaults
        self.levels = levels
        if ProcessInfo.processInfo.arguments.contains("-MMResetProgress") {
            defaults.removeObject(forKey: Self.key)
        }
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            stars = decoded
        } else {
            stars = [:]
        }
        if ProcessInfo.processInfo.arguments.contains("-MMUnlockAll") {
            for level in levels where stars[level.id] == nil { stars[level.id] = 0 }
        }
    }

    func stars(for level: LevelData) -> Int { stars[level.id] ?? 0 }

    func isCompleted(_ level: LevelData) -> Bool { (stars[level.id] ?? 0) > 0 }

    func isUnlocked(_ level: LevelData) -> Bool {
        guard let index = levels.firstIndex(where: { $0.id == level.id }) else { return false }
        if index == 0 || stars[level.id] != nil { return true }
        return isCompleted(levels[index - 1])
    }

    func record(_ level: LevelData, stars earned: Int) {
        if earned > (stars[level.id] ?? 0) {
            stars[level.id] = earned
            if let data = try? JSONEncoder().encode(stars) {
                defaults.set(data, forKey: Self.key)
            }
        }
    }

    func next(after level: LevelData) -> LevelData? {
        guard let index = levels.firstIndex(where: { $0.id == level.id }), index + 1 < levels.count else { return nil }
        return levels[index + 1]
    }

    /// The first level not yet completed (or the last one).
    var resumeLevel: LevelData? {
        levels.first { !isCompleted($0) } ?? levels.last
    }

    var totalStars: Int { stars.values.reduce(0, +) }
}
