import CoreData
import SwiftData
import SwiftUI

struct RootView: View {
    let postureProvider: any PostureProvider

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppLock.self) private var appLock
    @State private var model: AppModel?
    @State private var curtain = LockCurtain()

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
            updateCurtain()
            if scenePhase == .active { await appLock.promptIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model?.flushAll() }
            switch phase {
            case .background: appLock.didEnterBackground()
            case .active: appLock.didBecomeActive()
            default: break
            }
            updateCurtain()
            if phase == .active {
                Task { await appLock.promptIfNeeded() }
            }
        }
        .onChange(of: appLock.isLocked) { updateCurtain() }
        .onChange(of: appLock.isEnabled) { updateCurtain() }
        // No closure before `receive(on:)`: in a view it would be main-actor and trap on the store's queue.
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            model?.adoptSyncedChanges()
        }
        .onOpenURL { url in
            model?.handle(url: url)
        }
    }

    /// With the lock on, the cover hides the notebook whenever the app isn't in front (so the
    /// app switcher shows only the cover) and stays up until Face ID unlocks it.
    private func updateCurtain() {
        let showsCover = appLock.isEnabled && (appLock.isLocked || scenePhase != .active)
        guard showsCover else {
            curtain.hide()
            return
        }
        let notebook = model?.currentNotebook
        curtain.show(lock: appLock, cover: LockCover(
            title: notebook?.title ?? "Field Notes",
            theme: notebook?.theme ?? .journal,
            seed: notebook?.id.uuidString ?? "cover",
            number: model?.notebookNumber ?? 1
        ))
    }
}
