import SwiftUI

/// The one screen of the game, laid out to match the mockup:
/// logo, score cards, rotation pill, board with its arrow, boosters, tagline, mode buttons.
struct GameScreen: View {
    let sounds: SoundPlayer
    /// False while the opening animation is still covering the game.
    let isIntroOver: Bool
    let onReplayIntro: () -> Void

    @State private var store = GameStore()
    /// The theme in use. Changing it redraws everything that takes its colours from it.
    @AppStorage(Skin.key) private var skinID = "neon"
    /// The gem shop. Made once the screen is up, so it hears of purchases from launch.
    @State private var shop: GemShop?
    @State private var calloutText: String?
    @State private var calloutID = 0
    @State private var showHelp = false
    /// "How to play" opens by itself the first time the game is seen.
    @AppStorage("ff.seenHelp") private var seenHelp = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var toast: String?
    @State private var toastID = 0
    @State private var toastSeconds = 1.1
    @State private var confirmNewGame = false
    @AppStorage(SoundPlayer.musicKey) private var musicOn = true

    var body: some View {
        GeometryReader { geo in
            // The mockup is drawn on a 393-point-wide phone; everything scales from that.
            let scale = min(geo.size.width / 393, geo.size.height / 760)
            let side = 322 * scale

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LogoView(scale: scale)
                    .contentShape(Rectangle())
                    .onLongPressGesture {
                        confirmNewGame = true
                    }
                    .accessibilityAction(named: Text("New game")) {
                        confirmNewGame = true
                    }

                Text("Swipe. Merge. Rotate.")
                    .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.tagline)
                    .padding(.top, -4 * scale)

                ScoreCards(score: store.state.score, best: store.best, isFever: store.isFever, scale: scale)
                    .frame(width: side)
                    .overlay {
                        TimerRing(store: store, scale: scale)
                    }
                    .overlay(alignment: .topLeading) {
                        if store.gainEvent > 0 {
                            GainPop(amount: store.lastGain, scale: scale)
                                .frame(width: 122 * scale)
                                .id(store.gainEvent)
                        }
                    }
                    .padding(.top, 9 * scale)

                LevelBar(level: store.level, score: store.state.score, scale: scale)
                    .frame(width: side)
                    .padding(.top, 8 * scale)

                RotatePill(moves: store.state.movesUntilRotation, scale: scale)
                    .frame(width: side)
                    .overlay(alignment: .leading) {
                        if store.streak > 0 {
                            StreakChip(multiplier: store.streak + 1, scale: scale)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: store.streak)
                    .padding(.top, 9 * scale)

                ZStack {
                    BoardView(store: store, side: side)

                    if store.isDanger {
                        DangerGlow(side: side)
                    }

                    if store.crateOpenEvent > 0, store.lastCrateFind == .monkey {
                        MonkeyPop(side: side)
                            .id(store.crateOpenEvent)
                    }

                    if store.streak > 0 {
                        SpeedBolt(side: side)
                            .id(store.streak)
                    }

                    if Skin.current.backdrop == .snow {
                        SnowCap(side: side, shakeOff: store.rotatePulse)
                            .offset(y: -side * 0.545 + 2)
                    }

                    RotationArrow(
                        side: side,
                        isImminent: store.state.movesUntilRotation == 1 && !store.isGameOver,
                        isReversed: store.state.counterClockwise
                    )

                    Celebration(store: store, side: side)

                    if let calloutText {
                        Callout(text: calloutText, scale: scale)
                            .offset(y: -side * 0.44)
                            .id(calloutID)
                    }

                    if store.isGameOver {
                        GameOverOverlay(
                            title: store.isTimeUp ? "Time's Up" : "Game Over",
                            score: store.state.score,
                            level: store.level,
                            isBest: store.state.score > 0 && store.state.score >= store.best,
                            continueOffer: continueOffer,
                            side: side,
                            scale: scale,
                            onPlayAgain: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    store.newGame()
                                }
                            },
                            onContinue: {
                                // Not enough gems: the menu has the gem shop.
                                if !store.continueGame() {
                                    openHelp()
                                }
                            },
                            graffiti: Skin.current.overWord,
                            spark: Skin.current.spark
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .frame(width: side, height: side)
                .modifier(Shake(power: store.shakePower, animatableData: CGFloat(store.shakeEvent)))
                .animation(.linear(duration: 0.4), value: store.shakeEvent)
                .padding(.top, 14 * scale)

                BoosterBar(store: store, scale: scale) { booster in
                    store.useBooster(booster)
                }
                .padding(.top, 14 * scale)

                // Under the boosters: the level prize when one is won, otherwise which
                // game this is (a tap opens the menu, where the games are). Nothing
                // here ever covers the board.
                ZStack {
                    Button {
                        openHelp()
                    } label: {
                        HStack(spacing: 6 * scale) {
                            Text(tagline)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12 * scale, weight: .heavy))
                        }
                        .font(.system(size: 17 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.tagline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 16 * scale)
                        .frame(height: 36 * scale)
                        .background(Capsule().fill(Theme.glassFill))
                        .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
                    }
                    .buttonStyle(BounceButtonStyle())
                    .accessibilityHint(Text("Opens the menu"))

                    if store.prizeEvent > 0, !store.isGameOver {
                        PrizeReel(
                            prize: store.lastPrize,
                            scale: scale,
                            onTick: {
                                sounds.play(.tick, volume: 0.45)
                            },
                            onStop: {
                                sounds.play(store.lastPrize == GameStore.jackpot ? .fever : .bonus)
                            }
                        )
                        .scaleEffect(0.84)
                        .id(store.prizeEvent)
                    }
                }
                .frame(width: side, height: 64 * scale)
                .padding(.top, 8 * scale)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(skinID)
        }
        .background(BackgroundView().id(skinID).ignoresSafeArea())
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 16)
                .onEnded { value in
                    let move = value.translation
                    if abs(move.width) > abs(move.height) {
                        store.swipe(move.width > 0 ? .right : .left)
                    } else {
                        store.swipe(move.height > 0 ? .down : .up)
                    }
                }
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: store.isGameOver)
        .modifier(GameHaptics(store: store))
        .modifier(GameBanners(
            store: store,
            show: { message, seconds in
                show(message, seconds: seconds)
            },
            callout: { word in
                calloutText = word
                calloutID += 1
            }
        ))
        .modifier(GameSounds(store: store, sounds: sounds))
        .modifier(ThemeMoments(store: store, sounds: sounds))
        // Messages sit over the title, clear of the board.
        .overlay(alignment: .top) {
            if let toast {
                ToastView(text: toast, scale: 1)
                    .padding(.top, 46)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .onChange(of: track, initial: true) { _, newTrack in
            sounds.setTrack(newTrack)
        }
        .overlay(alignment: .topLeading) {
            CoinCounter(coins: store.coins, gems: store.gems)
                .id(skinID)
                .padding(.leading, 16)
                .padding(.top, 6)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                openHelp()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.tagline)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.glassFill))
                    .overlay(Circle().strokeBorder(Theme.glassStroke, lineWidth: 1))
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BounceButtonStyle())
            .id(skinID)
            .padding(.trailing, 10)
            .accessibilityLabel(Text("Menu"))
        }
        .sheet(isPresented: $showHelp) {
            HelpView(store: store, shop: shop, onReplayIntro: onReplayIntro)
        }
        .onChange(of: isIntroOver, initial: true) { _, isOver in
            if isOver, !seenHelp {
                openHelp()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                sounds.refreshMusic()
            } else {
                store.pauseTimer()
                if phase == .background {
                    sounds.pauseMusic()
                }
            }
        }
        .onChange(of: musicOn) { _, _ in
            sounds.refreshMusic()
        }
        .task {
            if shop == nil {
                shop = GemShop(store: store)
            }
        }
        .task {
            // Runs the game clock from real elapsed time.
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                let now = Date()
                store.tick(min(now.timeIntervalSince(last), 0.5))
                last = now
            }
        }
        .task(id: toastID) {
            guard toast != nil else { return }
            do {
                try await Task.sleep(for: .milliseconds(Int(toastSeconds * 1000)))
            } catch {
                return
            }
            withAnimation(.easeIn(duration: 0.2)) {
                toast = nil
            }
        }
        .confirmationDialog("Start a new game?", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("New Game", role: .destructive) {
                store.newGame()
            }
            Button("Keep Playing", role: .cancel) {}
        }
    }

    private func openHelp() {
        seenHelp = true
        // The clock waits while the rules are open; the next swipe starts it again.
        store.pauseTimer()
        showHelp = true
    }

    /// The tune that fits the moment: the fast one while points count double and in
    /// the last seconds of a timed game, otherwise the tune of the game mode.
    private var track: SoundPlayer.Track {
        let lastSeconds = store.mode == .timed && store.isTimerRunning && store.wholeSecondsLeft <= 20
        if !store.isGameOver, store.isFever || lastSeconds || store.isDanger {
            return .rush
        }
        // Each theme has its own tune.
        return SoundPlayer.Track(rawValue: "music-" + skinID) ?? (store.mode == .timed ? .timed : .endless)
    }

    /// The line under the boosters. In the Shape Shift game it counts down to the
    /// next change of shape.
    private var tagline: String {
        switch store.mode {
        case .timed:
            return "2 Minute Game"
        case .endless:
            return "Endless Game"
        case .shift:
            let moves = max(1, store.state.movesUntilShift)
            return moves == 1 ? "Board changes in 1 move" : "Board changes in \(moves) moves"
        case .twist:
            return store.state.counterClockwise ? "Twist: next turn is left" : "Twist: next turn is right"
        case .fruit:
            return "Fruit Salad"
        case .fusion:
            return "Fusion: a tile changes every move"
        }
    }

    /// What carrying on with the finished game would give, or nil when it cannot be
    /// carried on (it already was, or nothing was scored).
    private var continueOffer: String? {
        guard store.canContinue else { return nil }
        if store.isTimeUp {
            return "+\(Int(GameStore.continueSeconds)) seconds"
        }
        return "Clear \(GameStore.continueClears) tiles"
    }

    /// A tap on one of the two mode buttons under the tagline.
    private func pickMode(_ mode: GameStore.Mode) {
        guard store.isUnlocked(mode) else {
            show("Shape Shift unlocks with your first new theme", seconds: 2.8)
            return
        }
        guard !store.isAnimating, mode != store.mode else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            store.switchMode(mode)
        }
        switch mode {
        case .timed:
            show("Timed: 2 minutes on the clock", seconds: 2.2)
        case .endless:
            show("Endless: play until no moves are left", seconds: 2.6)
        case .shift:
            show("Shape Shift: the board changes every \(GameEngine.movesPerShift) moves", seconds: 3)
        case .twist:
            show("Twist: the board may turn either way", seconds: 3)
        case .fruit:
            show("Fruit Salad: merge two of the same fruit", seconds: 3)
        case .fusion:
            show("Fusion: a tile changes after every move", seconds: 3)
        }
    }

    private func show(_ message: String, seconds: Double = 1.1) {
        toastSeconds = seconds
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            toast = message
        }
        toastID += 1
    }
}

