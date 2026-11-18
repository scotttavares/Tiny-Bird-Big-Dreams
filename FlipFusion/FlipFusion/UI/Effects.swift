import SwiftUI

/// The countdown ring that sits between the Score and Best cards.
struct TimerRing: View {
    let store: GameStore
    let scale: CGFloat

    var body: some View {
        let left = store.secondsLeft
        let fraction = CGFloat(max(0, min(1, left / GameStore.roundSeconds)))
        let whole = Int(left.rounded(.up))
        let isLow = left <= 10
        let tint: Color = isLow ? Theme.timerLow : Theme.dotOn
        let beat = isLow && store.isTimerRunning && whole % 2 == 0

        ZStack {
            Circle()
                .stroke(Theme.glassStroke, lineWidth: 4 * scale)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.8), radius: 4 * scale)
            Text(String(format: "%d:%02d", whole / 60, whole % 60))
                .font(.system(size: 15 * scale, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isLow ? tint : Color.white)
        }
        .frame(width: 54 * scale, height: 54 * scale)
        .scaleEffect(beat ? 1.1 : 1)
        .animation(.easeInOut(duration: 0.3), value: whole)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(whole) seconds left"))
    }
}

/// A ring and eight sparks that fly out of a tile when it merges.
struct MergeBurst: View {
    let color: Color
    let size: CGFloat

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                .scaleEffect(1 + 0.5 * progress)

            ForEach(0..<8, id: \.self) { index in
                let angle = CGFloat(index) / 8 * 2 * .pi
                Circle()
                    .fill(color)
                    .frame(width: size * 0.15, height: size * 0.15)
                    .shadow(color: color, radius: 3)
                    .offset(
                        x: cos(angle) * size * 0.8 * progress,
                        y: sin(angle) * size * 0.8 * progress
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
