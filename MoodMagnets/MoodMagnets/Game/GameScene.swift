import SpriteKit
import UIKit

/// What the scene tells the SwiftUI layer.
@MainActor
protocol GameSceneDelegate: AnyObject {
    var selectedMood: Mood { get }
    func scene(_ scene: GameScene, didChangeMoves moves: Int)
    func scene(_ scene: GameScene, didWinWithMoves moves: Int)
    func sceneDidFail(_ scene: GameScene)
    func sceneMoodsChanged(_ scene: GameScene)
    func scene(_ scene: GameScene, nestsChanged satisfied: Int, of total: Int)
}

/// Draws and drives one level. The simulation runs at a fixed 120 Hz; the scene renders
/// whatever the latest state is and turns simulation events into juice (particles, haptics).
@MainActor
final class GameScene: SKScene {
    weak var gameDelegate: GameSceneDelegate?
    private(set) var level: LevelData
    private(set) var sim: Simulation

    private let world = SKNode()
    private var jellyNodes: [String: JellyNode] = [:]
    private var stoneNodes: [String: StoneNode] = [:]
    private var nestNodes: [SKShapeNode] = []
    private var lastNestStates: [Bool] = []
    private var accumulator: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var now: TimeInterval = 0
    private var finished = false
    /// When false the simulation is frozen (pause menu, win card, tent preview).
    var isRunning = true
    /// Tent posture shows off the board without letting touches change it.
    var acceptsTouches = true
    /// Scripted actions played automatically (the `-MMAutoSolve` demo / QA mode).
    var autoplay: [ActionData] = []

    private let haptics = Haptics()

