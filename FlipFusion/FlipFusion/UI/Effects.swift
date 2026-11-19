import SwiftUI

/// The countdown ring that sits between the Score and Best cards.
struct TimerRing: View {
    let store: GameStore
    let scale: CGFloat

    var body: some View {
        let isEndless = store.mode != .timed
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
        .accessibilityLabel(Text(isEndless ? "No clock in this game" : "\(whole) seconds left"))
    }
}

/// A ring and eight sparks that fly out of a tile when it merges.
struct MergeBurst: View {
    let color: Color
    let size: CGFloat
    /// A bomb's blast reaches the cells around it.
    var isBlast = false
    /// A super combo throws its sparks further.
    var isSuper = false
    /// Points to float up out of the burst (0 shows none).
    var points = 0
    /// The theme's own spark and tile shape.
    var spark: String = Skin.current.spark
    var shape: Skin.TileShape = Skin.current.shape
    /// Themes beyond the free one throw more sparks and a second ring.
    var flair: Bool = Skin.current.isPremium
    /// Merges made since the board last turned: each one makes the burst bigger.
    var heat = 0

    @State private var progress: CGFloat = 0

    var body: some View {
        let isBig = isBlast || isSuper
        // The second merge before a turn is a fifth bigger, the third two fifths, and
        // so on up to double.
        let extra = min(max(heat - 1, 0), 5)
        let boost = 1 + CGFloat(extra) * 0.2
        let ringGrowth: CGFloat = (isBlast ? 2.1 : (isSuper ? 1.3 : 0.5)) * boost
        let reach: CGFloat = (isBlast ? size * 1.7 : (isSuper ? size * 1.4 : size * 0.8)) * boost
        let sparks = (isBig ? 14 : 8) + (flair ? 6 : 0) + extra * 2
        let sparkSize: CGFloat = (isBig ? size * 0.22 : size * 0.15) * (1 + CGFloat(extra) * 0.1)

        ZStack {
            TileOutline(shape: shape)
                .strokeBorder(isBlast ? color : Color.white.opacity(0.9), lineWidth: isBlast ? 5 : 3)
                .scaleEffect(1 + ringGrowth * progress)

            if flair {
                TileOutline(shape: shape)
                    .strokeBorder(color.opacity(0.7), lineWidth: 2)
                    .scaleEffect(1 + ringGrowth * 2.2 * progress)
            }

            ForEach(0..<sparks, id: \.self) { index in
                let angle = CGFloat(index) / CGFloat(sparks) * 2 * .pi
                Image(systemName: spark)
                    .font(.system(size: sparkSize * 1.25, weight: .bold))
                    .foregroundStyle(color)
                    .shadow(color: color, radius: 3)
                    .rotationEffect(.degrees(Double(progress) * 180))
                    .offset(
                        x: cos(angle) * reach * progress,
                        y: sin(angle) * reach * progress
                    )
            }

            if points > 0 {
                Text("+\(points)")
                    .font(.system(size: size * (isSuper ? 0.6 : 0.42), weight: .black, design: .rounded))
                    .foregroundStyle(isSuper ? Color(hex: 0xFFE26A) : Color.white)
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

/// A quick shake. Animate `animatableData` from one whole number to the next and the
/// view shakes once and comes back to rest. `power` 1 is a nudge from side to side;
/// 2 and 3 are harder and rattle up and down as well.
struct Shake: GeometryEffect {
    var power: Int = 1
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let reach = CGFloat(3 + 4 * power)
        let x = reach * sin(animatableData * .pi * 6)
        let y = power > 1 ? reach * 0.5 * sin(animatableData * .pi * 8) : 0
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
    }
}

/// A big word that bounces in over the board, then floats up and fades.
struct Callout: View {
    let text: String
    let scale: CGFloat

    /// 0 not yet shown, 1 bounced in, 2 floating away.
    @State private var stage = 0

    var body: some View {
        Text(text)
            .font(.system(size: 40 * scale, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: [Color.white, Color(hex: 0xFFE26A)], startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: Theme.fusion[0], radius: 10 * scale)
            .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 2)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: 300 * scale)
            .rotationEffect(.degrees(stage == 0 ? -14 : -4))
            .scaleEffect(stage == 0 ? 0.2 : (stage == 1 ? 1 : 1.25))
            .offset(y: stage == 2 ? -50 * scale : 0)
            .opacity(stage == 1 ? 1 : 0)
            .task {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
                    stage = 1
                }
                // Short, so it is never in the way of the next move.
                try? await Task.sleep(for: .milliseconds(550))
                withAnimation(.easeIn(duration: 0.25)) {
                    stage = 2
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A white flash over the board.
struct Flash: View {
    let side: CGFloat

    @State private var faded = false

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.07, style: .continuous)
            .fill(Color.white)
            .opacity(faded ? 0 : 0.55)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    faded = true
                }
            }
    }
}

/// Coloured paper thrown out from the middle of the board.
struct Confetti: View {
    let side: CGFloat
    /// Themes beyond the free one throw their own sparks instead of paper.
    var symbol: String? = Skin.current.isPremium ? Skin.current.spark : nil

