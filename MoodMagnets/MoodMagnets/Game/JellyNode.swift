import SpriteKit
import UIKit

/// One jelly character. The physics lives in `Simulation`; this node only draws it:
/// glossy body, an expressive face per mood, squash-and-stretch on impacts, idle breathing,
/// blinking, eyes that follow the action, and a dashed orbit when the player can change it.
@MainActor
final class JellyNode: SKNode {
    let bodyID: String
    let radius: CGFloat
    let swappable: Bool
    private(set) var mood: Mood

    private let shadow = SKSpriteNode(texture: Art.shadow())
    /// Rotated to the squash axis.
    private let axis = SKNode()
    /// Scaled along the axis.
    private let squash = SKNode()
    /// Counter-rotated so the body and face stay upright inside the squash.
    private let upright = SKNode()
    private let sprite: SKSpriteNode
    private let face = SKNode()
    private var pupils: [SKShapeNode] = []
    private var eyes: [SKNode] = []
    private var orbit: SKShapeNode?
    private var field: SKShapeNode?

    // Squash spring state.
    private var squashAmount: CGFloat = 0
    private var squashVelocity: CGFloat = 0
    private var squashAngle: CGFloat = 0
    private let phase: CGFloat
    private var nextBlink: TimeInterval
    private var lookTarget: CGPoint?
    private var lookUntil: TimeInterval = 0
    private var lastTime: TimeInterval = 0

