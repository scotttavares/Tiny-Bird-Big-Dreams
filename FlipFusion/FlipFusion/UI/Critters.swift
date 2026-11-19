import SwiftUI

/// The creatures that can come out of a crate (the shark also surfaces by itself in
/// the Ocean theme). Each has two painted poses in the asset catalogue, named
/// "critter-" and its name, and the same with "-2" on the end; flipping between
/// them is what makes it bite, flail or stomp. Without pictures it is an emoji.
enum Critter: String, Equatable, Sendable {
    case shark, monkey, ufo, trex

    /// The picture of a pose: 0 is the first, anything else the second.
    func imageName(pose: Int) -> String {
        pose == 0 ? "critter-" + rawValue : "critter-" + rawValue + "-2"
    }

    var emoji: String {
        switch self {
        case .shark: return "\u{1F988}"
        case .monkey: return "\u{1F412}"
        case .ufo: return "\u{1F6F8}"
        case .trex: return "\u{1F996}"
        }
    }
}

/// A creature at a given width, in one of its two poses. Both poses are kept on
/// screen and only one shown, so changing pose never flickers.
struct CritterSprite: View {
    let critter: Critter
    let width: CGFloat
    var pose = 0

    var body: some View {
        let first = critter.imageName(pose: 0)
        let second = critter.imageName(pose: 1)
        let hasFirst = UIImage(named: first) != nil
        let hasSecond = UIImage(named: second) != nil

        Group {
            if hasFirst {
                ZStack {
                    Image(first)
                        .resizable()
                        .scaledToFit()
                        .opacity(pose == 0 || !hasSecond ? 1 : 0)
                    if hasSecond {
                        Image(second)
                            .resizable()
                            .scaledToFit()
                            .opacity(pose == 0 ? 0 : 1)
                    }
                }
                .frame(width: width)
                .shadow(color: Color.black.opacity(0.5), radius: width * 0.04, x: 0, y: width * 0.03)
            } else {
                Text(critter.emoji)
                    .font(.system(size: width * 0.8))
            }
        }
    }
}

/// One creature wrecking the board. It is laid out in a square the size of the
/// board and spills well outside it. `onHit` is called at each bite, landing, beam
/// or stomp, counting from 1, so the board can be shaken and a sound played in time.
struct CritterAttack: View {
    let critter: Critter
    let side: CGFloat
    let onHit: (Int) -> Void

    var body: some View {
        Group {
            switch critter {
            case .shark: SharkLunge(side: side, onHit: onHit)
            case .monkey: MonkeyRampage(side: side, onHit: onHit)
            case .ufo: UFORaid(side: side, onHit: onHit)
            case .trex: TrexStomp(side: side, onHit: onHit)
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The shark bursts up from below the board with its jaws open, bites down four
/// times, lunging and twisting with each bite, and sinks back.
struct SharkLunge: View {
    let side: CGFloat
    let onHit: (Int) -> Void

    @State private var isUp = false
    @State private var isGone = false
    @State private var pose = 0
    @State private var lean = 0.0
    @State private var lunge: CGFloat = 0

    var body: some View {
        CritterSprite(critter: .shark, width: side * 1.2, pose: pose)
            .rotationEffect(.degrees(lean), anchor: .bottom)
            .scaleEffect(pose == 1 ? 1.08 : 1, anchor: .bottom)
            .offset(y: isUp && !isGone ? side * 0.14 - lunge : side * 2)
            .task {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    isUp = true
                }
                try? await Task.sleep(for: .milliseconds(260))
                for bite in 1...4 {
                    // Rear back with the jaws open, twisting to one side...
                    withAnimation(.easeOut(duration: 0.12)) {
                        pose = 0
                        lean = bite % 2 == 0 ? 11 : -11
                        lunge = -side * 0.05
                    }
                    try? await Task.sleep(for: .milliseconds(150))
                    // ...then snap them shut on the board.
                    withAnimation(.easeIn(duration: 0.06)) {
                        pose = 1
                        lunge = side * 0.1
                    }
                    onHit(bite)
                    try? await Task.sleep(for: .milliseconds(140))
                }
                withAnimation(.easeOut(duration: 0.12)) {
                    pose = 0
                    lean = 0
                    lunge = 0
                }
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeIn(duration: 0.45)) {
                    isGone = true
                }
            }
    }
}

/// The monkey springs out and bounces to five spots round the board. In the air it
/// is tucked up in a somersault; it lands flung wide, squashes, and is off again.
struct MonkeyRampage: View {
    let side: CGFloat
    let onHit: (Int) -> Void

    /// Where it lands, as fractions of the board's side from its centre.
    private static let spots: [CGSize] = [
        CGSize(width: -0.25, height: -0.2), CGSize(width: 0.25, height: -0.27),
        CGSize(width: 0.22, height: 0.22), CGSize(width: -0.24, height: 0.2),
        CGSize(width: 0, height: -0.05),
    ]

    @State private var spot = -1
    @State private var spin = 0.0
    @State private var pose = 1
    @State private var isSquashed = false
    @State private var isGone = false

    private var place: CGSize {
        if isGone {
            return CGSize(width: side * 0.3, height: -side * 1.3)
        }
        guard spot >= 0 else {
            return CGSize(width: 0, height: side * 1.1)
        }
        let at = Self.spots[spot % Self.spots.count]
        return CGSize(width: at.width * side, height: at.height * side)
    }

    var body: some View {
        CritterSprite(critter: .monkey, width: side * 0.52, pose: pose)
            .rotationEffect(.degrees(spin))
            .scaleEffect(x: isSquashed ? 1.22 : 1, y: isSquashed ? 0.78 : 1)
            .offset(place)
            .task {
                for hop in 0..<Self.spots.count {
                    // Tucked up and spinning through the air.
                    pose = 1
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                        spot = hop
                        spin += 360
                        isSquashed = false
                    }
                    try? await Task.sleep(for: .milliseconds(270))
                    // Landing, arms and legs flung wide.
                    pose = 0
                    withAnimation(.easeOut(duration: 0.08)) {
                        isSquashed = true
                    }
                    onHit(hop + 1)
                    try? await Task.sleep(for: .milliseconds(160))
                }
                pose = 1
                withAnimation(.easeIn(duration: 0.35)) {
                    isSquashed = false
                    spin += 360
                    isGone = true
                }
            }
    }
}

/// The flying saucer swoops in and hovers over the board, its lights running round
/// and the aliens jumping about inside, shines its beam down twice, and shoots off.
struct UFORaid: View {
    let side: CGFloat
    let onHit: (Int) -> Void