    @State private var progress: CGFloat = 0

    private static let colors: [Color] = [
        Color(hex: 0xFF8AD8), Color(hex: 0xFFE26A), Color(hex: 0x86F2BC),
        Color(hex: 0x8FF0FF), Color(hex: 0xC08CFF), Color(hex: 0xFF9F2E),
    ]

    var body: some View {
        let width = side * 0.035

        ZStack {
            ForEach(0..<30, id: \.self) { index in
                // The golden angle spreads the pieces evenly without a random source.
                let angle = Double(index) * 2.399963
                let reach = side * (0.35 + 0.04 * CGFloat((index * 37) % 10))
                let spin = 360.0 + Double((index * 47) % 360)
                Group {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: width * 2.2, weight: .bold))
                            .foregroundStyle(Self.colors[index % Self.colors.count])
                    } else {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Self.colors[index % Self.colors.count])
                            .frame(width: width, height: width * 1.8)
                    }
                }
                    .rotationEffect(.degrees(Double(progress) * spin))
                    .offset(
                        x: CGFloat(cos(angle)) * reach * progress,
                        y: CGFloat(sin(angle)) * reach * progress + side * 0.3 * progress
                    )
            }
        }
        .opacity(Double(1 - progress))
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) {
                progress = 1
            }
        }
    }
}

/// The flashes and confetti that play over the board.
struct Celebration: View {
    let store: GameStore
    let side: CGFloat

    @State private var confettiID = 0

    var body: some View {
        ZStack {
            if store.flashEvent > 0 {
                Flash(side: side)
                    .id(store.flashEvent)
            }
            if confettiID > 0 {
                Confetti(side: side)
                    .id(confettiID)
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: store.superEvent) { _, _ in
            confettiID += 1
        }
        .onChange(of: store.comboEvent) { _, _ in
            confettiID += 1
        }
        .onChange(of: store.levelEvent) { _, _ in
            confettiID += 1
        }
        .onChange(of: store.heatEvent) { _, _ in
            // Five merges before the board turns earns confetti.
            if store.turnMerges >= 5 {
                confettiID += 1
            }
        }
        .onChange(of: store.isGameOver) { _, isOver in
            // A new best score gets a send-off.
            if isOver, store.state.score > 0, store.state.score >= store.best {
                confettiID += 1
            }
        }
    }
}

/// A button that squashes when pressed and springs back.
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// The two ways to play, as two labelled buttons under the tagline.
struct ModeSwitch: View {
    let scale: CGFloat
    let mode: GameStore.Mode
    /// Games the player has not unlocked yet: shown with a padlock.
    var lockedModes: Set<GameStore.Mode> = []
    let onPick: (GameStore.Mode) -> Void

    var body: some View {
        HStack(spacing: 6 * scale) {
            option(.timed, symbol: "timer", title: "2 Minutes")
            option(.endless, symbol: "infinity", title: "Endless")
            option(.shift, symbol: "shuffle", title: "Shape Shift")
        }
    }

