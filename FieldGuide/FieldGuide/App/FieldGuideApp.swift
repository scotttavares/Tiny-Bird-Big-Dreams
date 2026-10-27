import SwiftData
import SwiftUI

@main
struct FieldGuideApp: App {
    @State private var postureProvider = SystemPostureProvider()
    private let container: ModelContainer

    init() {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-FGInMemoryStore")
        // SwiftData's default store lives in Application Support, which doesn't exist on first launch.
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: Schema(FieldGuideSchema.models), configurations: configuration)
        } catch {
            fatalError("Could not open the Field Guide store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(postureProvider: postureProvider)
        }
        .modelContainer(container)
    }
}
