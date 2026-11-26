import SwiftUI

@main
struct FlipFusionApp: App {
    /// Change this to start every tester again as a new player, once, the next
    /// time the app opens: stages, coins, gems, themes and the tutorial all go.
    private static let freshStart = "fresh-start-1"

    init() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "reset.done") != Self.freshStart else { return }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("ff.") {
            defaults.removeObject(forKey: key)
        }
        defaults.set(Self.freshStart, forKey: "reset.done")
    }

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
