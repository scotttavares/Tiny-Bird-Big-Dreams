import SwiftUI

/// The one screen of the game, laid out to match the mockup:
/// logo, score cards, rotation pill, board with its arrow, tagline, page dots.
struct GameScreen: View {
    @State private var store = GameStore()
    @State private var sounds = SoundPlayer()
    @Environment(\.scenePhase) private var scenePhase
    @State private var toast: String?
    @State private var toastID = 0
    @State private var confirmNewGame = false

    var body: some View {
        GeometryReader { geo in
            // The mockup is drawn on a 393-point-wide phone; everything scales from that.
            let scale = min(geo.size.width / 393, geo.size.height / 720)
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

                ScoreCards(score: store.state.score, best: store.best, scale: scale)
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
                    .padding(.top, 14 * scale)

                RotatePill(moves: store.state.movesUntilRotation, scale: scale)
                    .padding(.top, 22 * scale)

                ZStack {
                    BoardView(store: store, side: side)

                    RotationArrow(
                        side: side,
                        isImminent: store.state.movesUntilRotation == 1 && !store.isGameOver
                    )

                    if let toast {
                        ToastView(text: toast, scale: scale)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }

                    if store.isGameOver {
                        GameOverOverlay(
                            title: store.isTimeUp ? "Time's Up" : "Game Over",
                            score: store.state.score,
                            isBest: store.state.score > 0 && store.state.score >= store.best,
                            side: side,
                            scale: scale
                        ) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.newGame()
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(width: side, height: side)
                .padding(.top, 14 * scale)

                Text("Swipe. Merge. Rotate.")
                    .font(.system(size: 21 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.tagline)
                    .padding(.top, 46 * scale)

                PageDots(scale: scale) {
                    show("More themes coming soon")
                }
                .padding(.top, 30 * scale)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(BackgroundView().ignoresSafeArea())
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
        .animation(.easeOut(duration: 0.25), value: store.isGameOver)
        .sensoryFeedback(.impact(weight: .light), trigger: store.mergePulse)
        .sensoryFeedback(.impact(weight: .heavy), trigger: store.rotatePulse)
        .onChange(of: store.comboEvent) { _, _ in
            show("Chain x\(store.lastCombo)!")
        }
        .modifier(GameSounds(store: store, sounds: sounds))
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.pauseTimer()
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
                try await Task.sleep(for: .milliseconds(1100))
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

    private func show(_ message: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            toast = message
        }
        toastID += 1
    }
}

/// Deep navy backdrop with a soft blue glow behind the board.
struct BackgroundView: View {
    var body: some View {
        ZStack {
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
    }
}

/// The three dots under the tagline. The first is the Neon theme in use; the others
/// are places for themes still to come.
struct PageDots: View {
    let scale: CGFloat
    let onLockedTap: () -> Void

    var body: some View {
        HStack(spacing: 12 * scale) {
            Circle()
                .fill(Theme.dotOn)
                .frame(width: 9 * scale, height: 9 * scale)
                .shadow(color: Theme.dotOn.opacity(0.8), radius: 4 * scale)
                .accessibilityLabel(Text("Neon theme, selected"))

            ForEach(0..<2, id: \.self) { _ in
                Button(action: onLockedTap) {
                    Circle()
                        .fill(Theme.dotOff)
                        .frame(width: 9 * scale, height: 9 * scale)
                        // A fingertip-sized tap area around the small dot.
                        .padding(.vertical, 14 * scale)
                        .padding(.horizontal, 2 * scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("More themes coming soon"))
            }
        }
        .frame(height: 9 * scale)
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
            .padding(.horizontal, 20 * scale)
            .padding(.vertical, 11 * scale)
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
    let isBest: Bool
    let side: CGFloat
    let scale: CGFloat
    let onPlayAgain: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.07, style: .continuous)
                .fill(Color(hex: 0x070A26, opacity: 0.86))

            VStack(spacing: 10 * scale) {
                Text(title)
                    .font(.system(size: 34 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing)
                    )
                Text(isBest ? "New best: \(score)" : "Score: \(score)")
                    .font(.system(size: 20 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(isBest ? Theme.counter : Theme.tagline)

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
                .buttonStyle(.plain)
                .padding(.top, 10 * scale)
            }
        }
        .frame(width: side, height: side)
    }
}
