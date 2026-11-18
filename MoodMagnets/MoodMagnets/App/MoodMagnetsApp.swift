import SwiftUI

@main
struct MoodMagnetsApp: App {
    @State private var postureProvider = SystemPostureProvider()
    @StateObject private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {
            RootView(postureProvider: postureProvider)
                .environmentObject(progress)
                .preferredColorScheme(.light)
        }
    }
}
