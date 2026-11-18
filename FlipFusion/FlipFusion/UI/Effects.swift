import SwiftUI

/// The countdown ring that sits between the Score and Best cards.
struct TimerRing: View {
    let store: GameStore
    let scale: CGFloat

    var body: some View {
        let isEndless = store.mode == .endless
        let left = store.secondsLeft
        let fraction: CGFloat = isEndless ? 1 : CGFloat(max(0, min(1, left / GameStore.roundSeconds)))
        let whole = Int(left.rounded(.up))
        let isLow = !isEndless && left <= 10
        let tint: Color = isEndless ? Theme.arrowLight : (isLow ? Theme.timerLow : Theme.dotOn)
        let beat = isLow && store.isTimerRunning && whole % 2 == 0

        ZStack {
            Circle()
                .stroke(Theme.glassStroke, lineWidth: 4 * scale)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.8), radius: 4 * scale)
            if isEndless {
                // No clock in the endless game.
                Image(systemName: "infinity")
                    .font(.system(size: 19 * scale, weight: .heavy))
                    .foregroundStyle(Color.white)
            } else {
                Text(String(format: "%d:%02d", whole / 60, whole % 60))
                    .font(.system(size: 15 * scale, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isLow ? tint : Color.white)
            }
        }
        .frame(width: 54 * scale, height: 54 * scale)
        .scaleEffect(beat ? 1.1 : 1)
        .animation(.easeInOut(duration: 0.3), value: whole)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isEndless ? "Endless game, no clock" : "\(whole) seconds left"))
    }
}

/// A ring and eight sparks that fly out of a tile when it merges.
struct MergeBurst: View {
    let color: Color
    let size: CGFloat
    /// A bomb's blast reaches the cells around it.
    var isBlast = false

    @State private var progress: CGFloat = 0

    var body: some View {
        let ringGrowth: CGFloat = isBlast ? 2.1 : 0.5
        let reach: CGFloat = isBlast ? size * 1.7 : size * 0.8
        let sparks = isBlast ? 14 : 8
        let sparkSize: CGFloat = isBlast ? size * 0.22 : size * 0.15

        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .strokeBorder(isBlast ? color : Color.white.opacity(0.9), lineWidth: isBlast ? 5 : 3)
                .scaleEffect(1 + ringGrowth * progress)

            ForEach(0..<sparks, id: \.self) { index in
                let angle = CGFloat(index) / CGFloat(sparks) * 2 * .pi
                Circle()
                    .fill(color)
                    .frame(width: sparkSize, height: sparkSize)
                    .shadow(color: color, radius: 3)
                    .offset(
                        x: cos(angle) * reach * progress,
                        y: sin(angle) * reach * progress
                    )
            }
        }
        .frame(width: size, height: size)
        .opacity(Double(1 - progress))
        .onAppear {
            // Wait for the tiles to finish sliding together.
            withAnimation(.easeOut(duration: 0.45).delay(0.12)) {
                progress = 1
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// "+16" floating up from the Score card.
struct GainPop: View {
    let amount: Int
    let scale: CGFloat

    @State private var risen = false

    var body: some View {
        Text("+\(amount)")
            .font(.system(size: 20 * scale, weight: .black, design: .rounded))
            .foregroundStyle(Theme.counter)
            .shadow(color: Theme.counter.opacity(0.7), radius: 5 * scale)
            .offset(y: risen ? -30 * scale : -4 * scale)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    risen = true
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Plays a sound for each thing that happens in the game.
struct GameSounds: ViewModifier {
    let store: GameStore
    let sounds: SoundPlayer

    func body(content: Content) -> some View {
        content
            .onChange(of: store.slidePulse) { _, _ in
                sounds.play(.slide, volume: 0.5)
            }
            .onChange(of: store.mergePulse) { _, _ in
                sounds.play(SoundPlayer.merge(for: store.lastMergeValue), volume: 0.9)
            }
            .onChange(of: store.rotatePulse) { _, _ in
                sounds.play(.rotate, volume: 0.8)
            }
            .onChange(of: store.comboEvent) { _, _ in
                sounds.play(.chain)
            }
            .onChange(of: store.feverEvent) { _, _ in
                sounds.play(.fever, volume: 0.9)
            }
            .onChange(of: store.specialSpawnEvent) { _, _ in
                sounds.play(.powerup, volume: 0.8)
            }
            .onChange(of: store.mode) { _, _ in
                sounds.play(.mode, volume: 0.8)
            }
            .onChange(of: store.bombEvent) { _, _ in
                sounds.play(.boom)
            }
            .onChange(of: store.timeBonusEvent) { _, _ in
                sounds.play(.bonus)
            }
            .onChange(of: store.wholeSecondsLeft) { _, seconds in
                if seconds >= 1, seconds <= 10, store.isTimerRunning {
                    sounds.play(.tick, volume: 0.7)
                }
            }
            .onChange(of: store.isGameOver) { _, isOver in
                sounds.play(isOver ? .over : .start, volume: 0.9)
            }
    }
}
