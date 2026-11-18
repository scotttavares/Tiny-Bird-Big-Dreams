import Foundation

/// Deterministic 2D physics + mood rules for one level.
///
/// World units are points, y points up, (0, 0) is the bottom-left corner. The simulation
/// runs at a fixed 120 Hz step so a level always plays out the same way for the same
/// inputs. That lets the unit tests replay each level's stored solution and prove it wins.
///
/// This file is mirrored by `tools/sim.py`, which is used to design and tune levels.
/// Keep the constants and the order of operations identical in both.
final class Simulation {
    // MARK: Tuning (mirror of tools/sim.py)
    static let dt = 1.0 / 120.0
    static let iterations = 4
    static let defaultGravity = -900.0
    static let drag = 0.35
    static let happyRange = 170.0
    static let grumpyRange = 150.0
    static let happyAccel = 1100.0
    static let grumpyAccel = 1500.0
    static let restitution = 0.25
    static let bouncyRestitution = 0.95
    static let bounceMinSpeed = 60.0
    static let friction = 0.4
    static let slop = 0.5
    static let correction = 0.8
    static let cheerTime = 0.45
    static let contactPad = 4.0
    static let scareSpeed = 380.0
    static let scareLift = 420.0
    static let scareCooldown = 0.8
    static let settleSpeed = 30.0
    static let winHold = 0.6
    static let fallY = -60.0

    final class Body {
        let id: String
        var x: Double
        var y: Double
        var vx = 0.0
        var vy = 0.0
        let r: Double
        var mood: Mood
        let swappable: Bool
        let isStatic: Bool
        let rangeScale: Double
        var cool = 0.0
        var fallen = false

        init(_ data: BodyData, isStatic: Bool) {
            id = data.id
            x = data.pos[0]
            y = data.pos[1]
            r = data.r ?? (isStatic ? 18.0 : 26.0)
            mood = data.mood
            swappable = data.swappable ?? false
            self.isStatic = isStatic
            rangeScale = data.rangeScale ?? 1.0
        }

        var invMass: Double { isStatic ? 0.0 : 1.0 / mood.mass }
        var speed: Double { (vx * vx + vy * vy).squareRoot() }
    }

    struct Segment {
        let x1: Double, y1: Double, x2: Double, y2: Double
        let r: Double
        let bouncy: Bool
    }

    enum Event: Equatable {
        case cheer(String)
        case scare(String)
        case fall(String)
        case moodChanged(String, Mood)
    }

    /// Strongest contact a jelly felt during the last step, for squash-and-stretch.
    struct Impact {
        var strength: Double
        var nx: Double
        var ny: Double
    }

    let level: LevelData
    let width: Double
    let height: Double
    let gravity: Double
    private(set) var jellies: [Body]
    private(set) var pegs: [Body]
    let segments: [Segment]
    private(set) var t = 0.0
    private(set) var moves = 0
    private(set) var won = false
    private(set) var failed = false
    private(set) var winTimer = 0.0
    private var cheer: [String: Double] = [:]

    /// Events since the last `drainEvents()`.
    private(set) var events: [Event] = []
    /// Impacts since the last `drainImpacts()`, keyed by jelly id.
    private(set) var impacts: [String: Impact] = [:]

    init(level: LevelData) {
        self.level = level
        width = level.width
        height = level.height
        gravity = level.gravity ?? Self.defaultGravity
        jellies = level.jellies.map { Body($0, isStatic: false) }
        pegs = level.pegs.map { Body($0, isStatic: true) }
        segments = level.segments.map {
            Segment(x1: $0.a[0], y1: $0.a[1], x2: $0.b[0], y2: $0.b[1], r: $0.r ?? 8.0, bouncy: $0.bouncy ?? false)
        }
    }

    var isOver: Bool { won || failed }

    func body(id: String) -> Body? {
        jellies.first { $0.id == id } ?? pegs.first { $0.id == id }
    }

