import SwiftUI
import WebKit

/// Hosts the bundled game page (`game.html`) and bridges it to the app:
/// - the page's saved values (keys starting with `paperWars`) go to `CloudSaves`, and come back
///   before the page starts, so settings, inks, stats and medals follow the player's iCloud;
/// - the fold posture is pushed in, so the page can split into two halves when the Duo is a tent.
struct GameWebView: UIViewRepresentable {
    let posture: Posture
    let saves: CloudSaves

    func makeCoordinator() -> Coordinator {
        Coordinator(saves: saves)
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
        weak var webView: WKWebView?
        var lastPosture: Posture?

        init(saves: CloudSaves) {
            self.saves = saves
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
            guard let save = GameBridge.Save(message.body) else { return }
            saves.set(save.value, forKey: save.key)
        }
    }
}
