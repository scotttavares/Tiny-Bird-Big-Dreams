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
    /// Points to float up out of the burst (0 shows none).
    var points = 0

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

            if points > 0 {
                Text("+\(points)")
                    .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white)
                    .shadow(color: color, radius: 6)
                    .shadow(color: Color.black.opacity(0.5), radius: 1, x: 0, y: 1)
                    .fixedSize()
                    .scaleEffect(0.7 + 0.5 * progress)
                    .offset(y: -size * (0.3 + 0.75 * progress))
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

/// A quick side-to-side shake. Animate `animatableData` from one whole number to
/// the next and the view shakes once and comes back to rest.
struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(animatableData * .pi * 6), y: 0))
    }
}

/// The player's coins, top-left of the screen.
struct CoinCounter: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xFFE26A), Color(hex: 0xF0A01F)], startPoint: .top, endPoint: .bottom))
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
            Text(coins.formatted(.number.grouping(.automatic)))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: coins)
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
        .background(Capsule().fill(Theme.glassFill))
        .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(coins) coins"))
    }
}

/// "x3" beside the rotation pill while quick merges are multiplying the score.
struct StreakChip: View {
    let multiplier: Int
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 2 * scale) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11 * scale, weight: .bold))
            Text("x\(multiplier)")
                .font(.system(size: 16 * scale, weight: .black, design: .rounded))
        }
        .foregroundStyle(Color(hex: 0x201400))
        .padding(.horizontal, 8 * scale)
        .frame(height: 28 * scale)
        .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0xFFE26A), Color(hex: 0xFF9F2E)], startPoint: .top, endPoint: .bottom)))
        .shadow(color: Color(hex: 0xFFB02E).opacity(0.8), radius: 6 * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Speed bonus, points times \(multiplier)"))
    }
}

/// The three boosters under the board. Each shows how many free uses are left,
/// or its price in coins once they are gone.
struct BoosterBar: View {
    let store: GameStore
    let scale: CGFloat
    let onTap: (GameStore.Booster) -> Void

    static func symbol(_ booster: GameStore.Booster) -> String {
        switch booster {
        case .flip: return "arrow.clockwise"
        case .sweep: return "wind"
        case .fever: return "flame.fill"
        }
    }

    static func name(_ booster: GameStore.Booster) -> String {
        switch booster {
        case .flip: return "Flip"
        case .sweep: return "Sweep"
        case .fever: return "Double"
        }
    }

    private func colors(_ booster: GameStore.Booster) -> [Color] {
        switch booster {
        case .flip: return [Color(hex: 0xC08CFF), Color(hex: 0x6C4BFF)]
        case .sweep: return [Color(hex: 0x86F2BC), Color(hex: 0x1FA5A0)]
        case .fever: return [Color(hex: 0xFF8AD8), Color(hex: 0xE0409F)]
        }
    }

    var body: some View {
        HStack(spacing: 22 * scale) {
            ForEach(GameStore.Booster.allCases, id: \.self) { booster in
                let count = store.boosterCounts[booster] ?? 0
                let usable = store.canAfford(booster) && !store.isGameOver
                Button {
                    onTap(booster)
                } label: {
                    VStack(spacing: 3 * scale) {
                        Image(systemName: Self.symbol(booster))
                            .font(.system(size: 22 * scale, weight: .heavy))
                            .foregroundStyle(Color.white)
                            .frame(width: 54 * scale, height: 54 * scale)
                            .background(
                                RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                                    .fill(LinearGradient(colors: colors(booster), startPoint: .top, endPoint: .bottom))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
                            )
                            .shadow(color: colors(booster)[1].opacity(0.7), radius: 7 * scale)
                            .overlay(alignment: .topTrailing) {
                                // Free uses left, or the price in coins.
                                Text(count > 0 ? "\(count)" : "\(booster.price)")
                                    .font(.system(size: 12 * scale, weight: .black, design: .rounded))
                                    .foregroundStyle(count > 0 ? Color.white : Color(hex: 0x201400))
                                    .padding(.horizontal, 6 * scale)
                                    .frame(minWidth: 22 * scale, minHeight: 20 * scale)
                                    .background(Capsule().fill(count > 0 ? Color(hex: 0xE8504F) : Color(hex: 0xFFD23F)))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                                    .offset(x: 9 * scale, y: -8 * scale)
                            }
                        Text(Self.name(booster))
                            .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.label)
                    }
                    .opacity(usable ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(
                    count > 0
                        ? "\(Self.name(booster)) booster, \(count) left"
                        : "\(Self.name(booster)) booster, costs \(booster.price) coins"
                ))
            }
        }
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

/// Shows a short banner over the board for each thing worth announcing.
struct GameBanners: ViewModifier {
    let store: GameStore
    /// Shows a message for a number of seconds.
    let show: (String, Double) -> Void

    /// Each special tile is explained the first time it turns up.
    @AppStorage("ff.seenClockTile") private var seenClockTile = false
    @AppStorage("ff.seenBombTile") private var seenBombTile = false

    func body(content: Content) -> some View {
        content
            .onChange(of: store.comboEvent) { _, _ in
                if store.isFever {
                    show("Chain x\(store.lastCombo)! Double points", 1.8)
                } else {
                    show("Chain x\(store.lastCombo)!", 1.1)
                }
            }
            .onChange(of: store.timeBonusEvent) { _, _ in
                show("+\(Int(GameStore.timeBonus)) seconds", 1.1)
            }
            .onChange(of: store.bombEvent) { _, _ in
                show("Boom!", 1.1)
            }
            .onChange(of: store.specialSpawnEvent) { _, _ in
                if store.lastSpecialKind == .time, !seenClockTile {
                    seenClockTile = true
                    show("Clock tile: merge it for +\(Int(GameStore.timeBonus)) seconds", 3.2)
                } else if store.lastSpecialKind == .bomb, !seenBombTile {
                    seenBombTile = true
                    show("Bomb tile: merge it to blast its neighbours", 3.2)
                }
            }
            .onChange(of: store.boosterEvent) { _, _ in
                switch store.lastBooster {
                case .flip: show("Flip!", 1.0)
                case .sweep: show("Swept \(store.lastSweepCount) tiles", 1.2)
                case .fever: show("Double points!", 1.4)
                }
            }
            .onChange(of: store.boosterDeniedEvent) { _, _ in
                let booster = store.lastBooster
                if store.canAfford(booster) {
                    show("No 2s or 4s to sweep", 1.6)
                } else {
                    show("\(BoosterBar.name(booster)) costs \(booster.price) coins", 1.8)
                }
            }
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
            .onChange(of: store.boosterEvent) { _, _ in
                if store.lastBooster == .sweep {
                    sounds.play(.boom, volume: 0.7)
                }
            }
            .onChange(of: store.boosterDeniedEvent) { _, _ in
                sounds.play(.tick)
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
