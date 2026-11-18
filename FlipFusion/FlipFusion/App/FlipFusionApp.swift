import SwiftUI

@main
struct FlipFusionApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

/// The game, with the opening animation over it until it finishes or is tapped away.
struct RootView: View {
    @State private var sounds = SoundPlayer()
    @State private var showIntro = true

    var body: some View {
        ZStack {
            GameScreen(
                sounds: sounds,
                isIntroOver: !showIntro,
                onReplayIntro: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showIntro = true
                    }
                }
            )

            if showIntro {
                IntroView(sounds: sounds) {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        showIntro = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}
