import Testing
import UIKit
@testable import FieldGuide

struct FingerTapTests {
    @Test func twoFingersTogetherAreATwoFingerTap() {
        var tap = FingerTap()
        _ = tap.press(2, at: 0)
        #expect(tap.lift(2, at: 0.1) == 2)
    }

    @Test func fingersLandingAndLiftingAtDifferentTimesStillCount() {
        var tap = FingerTap()
        _ = tap.press(1, at: 0)
        _ = tap.press(1, at: 0.05)
        _ = tap.press(1, at: 0.08)
        #expect(tap.lift(1, at: 0.15) == nil)
        #expect(tap.lift(2, at: 0.2) == 3)
    }

    @Test func oneFingerIsNotATap() {
        var tap = FingerTap()
        _ = tap.press(1, at: 0)
        #expect(tap.lift(1, at: 0.1) == nil)
    }

    @Test func aSlowPressIsNotATap() {
        var tap = FingerTap()
        _ = tap.press(2, at: 0)
        #expect(tap.lift(2, at: FingerTap.maxDuration + 0.1) == nil)
    }

    @Test func movingFingersAreNotATap() {
        var tap = FingerTap()
        _ = tap.press(2, at: 0)
        tap.moved(by: FingerTap.maxMovement + 1)
        #expect(tap.lift(2, at: 0.1) == nil)
    }

    @Test func aQuickSecondFingerDropsTheStroke() {
        var tap = FingerTap()
        #expect(tap.press(1, at: 0) == false)
        #expect(tap.press(1, at: 0.1) == true)
    }

    @Test func aLateSecondFingerKeepsTheStroke() {
        var tap = FingerTap()
        _ = tap.press(1, at: 0)
        #expect(tap.press(1, at: FingerTap.strokeWindow + 0.1) == false)
    }
}
