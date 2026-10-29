import QuartzCore
import SwiftUI
import UIKit

/// Where a sheet is rolled when its point `grab` is held at `finger`. Pure, unit-tested.
///
/// The sheet spans `0…width × 0…height` with its bound edge (the spine) at `x = 0`. It rolls round
/// a cylinder whose axis lies across the line from `grab` to `finger`; the paper past the roll lies
/// flat on top, back side up, and the held point lands under the finger.
struct PageCurlGeometry: Equatable, Sendable {
    /// A point on the line where the sheet leaves the table and starts to roll.
    var origin: CGPoint
    /// Unit vector across that line, pointing toward the lifted part of the sheet.
    var normal: CGVector
    var radius: CGFloat
    var isFlat: Bool

    init(origin: CGPoint, normal: CGVector, radius: CGFloat, isFlat: Bool) {
        self.origin = origin
        self.normal = normal
        self.radius = radius
        self.isFlat = isFlat
    }

    init(grab: CGPoint, finger: CGPoint, maxRadius: CGFloat) {
        let dx = grab.x - finger.x, dy = grab.y - finger.y, distance = hypot(dx, dy)
        guard distance > 0.5 else {
            self.init(origin: CGPoint(x: 1e6, y: 0), normal: CGVector(dx: 1, dy: 0), radius: 1, isFlat: true)
            return
        }
        let n = CGVector(dx: dx / distance, dy: dy / distance)
        // A small lift rolls tightly; the roll widens as the page comes up, to a natural maximum.
        let r = max(1, min(maxRadius, distance / .pi))
        // Halfway between grab and finger, moved back by half the roll's circumference, so the
        // paper that has gone over the roll lands with the held point under the finger.
        let mid = CGPoint(x: (grab.x + finger.x) / 2, y: (grab.y + finger.y) / 2)
        self.init(origin: CGPoint(x: mid.x - n.dx * .pi * r / 2, y: mid.y - n.dy * .pi * r / 2),
                  normal: n, radius: r, isFlat: false)
    }

    /// Signed distance from the line where the sheet starts to roll; positive toward the lifted side.
    func side(_ point: CGPoint) -> CGFloat {
        (point.x - origin.x) * normal.dx + (point.y - origin.y) * normal.dy
    }

    /// Keeps a held point where paper bound at the spine can reach: no further from the spine than
    /// the point was before it was lifted.
    static func constrain(_ point: CGPoint, grab: CGPoint, size: CGSize) -> CGPoint {
        var p = point
        let reach: [(CGPoint, CGFloat)] = [
            (CGPoint(x: 0, y: grab.y), grab.x),
            (.zero, hypot(grab.x, grab.y)),
            (CGPoint(x: 0, y: size.height), hypot(grab.x, size.height - grab.y)),
        ]
        for _ in 0..<2 {
            for (anchor, radius) in reach {
                let dx = p.x - anchor.x, dy = p.y - anchor.y, d = hypot(dx, dy)
                if d > radius { p = CGPoint(x: anchor.x + dx * radius / d, y: anchor.y + dy * radius / d) }
            }
        }
        return p
    }
}

/// A page being turned: snapshots of the sheet that moves and of the page it covers or uncovers,
/// and the point on the sheet that is held.
struct PageTurn {
    let offset: Int
    let target: Page
    let isForward: Bool
    let grab: CGPoint
    let size: CGSize
    let sheet: UIImage
    let under: UIImage
    var isSettling = false

    /// Lying flat where it started, and turned right over onto the other side of the spine.
    var flatPoint: CGPoint { grab }
    var overPoint: CGPoint { CGPoint(x: -grab.x, y: grab.y) }

    /// Where the held point actually goes for a hand at `hand`.
    ///
    /// Where the page is held decides how it leans: held low, the bottom leads and the top lags;
    /// held high, the reverse; held in the middle, it turns square. Past halfway the free side
    /// falls over ahead of the hand, as paper does.
    func held(at hand: CGPoint) -> CGPoint {
        let progress = min(1, max(0, (grab.x - hand.x) / (2 * max(grab.x, 1))))
        let lean = (grab.y / max(size.height, 1) - 0.5) * 2
        let lift = -lean * size.height * 0.12 * sin(.pi * progress) * (1 - 1.6 * progress)
        return PageCurlGeometry.constrain(CGPoint(x: hand.x, y: hand.y + lift), grab: grab, size: size)
    }
}