/// Deep navy backdrop with a soft blue glow behind the board.
struct BackgroundView: View {
    var body: some View {
        let skin = Skin.current
        let isPainted = PaintedBackdrop.has(skin)

        ZStack {
            if isPainted {
                // A painted picture of the theme's scene.
                PaintedBackdrop(skin: skin)
            } else {
                LinearGradient(
                    colors: [Theme.backgroundTop, Theme.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [Theme.backgroundGlow.opacity(0.55), Theme.backgroundGlow.opacity(0)],
                    center: UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 10,
                    endRadius: 380
                )
            }
            // Whatever moves in the theme in use.
            SceneView(skin: skin, isPainted: isPainted)
        }
    }
}

/// A short message that floats over the board.
struct ToastView: View {
    let text: String
    let scale: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 20 * scale, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 20 * scale)
            .padding(.vertical, 11 * scale)
            .frame(maxWidth: 300 * scale)
            .background(
                Capsule().fill(
                    LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing)
                )
            )
            .shadow(color: Theme.fusion[0].opacity(0.7), radius: 12 * scale)
            .allowsHitTesting(false)
    }
}

/// Covers the board when time runs out or no move is left.
struct GameOverOverlay: View {
    let title: String
    let score: Int
    /// The level the game reached, which decides the stars.
    let level: Int
    let isBest: Bool
    /// What "Keep going" gives, such as "+30 seconds". nil hides the button.
    let continueOffer: String?
    let side: CGFloat
    let scale: CGFloat
    let onPlayAgain: () -> Void
    let onContinue: () -> Void
    /// The theme's word, sprayed across the top of the card, and its spark.
    var graffiti = ""
    var spark = "sparkle"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.07, style: .continuous)
                .fill(Color(hex: 0x070A26, opacity: 0.86))

            Graffiti(word: graffiti, symbol: spark, side: side)

            VStack(spacing: 7 * scale) {
                StarRow(level: level, scale: scale)

                Text(title)
                    .font(.system(size: 32 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing)
                    )
                Text((isBest ? "New best: \(score)" : "Score: \(score)") + "  ·  Level \(level)")
                    .font(.system(size: 18 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(isBest ? Theme.counter : Theme.tagline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Button(action: onPlayAgain) {
                    Text("Play Again")
                        .font(.system(size: 20 * scale, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 30 * scale)
                        .frame(height: 52 * scale)
                        .background(
                            Capsule().fill(
                                LinearGradient(colors: Theme.flip.reversed(), startPoint: .top, endPoint: .bottom)
                            )
                        )
                        .shadow(color: Theme.flip[1].opacity(0.7), radius: 10 * scale)
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.top, 6 * scale)

                if let continueOffer {
                    Button(action: onContinue) {
                        HStack(spacing: 6 * scale) {
                            Text("Keep going: \(continueOffer)")
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 13 * scale, weight: .bold))
                                .foregroundStyle(Color(hex: 0x8FF0FF))
                            Text("\(GameStore.continueCost)")
                        }
                        .font(.system(size: 15 * scale, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 16 * scale)
                        .frame(height: 40 * scale)
                        .background(
                            Capsule().fill(
                                LinearGradient(colors: [Theme.pillTop, Theme.pillBottom], startPoint: .top, endPoint: .bottom)
                            )
                        )
                        .overlay(Capsule().strokeBorder(Theme.pillStroke, lineWidth: 1.5))
                    }
                    .buttonStyle(BounceButtonStyle())
                    .accessibilityLabel(Text("Keep going, \(continueOffer), for \(GameStore.continueCost) gems"))
                }
            }
            .padding(.horizontal, 12 * scale)
        }
        .frame(width: side, height: side)
    }
}
