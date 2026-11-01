import CoreGraphics
import Foundation

/// How the device is being held, as far as Field Guide's layout is concerned.
enum Posture: String, CaseIterable, Identifiable, Sendable {
    /// Folded shut; the app runs on the outer (cover) display. Quick-capture notebook.
    case closed
    /// Open with a vertical fold: a two-page spread split at the hinge.
    case book
    /// Open with a horizontal fold: reference on the top half, canvas and tools on the bottom.
    case laptop
    /// Propped up to show a finished page, read-only.
    case tent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .closed: "Closed"
        case .book: "Book"
        case .laptop: "Laptop"
        case .tent: "Tent"
        }
    }

    var symbol: String {
        switch self {
        case .closed: "iphone"
        case .book: "book"
        case .laptop: "laptopcomputer"
        case .tent: "triangle"
        }
    }
}

/// The hinge state reported by the system, mirrored into a type we own so that the
/// mapping logic stays testable and compiles against SDKs without the hinge API.
enum HingeStatus: Equatable, Sendable {
    case closed
    case partiallyOpen
    case fullyOpen
}

/// Everything the posture mapping looks at. Built from SwiftUI geometry and hinge updates.
struct PostureInputs: Equatable, Sendable {
    /// `nil` when the device has no hinge (every non-Duo device, the simulator by default).
    var hingeStatus: HingeStatus?
    var hingeAngleDegrees: Double?
    /// The fold's `.division` reserved region while it is active (device partially folded).
    var activeDivision: CGRect?
    /// The fold's `.division` region including inactive regions, so the split is known
    /// even when the device lies flat.
    var anyDivision: CGRect?
    /// The size of the workspace container.
    var containerSize: CGSize

    init(
        hingeStatus: HingeStatus? = nil,
        hingeAngleDegrees: Double? = nil,
        activeDivision: CGRect? = nil,
        anyDivision: CGRect? = nil,
        containerSize: CGSize = .zero
    ) {
        self.hingeStatus = hingeStatus
        self.hingeAngleDegrees = hingeAngleDegrees
        self.activeDivision = activeDivision
        self.anyDivision = anyDivision
        self.containerSize = containerSize
    }
}

/// Pure mapping from inputs to a posture. All thresholds are assumptions; see NOTES.md.
enum PostureMapper {
    /// Below this width a container is treated as a single page (outer display, iPhone portrait).
    static let minimumSpreadWidth: CGFloat = 600
    /// A horizontal fold opened less than this is treated as a tent rather than a laptop.
    static let tentMaximumAngle: Double = 100

    static func posture(for inputs: PostureInputs) -> Posture {
        // 1. An active division region is the authoritative signal that the device is
        //    partially folded. Its orientation tells book from laptop.
        if let fold = inputs.activeDivision {
            if isHorizontal(fold) {
                if let angle = inputs.hingeAngleDegrees, angle < tentMaximumAngle {
                    return .tent
                }
                return .laptop
            }
            return .book
        }

        // 2. A hinge without an active division: closed means the cover display.
        if let status = inputs.hingeStatus {
            if status == .closed {
                return .closed
            }
            // Fully open (flat) or partially open without a region, e.g. a non-fullscreen window.
            guard isSpreadSized(inputs.containerSize) else { return .closed }
            if let fold = inputs.anyDivision, isHorizontal(fold) {
                return .laptop
            }
            return .book
        }

        // 3. No hinge at all: fall back to the window size. Wide windows get the spread.
        return isSpreadSized(inputs.containerSize) ? .book : .closed
    }

    /// The rectangle to keep clear between the two pages, in container coordinates.
    /// Uses the real division region when there is one, otherwise a synthesized gutter
    /// at the middle of the container.
    static func hingeRect(for posture: Posture, inputs: PostureInputs, minimumThickness: CGFloat = 24) -> CGRect {
        let size = inputs.containerSize
        let fold = inputs.activeDivision ?? inputs.anyDivision
        switch posture {
        case .book:
            let base = fold.flatMap { isHorizontal($0) ? nil : $0 }
                ?? CGRect(x: size.width / 2, y: 0, width: 0, height: size.height)
            let width = max(base.width, minimumThickness)
            return CGRect(x: base.midX - width / 2, y: 0, width: width, height: size.height)
        case .laptop:
            let base = fold.flatMap { isHorizontal($0) ? $0 : nil }
                ?? CGRect(x: 0, y: size.height / 2, width: size.width, height: 0)
            let height = max(base.height, minimumThickness)
            return CGRect(x: 0, y: base.midY - height / 2, width: size.width, height: height)
        case .closed, .tent:
            return .null
        }
    }

    static func isHorizontal(_ fold: CGRect) -> Bool {
        fold.width > fold.height
    }

    static func isSpreadSized(_ size: CGSize) -> Bool {
        size.width >= minimumSpreadWidth
    }
}
