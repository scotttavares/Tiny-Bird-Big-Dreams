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
                VStack(spacing: 8) {
                    CanvasView(store: model.canvas)
                    ToolStrip(store: model.canvas, style: .compact)
                        .padding(.horizontal)
                }
                .background(Theme.chrome)
            } else {
                Theme.paper
            }
        }
        .readsPosture(into: postureProvider)
        .task {
            guard model == nil else { return }
            let appModel = AppModel(context: modelContext)
            appModel.bootstrap(seedDemo: ProcessInfo.processInfo.arguments.contains("-FGSeedDemo"))
            model = appModel
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model?.flushAll() }
        }
        .onOpenURL { url in
            model?.handle(url: url)
        }
    }
}
