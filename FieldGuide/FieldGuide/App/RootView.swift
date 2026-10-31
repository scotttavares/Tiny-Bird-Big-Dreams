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
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).map { _ in }.receive(on: RunLoop.main)) {
            model?.adoptSyncedChanges()
        }
        .onOpenURL { url in
            model?.handle(url: url)
        }
    }
}
