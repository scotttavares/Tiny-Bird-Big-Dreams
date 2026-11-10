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
        let schema = Schema(FieldGuideSchema.models)
        // `.automatic` syncs through the iCloud container in the app's entitlements.
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .automatic)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // A notebook that won't sync is better than an app that won't open.
            let local = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
            do {
                container = try ModelContainer(for: schema, configurations: local)
            } catch {
                fatalError("Could not open the Field Guide store: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(postureProvider: postureProvider)
        }
        .modelContainer(container)
    }
}
