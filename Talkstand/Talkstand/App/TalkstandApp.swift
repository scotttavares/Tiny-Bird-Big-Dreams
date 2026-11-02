import SwiftUI

@main
struct TalkstandApp: App {
    @State private var store = ScriptStore()

    var body: some Scene {
        WindowGroup {
            ScriptListView()
                .environment(store)
        }
    }
}