    private func option(_ target: GameStore.Mode, symbol: String, title: String) -> some View {
        let isOn = mode == target
        return Button {
            onPick(target)
        } label: {
            HStack(spacing: 5 * scale) {
                Image(systemName: lockedModes.contains(target) ? "lock.fill" : symbol)
                    .font(.system(size: 12 * scale, weight: .heavy))
                Text(title)
                    .font(.system(size: 14 * scale, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(isOn ? Color.white : Theme.label)
            .lineLimit(1)
            .padding(.horizontal, 10 * scale)
            .frame(height: 34 * scale)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [Theme.pillTop, Theme.pillBottom], startPoint: .top, endPoint: .bottom)
                )
                .opacity(isOn ? 1 : 0)
            )
            .background(Capsule().fill(Theme.glassFill))
            .overlay(Capsule().strokeBorder(isOn ? Theme.pillStroke : Theme.glassStroke, lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityLabel(Text(title + " game" + (isOn ? ", selected" : "")))
    }
}

/// The taps and thumps the phone makes as the game is played.
struct GameHaptics: ViewModifier {
    let store: GameStore

    @AppStorage("ff.hapticsOn") private var hapticsOn = true

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(trigger: store.mergePulse) { _, _ in
                hapticsOn ? .impact(weight: .light) : nil
            }
            .sensoryFeedback(trigger: store.rotatePulse) { _, _ in
                hapticsOn ? .impact(weight: .heavy) : nil
            }
            .sensoryFeedback(trigger: store.shakeEvent) { _, _ in
                hapticsOn ? .impact(weight: .heavy, intensity: 1) : nil
            }
            .sensoryFeedback(trigger: store.superEvent) { _, _ in
                hapticsOn ? .success : nil
            }
            .sensoryFeedback(trigger: store.levelEvent) { _, _ in
                hapticsOn ? .success : nil
            }
            .sensoryFeedback(trigger: store.isDanger) { _, isDanger in
                hapticsOn && isDanger ? .warning : nil
            }
    }
}

/// The player's coins and gems, top-left of the screen.
struct CoinCounter: View {
    let coins: Int
    let gems: Int

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
            Image(systemName: "diamond.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0x8FF0FF), Color(hex: 0xC08CFF)], startPoint: .top, endPoint: .bottom))
                .padding(.leading, 5)
            Text(gems.formatted(.number.grouping(.automatic)))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: gems)
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
        .background(Capsule().fill(Theme.glassFill))
        .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(coins) coins, \(gems) gems"))
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
        case .fever: return "star.fill"
        case .arm: return "flame.fill"
        }
    }

    static func name(_ booster: GameStore.Booster) -> String {
        switch booster {
        case .flip: return "Flip"
        case .sweep: return "Sweep"
        case .fever: return "Double"
        case .arm: return "Bombs"
        }
    }

    private func colors(_ booster: GameStore.Booster) -> [Color] {
        switch booster {
        case .flip: return [Color(hex: 0xC08CFF), Color(hex: 0x6C4BFF)]
        case .sweep: return [Color(hex: 0x86F2BC), Color(hex: 0x1FA5A0)]
        case .fever: return [Color(hex: 0xFF8AD8), Color(hex: 0xE0409F)]
        case .arm: return [Color(hex: 0xFFC14A), Color(hex: 0xE8582F)]
        }
    }

