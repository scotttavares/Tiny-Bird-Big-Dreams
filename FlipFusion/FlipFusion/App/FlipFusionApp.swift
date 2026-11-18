import SwiftUI

@main
struct FlipFusionApp: App {
    var body: some Scene {
        WindowGroup {
            GameScreen()
                .preferredColorScheme(.dark)
        }
    }
}