    init(level: LevelData) {
        self.level = level
        sim = Simulation(level: level)
        super.init(size: CGSize(width: level.width, height: level.height))
        scaleMode = .aspectFit
        anchorPoint = .zero
        backgroundColor = UIColor(hex: 0xFFE7C2)
        if ProcessInfo.processInfo.arguments.contains("-MMAutoSolve") {
            autoplay = level.solution.sorted { $0.t < $1.t }
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        if world.parent == nil { build() }
    }

    // MARK: Building

    func load(_ newLevel: LevelData) {
        level = newLevel
        size = CGSize(width: newLevel.width, height: newLevel.height)
        reset()
    }

    func reset() {
        sim = Simulation(level: level)
        if ProcessInfo.processInfo.arguments.contains("-MMAutoSolve") {
            autoplay = level.solution.sorted { $0.t < $1.t }
        }
        accumulator = 0
        lastUpdate = 0
        finished = false
        isRunning = true
        removeAllChildren()
        world.removeAllChildren()
        jellyNodes.removeAll()
        stoneNodes.removeAll()
        nestNodes.removeAll()
        lastNestStates = []
        build()
        gameDelegate?.scene(self, didChangeMoves: 0)
    }

    private func build() {
        let backdrop = SKSpriteNode(texture: Art.backdrop(size: size), size: size)
        backdrop.anchorPoint = .zero
        backdrop.zPosition = -100
        addChild(backdrop)
        addBokeh()

        world.removeFromParent()
        addChild(world)

        for (index, nest) in level.nests.enumerated() {
            let node = makeNest(nest)
            node.name = "nest-\(index)"
            world.addChild(node)
            nestNodes.append(node)
        }
        for segment in level.segments {
            world.addChild(makeSegment(segment))
        }
        for peg in sim.pegs {
            let node = StoneNode(id: peg.id, radius: CGFloat(peg.r), mood: peg.mood, swappable: peg.swappable, rangeScale: CGFloat(peg.rangeScale))
            node.position = CGPoint(x: peg.x, y: peg.y)
            node.zPosition = 5
            world.addChild(node)
            stoneNodes[peg.id] = node
        }
        for (index, jelly) in sim.jellies.enumerated() {
            let node = JellyNode(id: jelly.id, radius: CGFloat(jelly.r), mood: jelly.mood, swappable: jelly.swappable)
            node.position = CGPoint(x: jelly.x, y: jelly.y)
            node.zPosition = 10 + CGFloat(index)
            world.addChild(node)
            jellyNodes[jelly.id] = node
            // A little drop-in on load.
            node.setScale(0.01)
            node.run(.sequence([.wait(forDuration: 0.05 * Double(index)), .scale(to: 1.12, duration: 0.16), .scale(to: 1, duration: 0.1)]))
        }
    }

    private func addBokeh() {
        let dot = Art.softDot()
        var generator = SplitMix(seed: UInt64(level.id) &* 7919)
        for _ in 0..<14 {
            let sprite = SKSpriteNode(texture: dot)
            let s = CGFloat(generator.next(in: 18...70))
            sprite.size = CGSize(width: s, height: s)
            sprite.alpha = CGFloat(generator.next(in: 0.12...0.35))
            sprite.position = CGPoint(x: generator.next(in: 0...Double(size.width)), y: generator.next(in: 120...Double(size.height)))
            sprite.zPosition = -90
            let drift = CGFloat(generator.next(in: 10...30))
            let duration = generator.next(in: 4...8)
            sprite.run(.repeatForever(.sequence([
                .moveBy(x: drift, y: drift * 0.5, duration: duration),
                .moveBy(x: -drift, y: -drift * 0.5, duration: duration),
            ])))
            addChild(sprite)
        }
    }

    private func makeSegment(_ segment: SegmentData) -> SKNode {
        let ax = segment.a[0], ay = segment.a[1], bx = segment.b[0], by = segment.b[1]
        let r = CGFloat(segment.r ?? 8)
        let length = CGFloat(hypot(bx - ax, by - ay))
        let bouncy = segment.bouncy ?? false
        let container = SKNode()
        container.position = CGPoint(x: ax, y: ay)
        container.zRotation = CGFloat(atan2(by - ay, bx - ax))
        container.zPosition = 2

        let rect = CGRect(x: -r, y: -r, width: length + r * 2, height: r * 2)
        let shadow = SKShapeNode(path: CGPath(roundedRect: rect.offsetBy(dx: 0, dy: -3), cornerWidth: r, cornerHeight: r, transform: nil))
        shadow.fillColor = MoodPalette.ink.withAlphaComponent(0.12)
        shadow.strokeColor = .clear
        container.addChild(shadow)

        let body = SKShapeNode(path: CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
        body.fillColor = bouncy ? MoodPalette.bouncy : MoodPalette.cream
        body.strokeColor = bouncy ? UIColor(hex: 0xE0548A) : MoodPalette.creamEdge
        body.lineWidth = 2
        container.addChild(body)

        let shine = SKShapeNode(path: CGPath(roundedRect: CGRect(x: 0, y: r * 0.15, width: max(1, length), height: r * 0.45),
                                             cornerWidth: r * 0.22, cornerHeight: r * 0.22, transform: nil))
        shine.fillColor = UIColor.white.withAlphaComponent(bouncy ? 0.45 : 0.7)
        shine.strokeColor = .clear
        container.addChild(shine)

        if bouncy {
            var x: CGFloat = 6
            while x < length {
                let chevron = CGMutablePath()
                chevron.move(to: CGPoint(x: x - 3, y: -r * 0.35))
                chevron.addLine(to: CGPoint(x: x, y: r * 0.15))
                chevron.addLine(to: CGPoint(x: x + 3, y: -r * 0.35))
                let node = SKShapeNode(path: chevron)
                node.strokeColor = UIColor.white.withAlphaComponent(0.85)
                node.lineWidth = 1.6
                node.lineCap = .round
                container.addChild(node)
                x += 16
            }
            container.run(.repeatForever(.sequence([.scaleY(to: 1.12, duration: 0.5), .scaleY(to: 1, duration: 0.5)])))
        }
        return container
    }

    private func makeNest(_ nest: NestData) -> SKShapeNode {
        let rect = CGRect(x: nest.rect[0], y: nest.rect[1], width: nest.rect[2], height: nest.rect[3])
        let path = CGPath(roundedRect: rect.insetBy(dx: 3, dy: 0), cornerWidth: 16, cornerHeight: 16, transform: nil)
        let node = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [7, 5]))
        let color = nest.mood.map(MoodPalette.base) ?? UIColor.white
        node.strokeColor = color.withAlphaComponent(0.85)
        node.lineWidth = 2.5
        node.zPosition = 1
        let fill = SKShapeNode(path: path)
        fill.fillColor = (nest.mood.map(MoodPalette.light) ?? .white).withAlphaComponent(0.35)
        fill.strokeColor = .clear
        fill.name = "fill"
        node.addChild(fill)

        // Badge: a little mood dot and the count wanted.
        let badge = SKNode()
        badge.position = CGPoint(x: rect.midX, y: rect.maxY + 14)
        let dot = SKSpriteNode(texture: Art.jelly(nest.mood ?? .happy, radius: 9), size: CGSize(width: 18, height: 18))
        if nest.mood == nil { dot.alpha = 0.5 }
        badge.addChild(dot)
        let count = nest.count ?? 1
        if count > 1 {
            let label = SKLabelNode(text: "×\(count)")
            label.fontName = "AvenirNext-Heavy"
            label.fontSize = 14
            label.fontColor = MoodPalette.ink
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 20, y: 0)
            badge.addChild(label)
        }
        badge.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.9), .moveBy(x: 0, y: -3, duration: 0.9)])))
        node.addChild(badge)
        return node
    }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        now = currentTime
        let elapsed = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 0.1)
        lastUpdate = currentTime
        if isRunning && !finished {
            accumulator += elapsed
            while accumulator >= Simulation.dt {
                playDueActions()
                sim.step()
                accumulator -= Simulation.dt
                handleEvents()
                if sim.isOver { break }
            }
        }
        sync()
        checkOutcome()
    }

    private func playDueActions() {
        while let next = autoplay.first, next.t <= sim.t + 1e-9 {
            autoplay.removeFirst()
            if sim.apply(target: next.target, mood: next.mood) {
                gameDelegate?.scene(self, didChangeMoves: sim.moves)
            }
        }
    }

    private func sync() {
        let impacts = sim.drainImpacts()
        var moodsChanged = false
        for jelly in sim.jellies {
            guard let node = jellyNodes[jelly.id] else { continue }
            if jelly.fallen {
                node.isHidden = node.position.y < -80
            }
            node.position = CGPoint(x: jelly.x, y: jelly.y)
            if node.mood != jelly.mood {
                node.setMood(jelly.mood, animated: true)
                moodsChanged = true
            }
            if let impact = impacts[jelly.id] {
                node.impact(strength: impact.strength, nx: impact.nx, ny: impact.ny)
                if impact.strength > 260 { haptics.bump(intensity: min(1, impact.strength / 900)) }
            }
            node.tick(now: now, velocity: CGVector(dx: jelly.vx, dy: jelly.vy), scene: self)
        }
        for peg in sim.pegs {
            if let node = stoneNodes[peg.id], node.mood != peg.mood {
                node.setMood(peg.mood, animated: true)
                moodsChanged = true
            }
        }
        if moodsChanged { gameDelegate?.sceneMoodsChanged(self) }
        let states = sim.nestStates()
        if states != lastNestStates {
            for (index, satisfied) in states.enumerated() where index < nestNodes.count {
                let wasSatisfied = index < lastNestStates.count ? lastNestStates[index] : false
                let fill = nestNodes[index].childNode(withName: "fill") as? SKShapeNode
                fill?.removeAllActions()
                fill?.run(.fadeAlpha(to: satisfied ? 1.0 : 0.6, duration: 0.2))
                if satisfied && !wasSatisfied {
                    sparkle(at: CGPoint(x: level.nests[index].rect[0] + level.nests[index].rect[2] / 2,
                                        y: level.nests[index].rect[1] + 10), color: .white, count: 10)
                }
            }
            lastNestStates = states
            gameDelegate?.scene(self, nestsChanged: states.filter { $0 }.count, of: states.count)
        }
    }

    private func handleEvents() {
        for event in sim.drainEvents() {
            switch event {
            case .cheer(let id):
                guard let node = jellyNodes[id] else { continue }
                hearts(at: node.position)
                haptics.success()
            case .scare(let id):
                guard let node = jellyNodes[id] else { continue }
                exclaim(at: node.position, radius: node.radius)
                haptics.bump(intensity: 0.8)
            case .fall:
                haptics.failure()
            case .moodChanged:
                break
            }
        }
    }

    private func checkOutcome() {
        guard !finished else { return }
        if sim.won {
            finished = true
            haptics.success()
            for (index, node) in jellyNodes.values.sorted(by: { $0.position.x < $1.position.x }).enumerated() {
                node.celebrate(delay: Double(index) * 0.08)
            }
            confetti()
            let moves = sim.moves
            run(.wait(forDuration: 1.0)) { [weak self] in
                guard let self else { return }
                self.gameDelegate?.scene(self, didWinWithMoves: moves)
            }
        } else if sim.failed {
            finished = true
            run(.wait(forDuration: 0.7)) { [weak self] in
                guard let self else { return }
                self.gameDelegate?.sceneDidFail(self)
            }
        }
    }

    // MARK: Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard acceptsTouches, !finished, let touch = touches.first else { return }
        let point = touch.location(in: self)
        for node in jellyNodes.values { node.look(at: point, now: now) }
        guard let target = pickBody(at: point) else { return }
        let mood = gameDelegate?.selectedMood ?? .happy
        guard let body = sim.body(id: target) else { return }
        if !body.swappable {
            jellyNodes[target]?.refuse()
            stoneNodes[target]?.refuse()
            haptics.tap()
            return
        }
        if body.mood == mood {
            jellyNodes[target]?.refuse()
            stoneNodes[target]?.refuse()
            return
        }
        if sim.apply(target: target, mood: mood) {
            jellyNodes[target]?.setMood(mood, animated: true)
            stoneNodes[target]?.setMood(mood, animated: true)
            sparkle(at: CGPoint(x: body.x, y: body.y), color: MoodPalette.base(mood), count: 14)
            haptics.tap()
            gameDelegate?.scene(self, didChangeMoves: sim.moves)
        }
    }

    /// The nearest swappable body under the finger (generous radius), else any body.
    private func pickBody(at point: CGPoint) -> String? {
        var best: (String, Double, Bool)?
        for body in sim.jellies + sim.pegs where !body.fallen {
            let d = hypot(body.x - point.x, body.y - point.y)
            guard d <= body.r + 18 else { continue }
            if let current = best {
                if (body.swappable && !current.2) || (body.swappable == current.2 && d < current.1) {
                    best = (body.id, d, body.swappable)
                }
            } else {
                best = (body.id, d, body.swappable)
            }
        }
        return best?.0
    }

    /// Briefly pulses the bodies a hint points at.
    func highlight(_ id: String) {
        guard let body = sim.body(id: id) else { return }
        let ring = SKShapeNode(circleOfRadius: CGFloat(body.r) + 10)
        ring.strokeColor = .white
        ring.lineWidth = 4
        ring.glowWidth = 6
        ring.position = CGPoint(x: body.x, y: body.y)
        ring.zPosition = 50
        world.addChild(ring)
        ring.run(.sequence([
            .repeat(.sequence([.scale(to: 1.25, duration: 0.3), .scale(to: 1.0, duration: 0.3)]), count: 3),
            .fadeOut(withDuration: 0.3), .removeFromParent(),
        ]))
    }

    // MARK: Juice

    private func sparkle(at point: CGPoint, color: UIColor, count: Int) {
        let texture = Art.softDot()
        for i in 0..<count {
            let dot = SKSpriteNode(texture: texture)
            dot.size = CGSize(width: 10, height: 10)
            dot.color = color
            dot.colorBlendFactor = 1
            dot.position = point
            dot.zPosition = 40
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2
            let distance: CGFloat = 34 + CGFloat(i % 3) * 10
            world.addChild(dot)
            dot.run(.sequence([
                .group([.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.4), .fadeOut(withDuration: 0.4), .scale(to: 0.3, duration: 0.4)]),
                .removeFromParent(),
            ]))
        }
    }

    private func hearts(at point: CGPoint) {
        let texture = Art.heart()
        for i in 0..<6 {
            let heart = SKSpriteNode(texture: texture)
            heart.size = CGSize(width: 16, height: 15)
            heart.color = UIColor(hex: i % 2 == 0 ? 0xFF5C8A : 0xFF9EBB)
            heart.colorBlendFactor = 1
            heart.position = CGPoint(x: point.x + CGFloat(i - 3) * 6, y: point.y + 20)
            heart.zPosition = 45
            heart.setScale(0.2)
            world.addChild(heart)
            let dx = CGFloat(i - 3) * 9
            heart.run(.sequence([
                .wait(forDuration: Double(i) * 0.04),
                .group([.scale(to: 1, duration: 0.2), .moveBy(x: dx, y: 60, duration: 0.8), .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.35)])]),
                .removeFromParent(),
            ]))
        }
    }

    private func exclaim(at point: CGPoint, radius: CGFloat) {
        let label = SKLabelNode(text: "!")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 30
        label.fontColor = UIColor(hex: 0xFF4D6D)
        label.position = CGPoint(x: point.x + radius * 0.7, y: point.y + radius * 0.9)
        label.zPosition = 45
        label.setScale(0.2)
        world.addChild(label)
        label.run(.sequence([.scale(to: 1.2, duration: 0.1), .scale(to: 1, duration: 0.08), .wait(forDuration: 0.35), .fadeOut(withDuration: 0.2), .removeFromParent()]))
    }

    private func confetti() {
        let texture = Art.softDot()
        let colors: [UIColor] = Mood.allCases.map(MoodPalette.base) + [.white, UIColor(hex: 0xC9B8FF)]
        var generator = SplitMix(seed: UInt64(level.id) &* 104_729)
        for i in 0..<60 {
            let piece = SKSpriteNode(texture: texture)
            let s = CGFloat(generator.next(in: 7...14))
            piece.size = CGSize(width: s, height: s * 0.6)
            piece.color = colors[i % colors.count]
            piece.colorBlendFactor = 1
            piece.position = CGPoint(x: CGFloat(generator.next(in: 0...Double(size.width))), y: size.height + 20)
            piece.zPosition = 60
            addChild(piece)
            let fall = generator.next(in: 1.4...2.4)
            piece.run(.sequence([
                .wait(forDuration: generator.next(in: 0...0.5)),
                .group([.moveBy(x: CGFloat(generator.next(in: -60...60)), y: -size.height - 60, duration: fall),
                        .rotate(byAngle: CGFloat(generator.next(in: -8...8)), duration: fall)]),
                .removeFromParent(),
            ]))
        }
    }
}

/// Small deterministic RNG so decorations look the same every time a level loads.
struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let unit = Double(nextUInt64() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

/// Thin wrapper over UIKit haptics, rate limited so collisions don't buzz constantly.
@MainActor
final class Haptics {
    private let light = UIImpactFeedbackGenerator(style: .soft)
    private let notifier = UINotificationFeedbackGenerator()
    private var lastBump: TimeInterval = 0

    func tap() { light.impactOccurred(intensity: 0.7) }

    func bump(intensity: Double) {
        let time = CACurrentMediaTime()
        guard time - lastBump > 0.12 else { return }
        lastBump = time
        light.impactOccurred(intensity: CGFloat(max(0.2, min(1, intensity))))
    }

    func success() { notifier.notificationOccurred(.success) }
    func failure() { notifier.notificationOccurred(.error) }
}