    var body: some View {
        HStack(spacing: 18 * scale) {
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
                .buttonStyle(BounceButtonStyle())
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
    /// Bounces a big word in over the board.
    let callout: (String) -> Void

    /// Each special tile is explained the first time it turns up.
    @AppStorage("ff.seenClockTile") private var seenClockTile = false
    @AppStorage("ff.seenBombTile") private var seenBombTile = false
    @AppStorage("ff.seenStoneTile") private var seenStoneTile = false
    @AppStorage("ff.seenBlocks") private var seenBlocks = false
    @AppStorage("ff.seenCrate") private var seenCrate = false

    func body(content: Content) -> some View {
        content
            .onChange(of: store.comboEvent) { _, _ in
                callout("Chain x\(store.lastCombo)! Double points!")
                show("Chain reward: a power-up tile and double points", 2.2)
            }
            .onChange(of: store.timeBonusEvent) { _, _ in
                show("+\(Int(GameStore.timeBonus)) seconds", 1.1)
            }
            .onChange(of: store.bombEvent) { _, _ in
                callout(store.lastBombCount > 1 ? "Chain reaction!" : "Boom!")
            }
            .onChange(of: store.superEvent) { _, _ in
                callout(store.lastSuperCount >= 4 ? "MEGA COMBO!" : "Super combo!")
            }
            .onChange(of: store.streak) { _, streak in
                if streak == 2 {
                    callout("Nice!")
                } else if streak == GameStore.maxStreak {
                    callout("Unstoppable!")
                }
            }
            .onChange(of: store.wholeSecondsLeft) { _, seconds in
                if seconds == 10, store.isTimerRunning {
                    callout("10 seconds!")
                }
            }
            .onChange(of: store.gemEvent) { _, _ in
                show(store.lastGemGain == 1 ? "+1 gem" : "+\(store.lastGemGain) gems", 1.2)
            }
            .onChange(of: store.unlockEvent) { _, _ in
                callout("New theme: \(store.lastUnlockedSkin)!")
            }
            .onChange(of: store.levelEvent) { _, _ in
                callout("Level \(store.level)!")
                if store.level == 3 {
                    show("Stone blocks are coming. Bombs and Sweep clear them.", 3.4)
                } else if store.level == 4 {
                    show("Faster now: extra tiles drop in", 2.6)
                } else if store.mode == .timed {
                    show("+\(Int(GameStore.levelTimeBonus)) seconds", 1.2)
                }
            }
            .onChange(of: store.continueEvent) { _, _ in
                callout("Keep going!")
            }
            .onChange(of: store.heatEvent) { _, _ in
                callout(store.turnMerges >= 5 ? "On fire! x\(store.turnMerges)" : "Combo x\(store.turnMerges)!")
            }
            .onChange(of: store.shapeEvent) { _, _ in
                if store.mode == .shift {
                    callout((GameEngine.silhouetteName(store.state.shapeID) ?? "Shape shift") + "!")
                }
                if !store.state.blocks.isEmpty {
                    if !seenBlocks {
                        seenBlocks = true
                        show("New board shape: tiles stop at walls and holes", 3.4)
                    } else if !seenCrate, store.state.blocks.contains(where: { $0.kind == .crate }) {
                        seenCrate = true
                        show("Crates: merge beside one to smash it", 3.4)
                    }
                }
            }
            .onChange(of: store.crateEvent) { _, _ in
                callout(store.lastCrateCount > 1 ? "Smash x\(store.lastCrateCount)!" : "Smash!")
            }
            .onChange(of: store.directionEvent) { _, _ in
                callout("Reversed!")
            }
            .onChange(of: store.specialSpawnEvent) { _, _ in
                if store.lastSpecialKind == .time, !seenClockTile {
                    seenClockTile = true
                    show("Clock tile: merge it for +\(Int(GameStore.timeBonus)) seconds", 3.2)
                } else if store.lastSpecialKind == .bomb, !seenBombTile {
                    seenBombTile = true
                    show("Bomb tile: merge it to blast its neighbours", 3.2)
                } else if store.lastSpecialKind == .stone, !seenStoneTile {
                    seenStoneTile = true
                    show("Stone block: it never merges. Blast it with a bomb.", 3.4)
                }
            }
            .onChange(of: store.boosterEvent) { _, _ in
                switch store.lastBooster {
                case .flip: show("Flip!", 1.0)
                case .sweep: show("Swept \(store.lastSweepCount) tiles", 1.2)
                case .fever: show("Double points!", 1.4)
                case .arm: show("\(store.lastArmCount) tiles armed", 1.2)
                }
            }
            .onChange(of: store.boosterDeniedEvent) { _, _ in
                let booster = store.lastBooster
                if store.canAfford(booster) {
                    show(booster == .arm ? "No tiles to arm" : "No 2s or 4s to sweep", 1.6)
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
                } else if store.lastBooster == .arm {
                    sounds.play(.powerup)
                }
            }
            .onChange(of: store.superEvent) { _, _ in
                sounds.play(.combo)
            }
            .onChange(of: store.unlockEvent) { _, _ in
                sounds.play(.fever)
            }
            .onChange(of: store.boosterDeniedEvent) { _, _ in
                sounds.play(.tick)
            }
            .onChange(of: store.feverEvent) { _, _ in
                sounds.play(.fever, volume: 0.9)
            }
            .onChange(of: store.specialSpawnEvent) { _, _ in
                sounds.play(store.lastSpecialKind == .stone ? .tick : .powerup, volume: 0.8)
            }
            .onChange(of: store.levelEvent) { _, _ in
                sounds.play(.combo)
            }
            .onChange(of: store.streak) { old, new in
                if new > old {
                    sounds.play(.powerup, volume: 0.7)
                }
            }
            .onChange(of: store.shapeEvent) { _, _ in
                sounds.play(.mode, volume: 0.8)
            }
            .onChange(of: store.crateEvent) { _, _ in
                sounds.play(.boom, volume: 0.6)
            }
            .onChange(of: store.directionEvent) { _, _ in
                sounds.play(.mode)
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
                if seconds == 10, store.isTimerRunning {
                    sounds.play(.hurry)
                } else if seconds >= 1, seconds < 10, store.isTimerRunning {
                    sounds.play(.tick, volume: 0.7)
                }
            }
            .onChange(of: store.isGameOver) { _, isOver in
                sounds.play(isOver ? .over : .start, volume: 0.9)
            }
    }
}

/// "LEVEL 3", a bar that fills as the score climbs toward the next level, and the
/// score that level starts at.
struct LevelBar: View {
    let level: Int
    let score: Int
    let scale: CGFloat

    var body: some View {
        let from = GameEngine.scoreNeeded(forLevel: level)
        let target = GameEngine.scoreNeeded(forLevel: level + 1)
        let done = Double(score - from) / Double(max(1, target - from))
        let fraction = CGFloat(max(0, min(1, done)))

        HStack(spacing: 8 * scale) {
            Text("LEVEL \(level)")
                .font(.system(size: 12 * scale, weight: .black, design: .rounded))
                .foregroundStyle(Theme.counter)
                .fixedSize()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.cellFill)
                    Capsule()
                        .fill(LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.height, geo.size.width * fraction))
                        .shadow(color: Theme.fusion[0].opacity(0.8), radius: 4 * scale)
                }
            }
            .frame(height: 9 * scale)
            .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
            Text(target.formatted(.number.grouping(.automatic)))
                .font(.system(size: 12 * scale, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.label)
                .fixedSize()
        }
        .frame(height: 14 * scale)
        .animation(.easeOut(duration: 0.3), value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Level \(level). Next level at \(target) points"))
    }
}

/// A red rim that beats round the board while it is nearly full.
struct DangerGlow: View {
    let side: CGFloat

