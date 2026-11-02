import SwiftUI
import UIKit

@main
struct GameHostApp: App {
    @State private var postureProvider = SystemPostureProvider()
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store, postureProvider: postureProvider)
        }
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("GameHostDeviceDidShake")
}

extension UIWindow {
    /// SwiftUI has no shake gesture; the window sees every shake and passes it on.
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}
