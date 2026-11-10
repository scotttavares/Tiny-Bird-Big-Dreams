import SwiftUI

@main
struct PaperWarsApp: App {
    @State private var posture = SystemPostureProvider()
    @State private var saves = CloudSaves()
    @State private var store = ArsenalStore()

    var body: some Scene {
        WindowGroup {
            GameScreen(posture: posture, saves: saves, store: store)
        }
    }
}

/// The whole app is the game page. SwiftUI only reads the fold and keeps the saves;
/// the game itself (drawing, sound, rules) is the same HTML that runs on the website.
struct GameScreen: View {
    let posture: SystemPostureProvider
    let saves: CloudSaves
    let store: ArsenalStore

    var body: some View {
        GameWebView(posture: posture.posture, saves: saves, store: store)
            .ignoresSafeArea()
            .background(Color("PaperColor"))
            .readsPosture(into: posture)
            .persistentSystemOverlays(.hidden)
            .statusBarHidden()
    }
}