    @State private var isBright = false

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.07, style: .continuous)
            .strokeBorder(Theme.timerLow, lineWidth: 4)
            .shadow(color: Theme.timerLow, radius: side * 0.05)
            .opacity(isBright ? 0.95 : 0.2)
            .frame(width: side, height: side)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
                    isBright = true
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The prize reel of a new level: it flicks through the prizes, slows, and stops on
/// the one that was won.
struct PrizeReel: View {
    let prize: GameStore.Prize
    let scale: CGFloat
    /// Called on every flick of the reel, and once when it stops.
    let onTick: () -> Void
    let onStop: () -> Void

    @State private var step = 0
    @State private var isStopped = false
    @State private var isGone = false

    static func symbol(_ prize: GameStore.Prize) -> String {
        switch prize {
        case .coins: return "circle.circle.fill"
        case .gems: return "diamond.fill"
        case .booster(let booster): return BoosterBar.symbol(booster)
        }
    }

    static func words(_ prize: GameStore.Prize) -> String {
        switch prize {
        case .coins(let count): return "+\(count) coins"
        case .gems(let count): return count == 1 ? "+1 gem" : "+\(count) gems"
        case .booster(let booster): return "Free \(BoosterBar.name(booster))"
        }
    }

    var body: some View {
        let faces = GameStore.reelFaces
        let face = isStopped ? prize : faces[step % faces.count]
        let isJackpot = isStopped && prize == GameStore.jackpot
        let gold = Color(hex: 0xFFD23F)

        VStack(spacing: 2 * scale) {
            Text(isJackpot ? "JACKPOT!" : "LEVEL PRIZE")
                .font(.system(size: 12 * scale, weight: .black, design: .rounded))
                .foregroundStyle(gold)
            HStack(spacing: 8 * scale) {
                Image(systemName: Self.symbol(face))
                    .font(.system(size: 22 * scale, weight: .heavy))
                    .foregroundStyle(gold)
                Text(Self.words(face))
                    .font(.system(size: 24 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, 20 * scale)
        .frame(width: 236 * scale, height: 74 * scale)
        .background(
            RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)
                .fill(Color(hex: 0x12082E, opacity: 0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)
                .strokeBorder(gold, lineWidth: isStopped ? 3.5 : 2)
        )
        .shadow(color: gold.opacity(isStopped ? 0.9 : 0.45), radius: (isStopped ? 18 : 8) * scale)
        .scaleEffect(isStopped ? 1.12 : 1)
        .opacity(isGone ? 0 : 1)
        .task {
            var wait = 55
            for flick in 0..<15 {
                step = flick
                onTick()
                try? await Task.sleep(for: .milliseconds(wait))
                if Task.isCancelled { return }
                wait += 13
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                isStopped = true
            }
            onStop()
            try? await Task.sleep(for: .milliseconds(1500))
            if Task.isCancelled { return }
            withAnimation(.easeIn(duration: 0.3)) {
                isGone = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Three stars for the game just played: one for level 2, two for level 4, three for
/// level 6. They pop in one after another.
struct StarRow: View {
    let level: Int
    let scale: CGFloat

    @State private var shown = 0

    static func stars(forLevel level: Int) -> Int {
        level >= 6 ? 3 : (level >= 4 ? 2 : (level >= 2 ? 1 : 0))
    }

    var body: some View {
        let won = Self.stars(forLevel: level)

        HStack(spacing: 6 * scale) {
            ForEach(0..<3, id: \.self) { index in
                let isWon = index < won
                Image(systemName: "star.fill")
                    .font(.system(size: (index == 1 ? 40 : 32) * scale, weight: .black))
                    .foregroundStyle(isWon ? Color(hex: 0xFFD23F) : Color.white.opacity(0.16))
                    .shadow(color: isWon ? Color(hex: 0xFFB02E) : Color.clear, radius: 8 * scale)
                    .scaleEffect(!isWon || index < shown ? 1 : 0.1)
                    .offset(y: index == 1 ? -6 * scale : 0)
            }
        }
        .task {
            for index in 0..<won {
                try? await Task.sleep(for: .milliseconds(260))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    shown = index + 1
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(won == 1 ? "1 star" : "\(won) stars"))
    }
}

/// A wall or a crate standing on the board, drawn as a solid block: a lit top face
/// above a front face of bricks or planks.
struct ObstacleView: View {
    let kind: BlockKind
    let size: CGFloat

    /// A crate rocks gently; a gleam of light crosses a wall.
    @State private var isMoving = false

    var body: some View {
        let block = RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)

        Group {
            if kind == .crate {
                crate
                    .rotationEffect(.degrees(isMoving ? 2.5 : -2.5))
                    .offset(y: isMoving ? -size * 0.015 : size * 0.015)
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: isMoving)
            } else {
                wall
                    .overlay {
                        // A slanted bar of light that slides across, again and again.
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0), Color.white.opacity(0.4), Color.white.opacity(0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: size * 0.3, height: size * 1.6)
                            .rotationEffect(.degrees(22))
                            .offset(x: isMoving ? size * 0.95 : -size * 0.95)
                            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: false), value: isMoving)
                    }
                    .clipShape(block)
            }
        }
        .onAppear {
            isMoving = true
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.55), radius: size * 0.08, x: 0, y: size * 0.06)
        .accessibilityElement()
        .accessibilityLabel(Text(kind == .crate ? "crate" : "wall"))
    }

    /// One brick.
    private func brick(_ width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.02, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0xD0694A), Color(hex: 0x9A3F2A)], startPoint: .top, endPoint: .bottom))
            .frame(width: width, height: size * 0.17)
    }

    /// A brick wall: a paler top, then three courses of bricks, the middle one offset.
    private var wall: some View {
        let block = RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
        let mortar = size * 0.03
        let inner = size * 0.88
        let half = (inner - mortar) / 2
        let quarter = (inner - 2 * mortar) / 4

        return ZStack(alignment: .top) {
            // The mortar shows between the bricks.
            block.fill(Color(hex: 0x4A2218))
            VStack(spacing: mortar) {
                // The top of the wall, catching the light.
                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xF2A882), Color(hex: 0xD98060)], startPoint: .top, endPoint: .bottom))
                    .frame(width: inner, height: size * 0.2)
                HStack(spacing: mortar) {
                    brick(half)
                    brick(half)
                }
                HStack(spacing: mortar) {
                    brick(quarter)
                    brick(quarter * 2)
                    brick(quarter)
                }
                HStack(spacing: mortar) {
                    brick(half)
                    brick(half)
                }
            }
            .padding(.top, size * 0.05)
            block.strokeBorder(Color(hex: 0x2A120C), lineWidth: max(1.5, size * 0.03))
        }
        .clipShape(block)
    }

    /// A wooden crate: a paler lid, then a framed front with two crossed braces.
    private var crate: some View {
        let block = RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
        let plank = max(2, size * 0.09)
        let dark = Color(hex: 0x5A3214)
        let brace = StrokeStyle(lineWidth: plank, lineCap: .butt)

        return ZStack(alignment: .top) {
            block.fill(dark)
            VStack(spacing: size * 0.03) {
                // The lid.
                RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xF7D08A), Color(hex: 0xE0A858)], startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.9, height: size * 0.19)
                // The front.
                ZStack {
                    Rectangle()
                        .fill(LinearGradient(colors: [Color(hex: 0xD99A4E), Color(hex: 0xA86A2A)], startPoint: .top, endPoint: .bottom))
                    Outline(points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)], isClosed: false)
                        .stroke(Color(hex: 0x8A521E), style: brace)
                    Outline(points: [CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1)], isClosed: false)
                        .stroke(Color(hex: 0x8A521E), style: brace)
                    Rectangle()
                        .strokeBorder(Color(hex: 0xC08040), lineWidth: plank)
                    // A nail in each corner.
                    ForEach(0..<4, id: \.self) { corner in
                        Circle()
                            .fill(Color(hex: 0x3A2010))
                            .frame(width: size * 0.045, height: size * 0.045)
                            .position(
                                x: corner % 2 == 0 ? plank / 2 : size * 0.9 - plank / 2,
                                y: corner < 2 ? plank / 2 : size * 0.66 - plank / 2
                            )
                    }
                }
                .frame(width: size * 0.9, height: size * 0.66)
                .clipped()
            }
            .padding(.top, size * 0.04)
            block.strokeBorder(Color(hex: 0x2E1808), lineWidth: max(1.5, size * 0.03))
        }
        .clipShape(block)
    }
}

