import CoreData
import SwiftData
import SwiftUI

struct RootView: View {
    let postureProvider: any PostureProvider

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AppModel?

    var body: some View {
        Group {
            if let model {
                WorkspaceView(model: model, postureProvider: postureProvider)
            } else {
                Theme.chrome.ignoresSafeArea()
            }
        }
        .task {
            guard model == nil else { return }
            let appModel = AppModel(context: modelContext)
            appModel.bootstrap(seedDemo: ProcessInfo.processInfo.arguments.contains("-FGSeedDemo"))
            model = appModel
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model?.flushAll() }
        }
        // No closure before `receive(on:)`: in a view it would be main-actor and trap on the store's queue.
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            model?.adoptSyncedChanges()
        }
        .onOpenURL { url in
            model?.handle(url: url)
        }
    }
}
