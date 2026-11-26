import LocalAuthentication
import SwiftUI
import UIKit

/// How long Field Guide can sit in the background before it asks for Face ID again.
enum LockDelay: Int, CaseIterable, Identifiable, Sendable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Self { self }

    var title: String {
        switch self {
        case .immediately: "Immediately"
        case .oneMinute: "After 1 Minute"
        case .fiveMinutes: "After 5 Minutes"
        }
    }
}

/// The optional Face ID lock. Off by default; when it's on, the app opens behind a cover and
/// asks for Face ID (or Touch ID, falling back to the device passcode) before showing any page.
@MainActor
@Observable
final class AppLock {
    static let enabledKey = "appLockEnabled"
    static let delayKey = "appLockDelay"

    private let defaults: UserDefaults

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    var delay: LockDelay {
        didSet { defaults.set(delay.rawValue, forKey: Self.delayKey) }
    }

    /// True while the notebook is locked and waiting for Face ID.
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    private var backgroundedAt: Date?
    /// Set when the app locks on launch or on coming back, so Face ID is asked for once, not again
    /// each time the system prompt itself makes the app inactive and active (which would loop on Cancel).
    private var promptPending: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = defaults.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        delay = LockDelay(rawValue: defaults.integer(forKey: Self.delayKey)) ?? .immediately
        isLocked = enabled
        promptPending = enabled
    }

    /// Whether coming back after `backgroundedAt` should lock the app.
    nonisolated static func shouldLock(enabled: Bool, backgroundedAt: Date?, now: Date, delay: LockDelay) -> Bool {
        guard enabled, let backgroundedAt else { return false }
        return now.timeIntervalSince(backgroundedAt) >= TimeInterval(delay.rawValue)
    }

    func didEnterBackground(at date: Date = .now) {
        guard isEnabled, !isLocked else { return }
        backgroundedAt = date
    }

    func didBecomeActive(at date: Date = .now) {
        if Self.shouldLock(enabled: isEnabled, backgroundedAt: backgroundedAt, now: date, delay: delay) {
            isLocked = true
            promptPending = true
        }
        backgroundedAt = nil
    }

    /// Asks for Face ID automatically once after the app locks. Cancelling leaves the Unlock button.
    func promptIfNeeded() async {
        guard promptPending else { return }
        promptPending = false
        await unlock()
    }

    /// Asks for Face ID, falling back to the device passcode. Unlocks on success.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await Self.authenticate(reason: "Unlock your Field Guide notebooks.") {
            isLocked = false
        }
    }

    /// Turns the lock on only after the person proves Face ID works, so they can't lock themselves out.
    /// Returns false when the device has no passcode or the check was cancelled.
    func enable() async -> Bool {
        guard Self.isAvailable else { return false }
        guard await Self.authenticate(reason: "Turn on the Face ID lock for Field Guide.") else { return false }
        isEnabled = true
        return true
    }

    func disable() {
        isEnabled = false
        isLocked = false
        promptPending = false
        backgroundedAt = nil
    }

    // MARK: Device

    /// False when the device has no passcode set, so there's nothing to unlock with.
    static var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// "Face ID", "Touch ID", "Optic ID" or "Passcode", for labels.
    static var methodName: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    static var methodSymbol: String {
        switch methodName {
        case "Face ID": "faceid"
        case "Touch ID": "touchid"
        case "Optic ID": "opticid"
        default: "lock"
        }
    }

    private static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Not Now"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

/// Puts the lock screen in its own window above everything, sheets and full-screen camera included,
/// so nothing from a notebook shows in the app switcher or behind the lock.
@MainActor
final class LockCurtain {
    private var window: UIWindow?

    func show(lock: AppLock, cover: LockCover) {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState != .unattached }) else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        let host = UIHostingController(rootView: LockScreen(lock: lock, cover: cover))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    func hide() {
        window?.isHidden = true
        window = nil
    }
}

/// What the lock screen draws: the current notebook's cover, without any page content.
struct LockCover: Sendable {
    var title: String
    var theme: NotebookTheme
    var seed: String
    var number: Int
}

/// The notebook's cover with a lock on it. RootView asks for Face ID as soon as the app is in front.
struct LockScreen: View {
    let lock: AppLock
    let cover: LockCover

    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 50

    var body: some View {
        ZStack {
            Theme.chrome.ignoresSafeArea()
            NotebookCoverArt(title: cover.title, theme: cover.theme, seed: cover.seed, number: cover.number)
                .clipShape(.rect(cornerRadius: 18))
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .accessibilityHidden(true)
            VStack(spacing: 14) {
                Spacer()
                if lock.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(.black.opacity(0.35), in: .circle)
                        .accessibilityHidden(true)
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Label("Unlock with \(AppLock.methodName)", systemImage: AppLock.methodSymbol)
                            .font(.headline)
                            .padding(.horizontal, 22)
                            .frame(minHeight: buttonHeight)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(lock.isAuthenticating)
                }
                Spacer().frame(height: 70)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Field Guide is locked")
    }
}

/// Settings for the lock, from the More menu.
struct AppLockSheet: View {
    let lock: AppLock

    @Environment(\.dismiss) private var dismiss
    @State private var isTurningOn = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: Binding {
                        lock.isEnabled
                    } set: { on in
                        if on {
                            isTurningOn = true
                            Task {
                                if !(await lock.enable()) { failed = true }
                                isTurningOn = false
                            }
                        } else {
                            lock.disable()
                        }
                    }) {
                        Label("Lock with \(AppLock.methodName)", systemImage: AppLock.methodSymbol)
                    }
                    .disabled(isTurningOn)
                } footer: {
                    Text("Field Guide opens behind your notebook's cover until you unlock it. If \(AppLock.methodName) doesn't work, you can use your passcode.")
                }
                if lock.isEnabled {
                    Section("Require \(AppLock.methodName)") {
                        Picker("Require", selection: Binding { lock.delay } set: { lock.delay = $0 }) {
                            ForEach(LockDelay.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.chrome)
            .navigationTitle("Privacy Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Couldn't Turn On the Lock", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(AppLock.isAvailable
                     ? "\(AppLock.methodName) didn't confirm it's you, so the lock is still off."
                     : "Set a passcode for this device in Settings first, then try again.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}