/// A hole in the board: a dark pit with a lit rim, rings that sink into it and
/// specks that spiral down it and vanish.
struct PitView: View {
    let size: CGFloat

    @State private var isFalling = false

    var body: some View {
        let mouth = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)

        ZStack {
            // The pit: lighter walls near the rim, black at the bottom.
            mouth.fill(
                RadialGradient(
                    colors: [Color.black, Color.black, Color(hex: 0x1B1338), Color(hex: 0x3A2E6A)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.62
                )
            )
            // Rings sinking down it.
            ForEach(0..<2, id: \.self) { ring in
                mouth
                    .strokeBorder(Color(hex: 0x8C7BFF, opacity: 0.55), lineWidth: max(1, size * 0.025))
                    .scaleEffect(isFalling ? 0.08 : (ring == 0 ? 0.92 : 0.55))
                    .opacity(isFalling ? 0 : 0.7)
            }
            // Specks spiralling in.
            ForEach(0..<5, id: \.self) { speck in
                Circle()
                    .fill(speck % 2 == 0 ? Color.white : Color(hex: 0x8FF0FF))
                    .frame(width: size * 0.07, height: size * 0.07)
                    .scaleEffect(isFalling ? 0.1 : 1)
                    .offset(x: isFalling ? 0 : size * 0.36)
                    .rotationEffect(.degrees(Double(speck) * 72 + (isFalling ? 320 : 0)))
                    .opacity(isFalling ? 0 : 0.9)
            }
            // The rim: dark along the top inside edge, lit along the bottom.
            mouth.strokeBorder(
                LinearGradient(colors: [Color.black.opacity(0.9), Color.white.opacity(0.45)], startPoint: .top, endPoint: .bottom),
                lineWidth: max(2, size * 0.05)
            )
        }
        .frame(width: size, height: size)
        .clipShape(mouth)
        .onAppear {
            withAnimation(.easeIn(duration: 1.7).repeatForever(autoreverses: false)) {
                isFalling = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("hole"))
    }
}

/// The end-of-game card's decoration: the theme's word sprayed at a slant across the
/// top, and its sparks scattered round the edge like stickers.
struct Graffiti: View {
    let word: String
    let symbol: String
    let side: CGFloat