    init(id: String, radius: CGFloat, mood: Mood, swappable: Bool) {
        bodyID = id
        self.radius = radius
        self.mood = mood
        self.swappable = swappable
        sprite = SKSpriteNode(texture: Art.jelly(mood, radius: radius), size: CGSize(width: radius * 2, height: radius * 2))
        var hasher = Hasher()
        hasher.combine(id)
        let seed = CGFloat(abs(hasher.finalize() % 1000)) / 1000
        phase = seed * .pi * 2
        nextBlink = TimeInterval(1.5 + seed * 3)
        super.init()

        shadow.size = CGSize(width: radius * 2.1, height: radius * 0.7)
        shadow.zPosition = -2
        addChild(shadow)

        addChild(axis)
        axis.addChild(squash)
        squash.addChild(upright)
        upright.addChild(sprite)
        upright.addChild(face)
        face.zPosition = 1

        if swappable {
            let ring = SKShapeNode(circleOfRadius: radius + 7)
            let dashed = ring.path?.copy(dashingWithPhase: 0, lengths: [5, 5])
            ring.path = dashed
            ring.strokeColor = UIColor.white.withAlphaComponent(0.9)
            ring.lineWidth = 2.2
            ring.lineCap = .round
            ring.zPosition = -1
            ring.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 9)))
            addChild(ring)
            orbit = ring
        }
        buildFace()
        updateField()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Mood

    func setMood(_ newMood: Mood, animated: Bool) {
        guard newMood != mood else { return }
        mood = newMood
        sprite.texture = Art.jelly(newMood, radius: radius)
        buildFace()
        updateField()
        if animated {
            upright.removeAction(forKey: "pop")
            upright.setScale(1)
            let pop = SKAction.sequence([
                .scale(to: 1.28, duration: 0.08),
                .scale(to: 0.92, duration: 0.1),
                .scale(to: 1.04, duration: 0.08),
                .scale(to: 1.0, duration: 0.08),
            ])
            upright.run(pop, withKey: "pop")
        }
    }

    /// The faint ring showing how far Happy/Grumpy reach.
    private func updateField() {
        field?.removeFromParent()
        field = nil
        let range: CGFloat
        switch mood {
        case .happy: range = CGFloat(Simulation.happyRange)
        case .grumpy: range = CGFloat(Simulation.grumpyRange)
        case .nervous: return
        }
        let ring = SKShapeNode(circleOfRadius: range)
        ring.strokeColor = MoodPalette.base(mood).withAlphaComponent(0.28)
        ring.fillColor = MoodPalette.light(mood).withAlphaComponent(0.06)
        ring.lineWidth = 1.5
        ring.zPosition = -5
        let breathe = SKAction.sequence([
            .group([.scale(to: mood == .happy ? 0.96 : 1.03, duration: 1.1), .fadeAlpha(to: 0.6, duration: 1.1)]),
            .group([.scale(to: 1.0, duration: 1.1), .fadeAlpha(to: 1.0, duration: 1.1)]),
        ])
        ring.run(.repeatForever(breathe))
        insertChild(ring, at: 0)
        field = ring
    }

    private func buildFace() {
        face.removeAllChildren()
        pupils.removeAll()
        eyes.removeAll()
        let r = radius
        let ink = MoodPalette.ink
        let eyeY = r * 0.12
        let eyeX = r * 0.3

        switch mood {
        case .happy:
            for side: CGFloat in [-1, 1] {
                let path = CGMutablePath()
                path.addArc(center: CGPoint(x: side * eyeX, y: eyeY - r * 0.04), radius: r * 0.12,
                            startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
                let eye = SKShapeNode(path: path)
                eye.strokeColor = ink
                eye.lineWidth = r * 0.08
                eye.lineCap = .round
                face.addChild(eye)
                let cheek = SKShapeNode(ellipseOf: CGSize(width: r * 0.28, height: r * 0.16))
                cheek.position = CGPoint(x: side * r * 0.52, y: -r * 0.08)
                cheek.fillColor = UIColor(hex: 0xFF6F91, alpha: 0.45)
                cheek.strokeColor = .clear
                face.addChild(cheek)
            }
            let mouth = CGMutablePath()
            mouth.move(to: CGPoint(x: -r * 0.2, y: -r * 0.12))
            mouth.addQuadCurve(to: CGPoint(x: r * 0.2, y: -r * 0.12), control: CGPoint(x: 0, y: -r * 0.48))
            mouth.closeSubpath()
            let smile = SKShapeNode(path: mouth)
            smile.fillColor = UIColor(hex: 0x6B2A3A)
            smile.strokeColor = ink
            smile.lineWidth = r * 0.04
            face.addChild(smile)
            let tongue = SKShapeNode(ellipseOf: CGSize(width: r * 0.18, height: r * 0.1))
            tongue.position = CGPoint(x: 0, y: -r * 0.26)
            tongue.fillColor = UIColor(hex: 0xFF7A8A)
            tongue.strokeColor = .clear
            face.addChild(tongue)

        case .grumpy:
            addOpenEyes(size: r * 0.2, pupil: r * 0.075, at: eyeY - r * 0.02, spread: eyeX)
            for side: CGFloat in [-1, 1] {
                let brow = CGMutablePath()
                brow.move(to: CGPoint(x: side * (eyeX + r * 0.16), y: eyeY + r * 0.2))
                brow.addLine(to: CGPoint(x: side * (eyeX - r * 0.14), y: eyeY + r * 0.07))
                let node = SKShapeNode(path: brow)
                node.strokeColor = ink
                node.lineWidth = r * 0.09
                node.lineCap = .round
                face.addChild(node)
            }
            let frown = CGMutablePath()
            frown.move(to: CGPoint(x: -r * 0.17, y: -r * 0.3))
            frown.addQuadCurve(to: CGPoint(x: r * 0.17, y: -r * 0.3), control: CGPoint(x: 0, y: -r * 0.1))
            let mouth = SKShapeNode(path: frown)
            mouth.strokeColor = ink
            mouth.lineWidth = r * 0.08
            mouth.lineCap = .round
            face.addChild(mouth)

        case .nervous:
            addOpenEyes(size: r * 0.27, pupil: r * 0.06, at: eyeY, spread: eyeX)
            let wave = CGMutablePath()
            wave.move(to: CGPoint(x: -r * 0.2, y: -r * 0.24))
            for i in 1...4 {
                let x = -r * 0.2 + CGFloat(i) * r * 0.1
                let y = -r * 0.24 + (i % 2 == 0 ? 0 : r * 0.06)
                wave.addQuadCurve(to: CGPoint(x: x, y: -r * 0.24), control: CGPoint(x: x - r * 0.05, y: y + (i % 2 == 0 ? -r * 0.06 : 0)))
            }
            let mouth = SKShapeNode(path: wave)
            mouth.strokeColor = ink
            mouth.lineWidth = r * 0.06
            mouth.lineCap = .round
            face.addChild(mouth)
            let drop = CGMutablePath()
            drop.move(to: CGPoint(x: 0, y: r * 0.14))
            drop.addQuadCurve(to: CGPoint(x: 0, y: -r * 0.06), control: CGPoint(x: r * 0.13, y: -r * 0.02))
            drop.addQuadCurve(to: CGPoint(x: 0, y: r * 0.14), control: CGPoint(x: -r * 0.13, y: -r * 0.02))
            let sweat = SKShapeNode(path: drop)
            sweat.fillColor = UIColor(hex: 0xBDEBFF, alpha: 0.95)
            sweat.strokeColor = UIColor(hex: 0x6CC7F0)
            sweat.lineWidth = 1
            sweat.position = CGPoint(x: r * 0.62, y: r * 0.42)
            sweat.run(.repeatForever(.sequence([.moveBy(x: 0, y: -2, duration: 0.6), .moveBy(x: 0, y: 2, duration: 0.6)])))
            face.addChild(sweat)
        }
    }

    private func addOpenEyes(size: CGFloat, pupil: CGFloat, at y: CGFloat, spread: CGFloat) {
        for side: CGFloat in [-1, 1] {
            let eye = SKNode()
            eye.position = CGPoint(x: side * spread, y: y)
            let white = SKShapeNode(ellipseOf: CGSize(width: size, height: size * 1.15))
            white.fillColor = .white
            white.strokeColor = MoodPalette.ink.withAlphaComponent(0.6)
            white.lineWidth = 1
            eye.addChild(white)
            let dot = SKShapeNode(circleOfRadius: pupil)
            dot.fillColor = MoodPalette.ink
            dot.strokeColor = .clear
            eye.addChild(dot)
            let glint = SKShapeNode(circleOfRadius: pupil * 0.35)
            glint.fillColor = .white
            glint.strokeColor = .clear
            glint.position = CGPoint(x: pupil * 0.35, y: pupil * 0.4)
            dot.addChild(glint)
            face.addChild(eye)
            eyes.append(eye)
            pupils.append(dot)
        }
    }

    // MARK: Reactions

    /// Kick the squash spring. `strength` is the closing speed of the contact.
    func impact(strength: Double, nx: Double, ny: Double) {
        let amount = CGFloat(min(strength / 1100, 0.32))
        guard amount > 0.02 else { return }
        if amount > abs(squashAmount) {
            squashAngle = CGFloat(atan2(ny, nx))
        }
        squashVelocity -= amount * 14
    }

    func look(at point: CGPoint, now: TimeInterval) {
        lookTarget = point
        lookUntil = now + 1.4
    }

    /// "Nope" wiggle when a locked jelly is tapped.
    func refuse() {
        let wiggle = SKAction.sequence([
            .rotate(toAngle: 0.18, duration: 0.05), .rotate(toAngle: -0.18, duration: 0.08),
            .rotate(toAngle: 0.1, duration: 0.07), .rotate(toAngle: 0, duration: 0.06),
        ])
        upright.run(wiggle)
    }

    func celebrate(delay: TimeInterval) {
        let hop = SKAction.sequence([
            .wait(forDuration: delay),
            .moveBy(x: 0, y: radius * 0.6, duration: 0.18),
            .moveBy(x: 0, y: -radius * 0.6, duration: 0.18),
        ])
        hop.timingMode = .easeOut
        upright.run(hop)
        squashVelocity -= 2.5
    }

    /// Per-frame visual update. `velocity` comes from the simulation.
    func tick(now: TimeInterval, velocity: CGVector, scene: SKScene) {
        let dt = lastTime == 0 ? 1.0 / 60.0 : min(now - lastTime, 1.0 / 20.0)
        lastTime = now
        let step = CGFloat(dt)

        // Damped spring for squash.
        let stiffness: CGFloat = 230
        let damping: CGFloat = 9
        squashVelocity += (-stiffness * squashAmount - damping * squashVelocity) * step
        squashAmount += squashVelocity * step
        squashAmount = max(-0.4, min(0.4, squashAmount))

        let breathe = 0.022 * sin(CGFloat(now) * 2.3 + phase)
        axis.zRotation = squashAngle
        upright.zRotation = -squashAngle
        squash.xScale = 1 + squashAmount
        squash.yScale = 1 - squashAmount * 0.75
        sprite.yScale = 1 + breathe
        sprite.xScale = 1 - breathe * 0.6

        // Nervous jellies tremble.
        if mood == .nervous {
            upright.position = CGPoint(x: sin(CGFloat(now) * 47 + phase) * 0.9, y: cos(CGFloat(now) * 39) * 0.5)
        } else if upright.position != .zero, upright.action(forKey: "pop") == nil {
            upright.position = .zero
        }

        // Soft contact shadow just under the jelly.
        shadow.position = CGPoint(x: 0, y: -radius * 0.92)

        // Eyes look at the touch, else where the jelly is heading.
        var look = CGVector(dx: velocity.dx, dy: velocity.dy)
        if let target = lookTarget, now < lookUntil {
            look = CGVector(dx: target.x - position.x, dy: target.y - position.y)
        }
        let length = max(1, hypot(look.dx, look.dy))
        let reach = radius * 0.05 * min(1, length / 60)
        for pupil in pupils {
            pupil.position = CGPoint(x: look.dx / length * reach, y: look.dy / length * reach)
        }

        // Blink.
        if !eyes.isEmpty && now >= nextBlink {
            nextBlink = now + 2.2 + Double((phase * 1000).truncatingRemainder(dividingBy: 2.5))
            let blink = SKAction.sequence([.scaleY(to: 0.1, duration: 0.05), .scaleY(to: 1, duration: 0.07)])
            for eye in eyes { eye.run(blink) }
        }
    }
}

