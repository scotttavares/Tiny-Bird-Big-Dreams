import Foundation
import Observation

/// Somewhere to keep string values: iCloud's key-value store, UserDefaults, or a test double.
@MainActor
protocol SaveBacking: AnyObject {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
    var keys: [String] { get }
}

/// The player's saved game data (settings, ink colours, soldier names, stats, medals).
///
/// Every value is written to the player's own iCloud key-value store, so it survives a reinstall
/// and follows them to a new phone, and to UserDefaults, so it still works offline or when
/// they aren't signed in to iCloud. On launch the iCloud copy wins, since it's the newest across
/// devices. Nothing is sent anywhere else.
@MainActor
@Observable
final class CloudSaves {
    /// Only the game's own keys are saved; anything else the page stores stays in the page.
    nonisolated static let keyPrefix = "paperWars"

    private let cloud: SaveBacking
    private let local: SaveBacking
    private(set) var values: [String: String] = [:]
    /// Called when another device changes a value in iCloud.
    @ObservationIgnored var onExternalChange: ((String, String?) -> Void)?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(cloud: SaveBacking = CloudBacking(), local: SaveBacking = DefaultsBacking()) {
        self.cloud = cloud
        self.local = local
        for key in local.keys where key.hasPrefix(Self.keyPrefix) {
            values[key] = local.string(forKey: key)
        }
        for key in cloud.keys where key.hasPrefix(Self.keyPrefix) {
            guard let value = cloud.string(forKey: key) else { continue }
            values[key] = value
            local.set(value, forKey: key)
        }
        if cloud is CloudBacking {
            observer = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: NSUbiquitousKeyValueStore.default,
                queue: .main
            ) { [weak self] note in
                let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
                MainActor.assumeIsolated { self?.cloudChanged(keys: keys) }
            }
        }
    }

    func set(_ value: String?, forKey key: String) {
        guard key.hasPrefix(Self.keyPrefix), values[key] != value else { return }
        values[key] = value
        local.set(value, forKey: key)
        cloud.set(value, forKey: key)
    }

    /// Values changed on another device: take them, and tell the page.
    func cloudChanged(keys: [String]) {
        for key in keys where key.hasPrefix(Self.keyPrefix) {
            let value = cloud.string(forKey: key)
            guard values[key] != value else { continue }
            values[key] = value
            local.set(value, forKey: key)
            onExternalChange?(key, value)
        }
    }
}

/// The player's iCloud key-value store (up to 1 MB, synced by the system).
@MainActor
final class CloudBacking: SaveBacking {
    private var store: NSUbiquitousKeyValueStore { .default }

    init() {
        store.synchronize()
    }

    func string(forKey key: String) -> String? { store.string(forKey: key) }
    func set(_ value: String?, forKey key: String) {
        if let value { store.set(value, forKey: key) } else { store.removeObject(forKey: key) }
    }
    var keys: [String] { Array(store.dictionaryRepresentation.keys) }
}

/// The on-device copy.
@MainActor
final class DefaultsBacking: SaveBacking {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? { defaults.string(forKey: key) }
    func set(_ value: String?, forKey key: String) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
    var keys: [String] { Array(defaults.dictionaryRepresentation().keys) }
}
