import SwiftUI

/// The opening animation, shown each time the app starts: four tiles drop in, the
/// cluster makes the game's quarter turn, the tiles fuse in a burst and the logo
/// appears. A tap skips it. It always plays in the original Neon look, whatever
/// theme is in use.
struct IntroView: View {
    let sounds: SoundPlayer
    let onFinish: () -> Void

    @State private var dropped = 0
    @State private var turn: Double = 0
    @State private var isFused = false
    @State private var showLogo = false
    @State private var showTagline = false
    @State private var isDone = false

    private let values = [2, 4, 8, 16]
    private let notes: [SoundPlayer.Sound] = [.merge1, .merge2, .merge3, .merge4]
    /// The original look.
    private let neon = Skin.all[0]

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 393, geo.size.height / 720)
            let tile = 84 * scale
            let step = tile + 10 * scale

            ZStack {
                // The original backdrop, written out here so no theme recolours it.
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: 0x0D1445), Color(hex: 0x070A26)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    RadialGradient(
                        colors: [Color(hex: 0x1D2F8F, opacity: 0.55), Color(hex: 0x1D2F8F, opacity: 0)],
                        center: UnitPoint(x: 0.5, y: 0.5),
                        startRadius: 10,
                        endRadius: 380
                    )
                }
                .ignoresSafeArea()

                // The four tiles, as a 2×2 cluster that turns as one.
                ZStack {
                    ForEach(0..<4, id: \.self) { index in
                        let home = CGSize(
                            width: (CGFloat(index % 2) - 0.5) * step,
                            height: (CGFloat(index / 2) - 0.5) * step
                        )
                        let hasLanded = index < dropped
                        TileView(value: values[index], size: tile, skin: neon)
                            .rotationEffect(.degrees(-turn))
                            .scaleEffect(isFused ? 0.3 : 1)
                            .opacity(isFused ? 0 : 1)
                            .offset(
                                x: isFused ? 0 : home.width,
                                y: isFused ? 0 : (hasLanded ? home.height : home.height - geo.size.height)
                            )
                    }
                }
                .rotationEffect(.degrees(turn))

                if isFused {
                    MergeBurst(color: Theme.fusion[0], size: tile, isBlast: true, spark: "circle.fill", shape: .rounded, flair: false)
                }

                VStack(spacing: 18 * scale) {
                    LogoView(scale: scale * 1.08)
                        .scaleEffect(showLogo ? 1 : 0.3)
                        .opacity(showLogo ? 1 : 0)
                    Text("Swipe. Merge. Rotate.")
                        .font(.system(size: 21 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.tagline)
                        .opacity(showTagline ? 1 : 0)
                        .offset(y: showTagline ? 0 : 10 * scale)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            finish()
        }
        .task {
            try? await play()
            finish()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Flip Fusion. Swipe, merge, rotate."))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Starts the game"))
    }

    /// Runs the animation. Throws (and so stops at once) if the intro is skipped.
    private func play() async throws {
        try await Task.sleep(for: .milliseconds(250))
        for index in 0..<4 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                dropped = index + 1
            }
            sounds.play(notes[index], volume: 0.8)
            try await Task.sleep(for: .milliseconds(170))
        }
        try await Task.sleep(for: .milliseconds(280))

        sounds.play(.rotate, volume: 0.8)
        withAnimation(.easeInOut(duration: 0.5)) {
            turn = 90
        }
        try await Task.sleep(for: .milliseconds(620))

        sounds.play(.fever, volume: 0.9)
        withAnimation(.easeIn(duration: 0.2)) {
            isFused = true
        }
        try await Task.sleep(for: .milliseconds(220))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            showLogo = true
        }
        try await Task.sleep(for: .milliseconds(350))
        withAnimation(.easeOut(duration: 0.3)) {
            showTagline = true
        }
        try await Task.sleep(for: .milliseconds(1100))
    }

    private func finish() {
        guard !isDone else { return }
        isDone = true
        onFinish()
    }
}