/// A Mood Stone: a static magnet with a mood.
@MainActor
final class StoneNode: SKNode {
    let bodyID: String
    let radius: CGFloat
    private(set) var mood: Mood
    private let sprite: SKSpriteNode
    private var field: SKShapeNode?
    private let rangeScale: CGFloat

    init(id: String, radius: CGFloat, mood: Mood, swappable: Bool, rangeScale: CGFloat) {
        bodyID = id
        self.radius = radius
        self.mood = mood
        self.rangeScale = rangeScale
        sprite = SKSpriteNode(texture: Art.stone(mood, radius: radius), size: CGSize(width: radius * 2, height: radius * 2))
        super.init()
        addChild(sprite)
        if swappable {
            let ring = SKShapeNode(circleOfRadius: radius + 6)
            ring.path = ring.path?.copy(dashingWithPhase: 0, lengths: [4, 4])
            ring.strokeColor = UIColor.white.withAlphaComponent(0.9)
            ring.lineWidth = 2
            ring.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 8)))
            addChild(ring)
        }
        updateField()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setMood(_ newMood: Mood, animated: Bool) {
        guard newMood != mood else { return }
        mood = newMood
        sprite.texture = Art.stone(newMood, radius: radius)
        updateField()
        if animated {
            sprite.run(.sequence([.scale(to: 1.3, duration: 0.08), .scale(to: 1, duration: 0.16)]))
        }
    }

    func refuse() {
        sprite.run(.sequence([.moveBy(x: 3, y: 0, duration: 0.04), .moveBy(x: -6, y: 0, duration: 0.06), .moveBy(x: 3, y: 0, duration: 0.04)]))
    }

    private func updateField() {
        field?.removeFromParent()
        field = nil
        let range: CGFloat
        switch mood {
        case .happy: range = CGFloat(Simulation.happyRange) * rangeScale
        case .grumpy: range = CGFloat(Simulation.grumpyRange) * rangeScale
        case .nervous: return
        }
        let ring = SKShapeNode(circleOfRadius: range)
        ring.strokeColor = MoodPalette.base(mood).withAlphaComponent(0.3)
        ring.fillColor = MoodPalette.light(mood).withAlphaComponent(0.07)
        ring.lineWidth = 1.5
        ring.zPosition = -5
        ring.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 1.2), .fadeAlpha(to: 1, duration: 1.2)])))
        insertChild(ring, at: 0)
        field = ring
    }
}