    /// 0 on its way in, 1 hovering, 2 gone.
    @State private var stage = 0
    @State private var isBeaming = false
    @State private var isBobbing = false
    @State private var pose = 0

    var body: some View {
        ZStack {
            // The beam: a cone of light widening down onto the board.
            Outline(points: [CGPoint(x: 0.4, y: 0), CGPoint(x: 0.6, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)])
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xC8FF6A, opacity: 0.85), Color(hex: 0x6AFFE0, opacity: 0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: side * 0.85, height: side * 0.8)
                .offset(y: side * 0.12)
                .opacity(isBeaming ? 1 : 0)
                .scaleEffect(x: isBeaming ? 1 : 0.3, y: 1, anchor: .top)

            CritterSprite(critter: .ufo, width: side * 0.72, pose: pose)
                .rotationEffect(.degrees(isBobbing ? 5 : -5))
                .offset(y: -side * 0.44 + (isBobbing ? -7 : 7))
        }
        .offset(x: stage == 0 ? -side * 1.3 : (stage == 2 ? side * 1.4 : 0), y: stage == 1 ? 0 : -side * 0.6)
        .task {
            // The lights and the aliens never stop moving.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(170))
                pose = 1 - pose
            }
        }
        .task {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                stage = 1
            }
            withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                isBobbing = true
            }
            try? await Task.sleep(for: .milliseconds(420))
            for flash in 1...2 {
                withAnimation(.easeOut(duration: 0.15)) {
                    isBeaming = true
                }
                onHit(flash)
                try? await Task.sleep(for: .milliseconds(380))
                withAnimation(.easeIn(duration: 0.12)) {
                    isBeaming = false
                }
                try? await Task.sleep(for: .milliseconds(160))
            }
            withAnimation(.easeIn(duration: 0.35)) {
                stage = 2
            }
        }
    }
}

/// The T-rex stamps across the board from right to left, three heavy steps, changing
/// legs and snapping its jaws with each one.
struct TrexStomp: View {
    let side: CGFloat
    let onHit: (Int) -> Void

    /// Where it stands after each step, as fractions of the board's side from its
    /// centre: off to the right, three steps across, then off to the left.
    private static let steps: [CGFloat] = [1.4, 0.3, 0, -0.3, -1.5]

    @State private var step = 0
    @State private var isDown = true
    @State private var pose = 0

    var body: some View {
        CritterSprite(critter: .trex, width: side * 0.98, pose: pose)
            .rotationEffect(.degrees(isDown ? 3 : -7))
            .offset(x: Self.steps[step] * side, y: isDown ? side * 0.04 : -side * 0.13)
            .task {
                for stomp in 1...3 {
                    // One leg up, head back, roaring...
                    pose = 0
                    withAnimation(.easeOut(duration: 0.22)) {
                        step = stomp
                        isDown = false
                    }
                    try? await Task.sleep(for: .milliseconds(230))
                    // ...then down it comes on the other, jaws snapping.
                    pose = 1
                    withAnimation(.easeIn(duration: 0.07)) {
                        isDown = true
                    }
                    onHit(stomp)
                    try? await Task.sleep(for: .milliseconds(230))
                }
                pose = 0
                withAnimation(.easeIn(duration: 0.3)) {
                    step = 4
                    isDown = false
                }
            }
    }
}