    /// Player action: give `id` the mood `mood`. Returns `true` when it counted as a move.
    @discardableResult
    func apply(target id: String, mood: Mood) -> Bool {
        guard let target = body(id: id), target.swappable, target.mood != mood, !target.fallen else { return false }
        target.mood = mood
        moves += 1
        events.append(.moodChanged(id, mood))
        return true
    }

    func drainEvents() -> [Event] {
        defer { events.removeAll() }
        return events
    }

    func drainImpacts() -> [String: Impact] {
        defer { impacts.removeAll() }
        return impacts
    }

    // MARK: Forces

    private func acceleration(of target: Body) -> (Double, Double) {
        var ax = 0.0
        var ay = gravity
        for source in jellies + pegs {
            if source === target || source.fallen { continue }
            let dx = source.x - target.x
            let dy = source.y - target.y
            let d = (dx * dx + dy * dy).squareRoot()
            if d < 1e-6 { continue }
            let nx = dx / d
            let ny = dy / d
            if source.mood == .happy {
                if target.mood != .grumpy {
                    let range = Self.happyRange * source.rangeScale
                    if d < range && d > source.r + target.r + 1.0 {
                        let m = Self.happyAccel * (1.0 - d / range) * target.mood.response
                        ax += nx * m
                        ay += ny * m
                    }
                }
            } else if source.mood == .grumpy {
                let range = Self.grumpyRange * source.rangeScale
                if d < range {
                    let m = Self.grumpyAccel * (1.0 - d / range) * target.mood.response
                    ax -= nx * m
                    ay -= ny * m
                }
            }
        }
        return (ax, ay)
    }

    // MARK: Contacts

    /// Resolves a contact for jelly `a` against `b` (`nil` = static). The normal points from b to a.
    @discardableResult
    private func solve(_ a: Body, nx: Double, ny: Double, penetration: Double, invB: Double, _ b: Body?, restitution bounce: Double? = nil) -> Double {
        let invA = a.invMass
        let total = invA + invB
        if total <= 0 { return 0 }
        if penetration > Self.slop {
            let c = (penetration - Self.slop) * Self.correction / total
            a.x += nx * c * invA
            a.y += ny * c * invA
            if let b {
                b.x -= nx * c * invB
                b.y -= ny * c * invB
            }
        }
        let bvx = b?.vx ?? 0.0
        let bvy = b?.vy ?? 0.0
        let rvx = a.vx - bvx
        let rvy = a.vy - bvy
        let vn = rvx * nx + rvy * ny
        if vn >= 0 { return 0 }
        var e = bounce ?? Self.restitution
        if -vn < Self.bounceMinSpeed && bounce == nil { e = 0.0 }
        let j = -(1.0 + e) * vn / total
        a.vx += nx * j * invA
        a.vy += ny * j * invA
        if let b {
            b.vx -= nx * j * invB
            b.vy -= ny * j * invB
        }
        let tx = -ny
        let ty = nx
        let vt = rvx * tx + rvy * ty
        var jt = -vt / total
        let limit = Self.friction * j
        if jt > limit { jt = limit }
        if jt < -limit { jt = -limit }
        a.vx += tx * jt * invA
        a.vy += ty * jt * invA
        if let b {
            b.vx -= tx * jt * invB
            b.vy -= ty * jt * invB
        }
        // Visual feedback only: never feeds back into the physics.
        noteImpact(a, strength: -vn, nx: nx, ny: ny)
        if let b { noteImpact(b, strength: -vn, nx: -nx, ny: -ny) }
        return j
    }

    private func noteImpact(_ body: Body, strength: Double, nx: Double, ny: Double) {
        if body.isStatic { return }
        if let existing = impacts[body.id], existing.strength >= strength { return }
        impacts[body.id] = Impact(strength: strength, nx: nx, ny: ny)
    }

