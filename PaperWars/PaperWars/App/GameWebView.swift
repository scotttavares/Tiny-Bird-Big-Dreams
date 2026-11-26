import SwiftUI
import WebKit

/// Hosts the bundled game page (`game.html`) and bridges it to the app:
/// - the page's saved values (keys starting with `paperWars`) go to `CloudSaves`, and come back
///   before the page starts, so settings, inks, stats and medals follow the player's iCloud;
/// - the fold posture is pushed in, so the page can split into two halves when the Duo is a tent;
/// - the Full Arsenal purchase: the page asks to buy, restore or check it, and is told the result;
/// - Game Center for two-phone multiplayer: the page's `{type: "gc"}` requests go to `GameCenter`, its events come back.
struct GameWebView: UIViewRepresentable {
    let posture: Posture
    let saves: CloudSaves
    let store: ArsenalStore
    let gameCenter: GameCenter

    func makeCoordinator() -> Coordinator {
        Coordinator(saves: saves, store: store, gameCenter: gameCenter)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let content = WKUserContentController()
        content.addUserScript(WKUserScript(
            source: GameBridge.startScript(saved: saves.values, posture: posture),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        content.add(context.coordinator, name: GameBridge.handlerName)
        config.userContentController = content

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        web.isInspectable = true
        #endif
        if let url = Bundle.main.url(forResource: "game", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        context.coordinator.webView = web
        context.coordinator.lastPosture = posture
        saves.onExternalChange = { [weak coordinator = context.coordinator] key, value in
            coordinator?.run(GameBridge.storedScript(key: key, value: value))
        }
        store.onChange = { [weak coordinator = context.coordinator] owned, price in
            coordinator?.run(GameBridge.arsenalScript(owned: owned, price: price))
        }
        store.onFailure = { [weak coordinator = context.coordinator] message in
            coordinator?.run(GameBridge.arsenalFailedScript(message))
        }
        gameCenter.onEvent = { [weak coordinator = context.coordinator] script in
            coordinator?.run(script)
        }
        gameCenter.presenter = { [weak coordinator = context.coordinator] in
            coordinator?.topController()
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.send(posture: posture)
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: GameBridge.handlerName)
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        let saves: CloudSaves
        let store: ArsenalStore
        let gameCenter: GameCenter
        weak var webView: WKWebView?
        var lastPosture: Posture?

        init(saves: CloudSaves, store: ArsenalStore, gameCenter: GameCenter) {
            self.saves = saves
            self.store = store
            self.gameCenter = gameCenter
        }

        /// The view controller on top, to present the share sheet and Game Center's screens over.
        func topController() -> UIViewController? {
            guard var top = webView?.window?.rootViewController else { return nil }
            while let shown = top.presentedViewController { top = shown }
            return top
        }

        func send(posture: Posture) {
            guard posture != lastPosture else { return }
            lastPosture = posture
            run(GameBridge.postureScript(posture))
        }

        func run(_ script: String) {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            if let op = GameBridge.GameCenterOp(message.body) {
                gameCenter.handle(op)
                return
            }
            if let video = GameBridge.VideoShare(message.body) {
                share(video)
                return
            }
            if let request = GameBridge.StoreRequest(message.body) {
                let store = self.store
                Task {
                    switch request {
                    case .buy: await store.buy()
                    case .restore: await store.restore()
                    case .status: await store.refresh()
                    }
                }
                return
            }
            guard let save = GameBridge.Save(message.body) else { return }
            saves.set(save.value, forKey: save.key)
        }

        /// Writes the replay video to a temporary file and opens the share sheet, where the player chooses
        /// Save Video (Photos), Save to Files (any folder), Messages and so on.
        func share(_ video: GameBridge.VideoShare) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(video.name)
            do { try video.data.write(to: url, options: .atomic) } catch {
                run(GameBridge.videoSharedScript(saved: false))
                return
            }
            guard let web = webView, let top = topController() else { return }
            let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = web // iPad shows it as a popover
            sheet.popoverPresentationController?.sourceRect = CGRect(x: web.bounds.midX, y: web.bounds.maxY - 80, width: 1, height: 1)
            sheet.completionWithItemsHandler = { [weak self] _, completed, _, _ in
                Task { @MainActor in
                    try? FileManager.default.removeItem(at: url)
                    self?.run(GameBridge.videoSharedScript(saved: completed))
                }
            }
            top.present(sheet, animated: true)
        }
    }
}
