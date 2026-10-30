import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Decides whether a run of touches, from first finger down to last finger up, was a tap.
struct FingerTap {
    static let maxDuration: TimeInterval = 0.4
    static let maxMovement: CGFloat = 12
    /// A second finger this soon means the first was never drawing.
    static let strokeWindow: TimeInterval = 0.25

    private var down = 0
    private var firstTouch: TimeInterval = 0
    private var hasMoved = false
    private(set) var peak = 0

    /// Fingers landed. Returns true if the first one's stroke should be dropped.
    mutating func press(_ count: Int, at time: TimeInterval) -> Bool {
        if down == 0 { firstTouch = time }
        let wasOne = down == 1
        down += count
        peak = max(peak, down)
        return (wasOne || down == count && count > 1) && time - firstTouch < Self.strokeWindow
    }

    mutating func moved(by distance: CGFloat) {
        if distance > Self.maxMovement { hasMoved = true }
    }

    /// Fingers lifted. Once the last is up, returns how many fingers tapped, if it was a tap.
    mutating func lift(_ count: Int, at time: TimeInterval) -> Int? {
        down = max(down - count, 0)
        guard down == 0, peak >= 2, !hasMoved, time - firstTouch <= Self.maxDuration else { return nil }
        return peak
    }

    var isFinished: Bool { down == 0 }
}

/// Reports multi-finger taps without taking part in gesture arbitration.
///
/// It's added to the window so it also sees touches on the page-edge grips, and it can neither
/// be prevented by PencilKit's drawing recognizer nor prevent anything itself.
final class FingerTapRecognizer: UIGestureRecognizer {
    /// Whether a touch counts; one that doesn't ends the tap.
    var accepts: (UITouch) -> Bool = { _ in true }
    /// A first finger came down.
    var onFirstTouch: () -> Void = {}
    /// A second finger came down, and `dropStroke` says it was soon enough to be no stroke.
    var onSecondFinger: (_ dropStroke: Bool) -> Void = { _ in }

    /// How many fingers made the last tap; read in the action.
    private(set) var fingers = 0

    private var tap = FingerTap()
    private var starts: [ObjectIdentifier: CGPoint] = [:]

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.allSatisfy(accepts) else {
            state = .failed
            return
        }
        let time = touches.first?.timestamp ?? 0
        let wasPeak = tap.peak
        if wasPeak == 0 { onFirstTouch() }
        for touch in touches {
            starts[ObjectIdentifier(touch)] = touch.location(in: nil)
        }
        let dropStroke = tap.press(touches.count, at: time)
        if wasPeak < 2, tap.peak >= 2 { onSecondFinger(dropStroke) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            guard let start = starts[ObjectIdentifier(touch)] else { continue }
            let now = touch.location(in: nil)
            tap.moved(by: hypot(now.x - start.x, now.y - start.y))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        let tapped = tap.lift(touches.count, at: touches.first?.timestamp ?? 0)
        guard tap.isFinished else { return }
        if let tapped {
            fingers = tapped
            state = .ended
        } else {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override func reset() {
        tap = FingerTap()
        starts = [:]
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}