    private func collide() {
        let js = jellies
        for _ in 0..<Self.iterations {
            for i in 0..<js.count {
                let a = js[i]
                if a.fallen { continue }
                if i + 1 < js.count {
                    for k in (i + 1)..<js.count {
                        let b = js[k]
                        if b.fallen { continue }
                        let dx = a.x - b.x
                        let dy = a.y - b.y
                        let d2 = dx * dx + dy * dy
                        let rr = a.r + b.r
                        if d2 < rr * rr && d2 > 1e-9 {
                            let d = d2.squareRoot()
                            solve(a, nx: dx / d, ny: dy / d, penetration: rr - d, invB: b.invMass, b)
                        }
                    }
                }
                for p in pegs {
                    let dx = a.x - p.x
                    let dy = a.y - p.y
                    let d2 = dx * dx + dy * dy
                    let rr = a.r + p.r
                    if d2 < rr * rr && d2 > 1e-9 {
                        let d = d2.squareRoot()
                        solve(a, nx: dx / d, ny: dy / d, penetration: rr - d, invB: 0.0, nil)
                    }
                }
                for s in segments {
                    let ex = s.x2 - s.x1
                    let ey = s.y2 - s.y1
                    let l2 = ex * ex + ey * ey
                    var u = l2 > 0 ? ((a.x - s.x1) * ex + (a.y - s.y1) * ey) / l2 : 0.0
                    if u < 0 { u = 0.0 }
                    if u > 1 { u = 1.0 }
                    let cx = s.x1 + ex * u
                    let cy = s.y1 + ey * u
                    let dx = a.x - cx
                    let dy = a.y - cy
                    let d2 = dx * dx + dy * dy
                    let rr = a.r + s.r
                    if d2 < rr * rr && d2 > 1e-9 {
                        let d = d2.squareRoot()
                        solve(a, nx: dx / d, ny: dy / d, penetration: rr - d, invB: 0.0, nil,
                              restitution: s.bouncy ? Self.bouncyRestitution : nil)
                    }
                }
            }
            // World walls: left, right and ceiling. The bottom is open (falling = failing).
            for a in js {
                if a.fallen { continue }
                if a.x < a.r {
                    a.x = a.r
                    if a.vx < 0 { a.vx = -a.vx * Self.restitution }
                }
                if a.x > width - a.r {
                    a.x = width - a.r
                    if a.vx > 0 { a.vx = -a.vx * Self.restitution }
                }
                if a.y > height - a.r {
                    a.y = height - a.r
                    if a.vy > 0 { a.vy = -a.vy * Self.restitution }
                }
            }
        }
    }

    // MARK: Mood rules

    private func applyMoodRules() {
        let js = jellies
        for a in js where a.cool > 0 {
            a.cool -= Self.dt
        }
        for i in 0..<js.count {
            if i + 1 >= js.count { break }
            for k in (i + 1)..<js.count {
                let a = js[i]
                let b = js[k]
                if a.fallen || b.fallen { continue }
                let dx = a.x - b.x
                let dy = a.y - b.y
                let d = (dx * dx + dy * dy).squareRoot()
                let touching = d <= a.r + b.r + Self.contactPad
                let key = a.id + "|" + b.id
                let pair: Set<Mood> = [a.mood, b.mood]
                if touching && pair == [.happy, .nervous] {
                    let held = (cheer[key] ?? 0.0) + Self.dt
                    cheer[key] = held
                    if held >= Self.cheerTime {
                        let n = a.mood == .nervous ? a : b
                        n.mood = .happy
                        cheer[key] = 0.0
                        events.append(.cheer(n.id))
                    }
                } else {
                    cheer[key] = 0.0
                }
                if touching && pair == [.grumpy, .nervous] && d > 1e-6 {
                    let (n, g) = a.mood == .nervous ? (a, b) : (b, a)
                    if n.cool <= 0 {
                        let nx = (n.x - g.x) / d
                        let ny = (n.y - g.y) / d
                        n.vx += nx * Self.scareSpeed
                        n.vy += ny * Self.scareSpeed + Self.scareLift
                        n.cool = Self.scareCooldown
                        events.append(.scare(n.id))
                    }
                }
            }
        }
        for a in js {
            for p in pegs {
                if a.fallen { continue }
                let key = a.id + "|" + p.id
                let dx = a.x - p.x
                let dy = a.y - p.y
                let d = (dx * dx + dy * dy).squareRoot()
                let touching = d <= a.r + p.r + Self.contactPad
                if touching && a.mood == .nervous && p.mood == .happy {
                    let held = (cheer[key] ?? 0.0) + Self.dt
                    cheer[key] = held
                    if held >= Self.cheerTime {
                        a.mood = .happy
                        cheer[key] = 0.0
                        events.append(.cheer(a.id))
                    }
                } else {
                    cheer[key] = 0.0
                }
                if a.mood == .nervous && p.mood == .grumpy {
                    if touching && a.cool <= 0 && d > 1e-6 {
                        a.vx += dx / d * Self.scareSpeed
                        a.vy += dy / d * Self.scareSpeed + Self.scareLift
                        a.cool = Self.scareCooldown
                        events.append(.scare(a.id))
                    }
                }
            }
        }
    }