    @State private var isSprayed = false

    /// Where each spark goes (as fractions of the card), how big and how far turned.
    private static let marks: [(x: CGFloat, y: CGFloat, size: CGFloat, turn: Double)] = [
        (0.08, 0.10, 0.09, -20), (0.92, 0.09, 0.07, 25), (0.06, 0.52, 0.06, 15),
        (0.94, 0.48, 0.08, -15), (0.10, 0.90, 0.08, 30), (0.90, 0.91, 0.10, -25),
        (0.30, 0.95, 0.05, 10), (0.70, 0.05, 0.05, -10),
    ]
    private static let colors: [Color] = [
        Color(hex: 0xFF8AD8), Color(hex: 0xFFE26A), Color(hex: 0x86F2BC), Color(hex: 0x8FF0FF), Color(hex: 0xFF9F2E),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<Self.marks.count, id: \.self) { index in
                let mark = Self.marks[index]
                Image(systemName: symbol)
                    .font(.system(size: side * mark.size, weight: .black))
                    .foregroundStyle(Self.colors[index % Self.colors.count].opacity(0.6))
                    .rotationEffect(.degrees(mark.turn))
                    .scaleEffect(isSprayed ? 1 : 0.2)
                    .position(x: side * mark.x, y: side * mark.y)
            }

