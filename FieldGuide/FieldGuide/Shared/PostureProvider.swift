import Observation
import SwiftUI

/// The single seam between the device's fold state and Field Guide's layouts.
///
/// Views never look at hinge APIs directly; they read `posture` and `hingeRect` from a
/// provider. The default implementation derives posture from the iPhone Duo hinge and
/// reserved-region APIs when the SDK has them, and from window size otherwise. A test or
/// a future API can swap in a different implementation.
@MainActor
protocol PostureProvider: AnyObject, Observable {
    /// The posture layouts should use right now.
    var posture: Posture { get }
    /// The area to keep clear between the pages, in workspace coordinates (`.null` when single-page).
    var hingeRect: CGRect { get }
    /// The latest raw inputs, for diagnostics.
    var inputs: PostureInputs { get }
    /// A forced posture (debug menu, launch argument, or the manual "Present" mode).
    var override: Posture? { get set }
    /// Feed new geometry/hinge readings.
    func ingest(_ inputs: PostureInputs)
}

/// Default provider: maps readings through `PostureMapper` and honors an override.
@MainActor
@Observable
final class SystemPostureProvider: PostureProvider {
    static let overrideDefaultsKey = "FGPostureOverride"

    private(set) var posture: Posture = .closed
    private(set) var hingeRect: CGRect = .null
    private(set) var inputs = PostureInputs()

    var override: Posture? {
        didSet { recompute() }
    }

    init(defaults: UserDefaults = .standard) {
        // `-FGPostureOverride book` on the command line lands in the arguments domain.
        if let raw = defaults.string(forKey: Self.overrideDefaultsKey) {
            override = Posture(rawValue: raw)
        }
        recompute()
    }

    func ingest(_ inputs: PostureInputs) {
        guard inputs != self.inputs else { return }
        self.inputs = inputs
        recompute()
    }

    private func recompute() {
        let next = override ?? PostureMapper.posture(for: inputs)
        let rect = PostureMapper.hingeRect(for: next, inputs: inputs)
        if next != posture { posture = next }
        if rect != hingeRect { hingeRect = rect }
    }
}

// MARK: - Reading the device

/// The geometry half of `PostureInputs`, read from a `GeometryProxy`.
struct PostureGeometry: Equatable, Sendable {
    var size: CGSize = .zero
    var activeDivision: CGRect?
    var anyDivision: CGRect?

    init() {}

    init(proxy: GeometryProxy) {
        size = proxy.size
        #if FIELDGUIDE_DUO_SDK
        if #available(iOS 27.1, *) {
            activeDivision = proxy.reservedRegions(kind: .division).first?.frame
            anyDivision = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first?.frame
        }
        #endif
    }
}

/// The hinge half of `PostureInputs`.
struct HingeReading: Equatable, Sendable {
    var status: HingeStatus?
    var angleDegrees: Double?
}

/// Collects geometry and hinge updates for the view it is attached to and pushes them
/// into a `PostureProvider`. Attach it to the same container whose coordinate space the
/// layouts use, so the hinge rect lines up.
struct PostureReader: ViewModifier {
    let provider: any PostureProvider

    @State private var geometry = PostureGeometry()
    @State private var hinge = HingeReading()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: PostureGeometry.self) { proxy in
                PostureGeometry(proxy: proxy)
            } action: { newValue in
                geometry = newValue
                push()
            }
            .modifier(HingeObserver { reading in
                hinge = reading
                push()
            })
    }

    private func push() {
        provider.ingest(PostureInputs(
            hingeStatus: hinge.status,
            hingeAngleDegrees: hinge.angleDegrees,
            activeDivision: geometry.activeDivision,
            anyDivision: geometry.anyDivision,
            containerSize: geometry.size
        ))
    }
}

/// Wraps `onHingeChange` so the rest of the app compiles against SDKs that predate it.
private struct HingeObserver: ViewModifier {
    let onChange: (HingeReading) -> Void

    func body(content: Content) -> some View {
        #if FIELDGUIDE_DUO_SDK
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, newContext in
                onChange(HingeReading(newContext.hinge))
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if FIELDGUIDE_DUO_SDK
@available(iOS 27.1, *)
private extension HingeReading {
    init(_ hinge: DeviceHinge?) {
        guard let hinge else {
            self.init()
            return
        }
        // Compare instead of switching so a future status case doesn't break the build;
        // Apple's guidance is to treat anything unrecognised as fully open.
        let status: HingeStatus
        if hinge.status == .closed {
            status = .closed
        } else if hinge.status == .partiallyOpen {
            status = .partiallyOpen
        } else {
            status = .fullyOpen
        }
        self.init(status: status, angleDegrees: hinge.angle.degrees)
    }
}
#endif

extension View {
    func readsPosture(into provider: any PostureProvider) -> some View {
        modifier(PostureReader(provider: provider))
    }
}