/// Moves the held point toward the hand on a spring, so the paper has a little weight: it trails
/// the finger slightly, and when let go it carries the flick on to where it lands.
@MainActor @Observable
final class PageTurnMotion {
    private(set) var position: CGPoint = .zero
    @ObservationIgnored private var velocity: CGVector = .zero
    @ObservationIgnored private var target: CGPoint = .zero
    @ObservationIgnored private var stiffness: CGFloat = 1400
    @ObservationIgnored private var dampingRatio: CGFloat = 0.9
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var onSettle: (@MainActor () -> Void)?

    func start(at point: CGPoint) {
        stop()
        position = point
        target = point
        velocity = .zero
    }

    /// Follow the finger closely.
    func follow(_ point: CGPoint) {
        target = point
        stiffness = 1400
        dampingRatio = 0.9
        run()
    }

    /// Let go: glide on with `velocity` (points per second) and come to rest at `point`.
    func release(to point: CGPoint, velocity: CGVector, onSettle: @escaping @MainActor () -> Void) {
        target = point
        self.velocity = velocity
        stiffness = 170
        dampingRatio = 0.92
        self.onSettle = onSettle
        run()
    }

    func stop() {
        link?.invalidate()
        link = nil
        onSettle = nil
    }

    private func run() {
        guard link == nil else { return }
        let proxy = DisplayLinkProxy { [weak self] link in self?.tick(link) }
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    private func tick(_ link: CADisplayLink) {
        let dt = min(max(link.targetTimestamp - link.timestamp, 1.0 / 240), 1.0 / 30)
        let damping = 2 * sqrt(stiffness) * dampingRatio
        var p = position, v = velocity
        let steps = 4, h = CGFloat(dt) / CGFloat(steps)
        for _ in 0..<steps {
            let ax = stiffness * (target.x - p.x) - damping * v.dx
            let ay = stiffness * (target.y - p.y) - damping * v.dy
            v.dx += ax * h
            v.dy += ay * h
            p.x += v.dx * h
            p.y += v.dy * h
        }
        velocity = v
        let settled = hypot(target.x - p.x, target.y - p.y) < 0.5 && hypot(v.dx, v.dy) < 8
        position = settled ? target : p
        guard settled else { return }
        velocity = .zero
        let done = onSettle
        stop()
        done?()
    }
}

/// `CADisplayLink` keeps a strong reference to its target; this keeps it off the motion itself.
@MainActor
private final class DisplayLinkProxy: NSObject {
    let handler: @MainActor (CADisplayLink) -> Void

    init(handler: @escaping @MainActor (CADisplayLink) -> Void) {
        self.handler = handler
    }

    @objc func fire(_ link: CADisplayLink) {
        handler(link)
    }
}

/// Draws a turning page: the page underneath, and the sheet rolled over it by the `pageCurl`
/// shader (`PageCurl.metal`), which also shades the roll and casts the sheet's shadow.
struct PageCurlView: View {
    let turn: PageTurn
    let motion: PageTurnMotion
    let paper: Color

    var body: some View {
        let size = turn.size
        let curl = PageCurlGeometry(grab: turn.grab, finger: turn.held(at: motion.position), maxRadius: size.width * 0.12)
        ZStack {
            Image(uiImage: turn.under)
                .resizable()
            Image(uiImage: turn.sheet)
                .resizable()
                .layerEffect(
                    ShaderLibrary.pageCurl(
                        .float2(size),
                        .float2(curl.origin),
                        .float2(curl.normal.dx, curl.normal.dy),
                        .float(curl.radius),
                        .color(paper)
                    ),
                    maxSampleOffset: size,
                    isEnabled: !curl.isFlat
                )
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 6))
        .contentShape(.rect)
        .accessibilityHidden(true)
    }
}