            if !word.isEmpty {
                Text(word.uppercased())
                    .font(.system(size: side * 0.1, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: 0xFFE26A), Color(hex: 0xFF7AD9)], startPoint: .leading, endPoint: .trailing)
                    )
                    // A hard offset shadow, like the outline of spray-can lettering.
                    .shadow(color: Color(hex: 0x3A0A5A), radius: 0, x: side * 0.008, y: side * 0.008)
                    .shadow(color: Color(hex: 0xFF7AD9, opacity: 0.8), radius: side * 0.03)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: side * 0.86)
                    .rotationEffect(.degrees(-7))
                    .scaleEffect(isSprayed ? 1 : 1.6)
                    .opacity(isSprayed ? 1 : 0)
                    .position(x: side * 0.5, y: side * 0.1)
            }
        }
        .frame(width: side, height: side)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.15)) {
                isSprayed = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The speed bonus going up: lightning strikes down the left edge of the board and
/// speed lines streak across its top edge. Over in half a second, and clear of the tiles.
struct SpeedBolt: View {
    let side: CGFloat

    @State private var isGone = false

    private static let bolt: [CGPoint] = [
        CGPoint(x: 0.55, y: 0), CGPoint(x: 0.1, y: 0.55), CGPoint(x: 0.45, y: 0.55), CGPoint(x: 0.3, y: 1),
        CGPoint(x: 0.9, y: 0.4), CGPoint(x: 0.55, y: 0.4), CGPoint(x: 0.8, y: 0),
    ]

    var body: some View {
        ZStack {
            Outline(points: Self.bolt)
                .fill(LinearGradient(colors: [Color.white, Color(hex: 0xFFE26A), Color(hex: 0xFF9F2E)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(hex: 0xFFE26A), radius: side * 0.04)
                .frame(width: side * 0.15, height: side * 0.56)
                .scaleEffect(isGone ? 1.15 : 0.9)
                .position(x: -side * 0.035, y: side * 0.3)

            ForEach(0..<5, id: \.self) { line in
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: side * (0.16 + 0.06 * CGFloat(line)), height: 3)
                    .position(x: isGone ? side * 1.25 : -side * 0.25, y: -side * 0.012 - CGFloat(line) * 5)
            }
        }
        .frame(width: side, height: side)
        .opacity(isGone ? 0 : 1)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isGone = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