    // MARK: Goals

    /// Which nests are currently satisfied (for highlighting), in `level.nests` order.
    func nestStates() -> [Bool] {
        level.nests.map { nestSatisfied($0, requireSettled: false) }
    }

    private func nestSatisfied(_ nest: NestData, requireSettled: Bool) -> Bool {
        let x = nest.rect[0], y = nest.rect[1], w = nest.rect[2], h = nest.rect[3]
        var count = 0
        for a in jellies {
            if a.fallen { continue }
            if x <= a.x && a.x <= x + w && y <= a.y && a.y <= y + h && (nest.mood == nil || a.mood == nest.mood) {
                if !requireSettled || a.speed < Self.settleSpeed { count += 1 }
            }
        }
        return count >= (nest.count ?? 1)
    }

    private func allNestsSatisfied() -> Bool {
        for nest in level.nests where !nestSatisfied(nest, requireSettled: true) {
            return false
        }
        return true
    }

    // MARK: Step

    func step() {
        if won || failed { return }
        let accelerations = jellies.map { acceleration(of: $0) }
        for (a, acc) in zip(jellies, accelerations) {
            if a.fallen { continue }
            a.vx += acc.0 * Self.dt
            a.vy += acc.1 * Self.dt
            let k = 1.0 - Self.drag * Self.dt
            a.vx *= k
            a.vy *= k
            a.x += a.vx * Self.dt
            a.y += a.vy * Self.dt
        }
        collide()
        applyMoodRules()
        for a in jellies where !a.fallen && a.y < Self.fallY {
            a.fallen = true
            failed = true
            events.append(.fall(a.id))
        }
        t += Self.dt
        if !failed && allNestsSatisfied() {
            winTimer += Self.dt
            if winTimer >= Self.winHold { won = true }
        } else {
            winTimer = 0.0
        }
    }

    /// Plays `actions` against a fresh simulation, like `tools/sim.py`'s `run`.
    static func run(_ level: LevelData, actions: [ActionData], maxTime: Double = 12.0) -> Simulation {
        let sim = Simulation(level: level)
        let ordered = actions.enumerated().sorted {
            $0.element.t == $1.element.t ? $0.offset < $1.offset : $0.element.t < $1.element.t
        }.map(\.element)
        var next = 0
        let steps = Int((maxTime / dt).rounded())
        for _ in 0..<steps {
            while next < ordered.count && ordered[next].t <= sim.t + 1e-9 {
                sim.apply(target: ordered[next].target, mood: ordered[next].mood)
                next += 1
            }
            sim.step()
            if sim.isOver { break }
        }
        return sim
    }
}
