import Foundation
import Testing
@testable import FieldGuide

@MainActor
struct AppLockTests {
    private func freshDefaults() -> UserDefaults {
        let name = "AppLockTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func theLockIsOffByDefault() {
        let lock = AppLock(defaults: freshDefaults())
        #expect(!lock.isEnabled)
        #expect(!lock.isLocked)
        #expect(lock.delay == .immediately)
    }

    @Test func aTurnedOnLockStartsLocked() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: AppLock.enabledKey)
        defaults.set(LockDelay.fiveMinutes.rawValue, forKey: AppLock.delayKey)
        let lock = AppLock(defaults: defaults)
        #expect(lock.isEnabled)
        #expect(lock.isLocked)
        #expect(lock.delay == .fiveMinutes)
    }

    @Test func theDelayDecidesWhenComingBackLocks() {
        let away = Date(timeIntervalSinceReferenceDate: 1_000)
        #expect(AppLock.shouldLock(enabled: true, backgroundedAt: away, now: away, delay: .immediately))
        #expect(!AppLock.shouldLock(enabled: true, backgroundedAt: away, now: away.addingTimeInterval(59), delay: .oneMinute))
        #expect(AppLock.shouldLock(enabled: true, backgroundedAt: away, now: away.addingTimeInterval(60), delay: .oneMinute))
        #expect(!AppLock.shouldLock(enabled: true, backgroundedAt: away, now: away.addingTimeInterval(299), delay: .fiveMinutes))
        #expect(!AppLock.shouldLock(enabled: false, backgroundedAt: away, now: away.addingTimeInterval(999), delay: .immediately))
        #expect(!AppLock.shouldLock(enabled: true, backgroundedAt: nil, now: away, delay: .immediately))
    }

    @Test func turningTheLockOffUnlocksAndForgets() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: AppLock.enabledKey)
        let lock = AppLock(defaults: defaults)
        lock.disable()
        #expect(!lock.isLocked)
        #expect(!defaults.bool(forKey: AppLock.enabledKey))
        lock.didEnterBackground()
        lock.didBecomeActive()
        #expect(!lock.isLocked)
    }

    @Test func faceIDHasAUsageDescription() {
        let text = Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") as? String
        #expect(text?.isEmpty == false)
    }
}
