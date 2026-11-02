import CoreGraphics
import SwiftUI

/// Where the script and the camera stage go on screen.
///
/// Stand mode is the iPhone Duo half-folded on a table with the fold running across a
/// portrait screen: the upright top half (with the front camera) shows the script so your
/// eyes stay near the lens, and the flat bottom half shows the preview and controls.
/// Every other case (unfolded, the outer display, any other iPhone) stacks the two.
struct StandLayout: Equatable, Sendable {
    enum Mode: Equatable, Sendable {
        /// Half-folded with a horizontal fold: split at the hinge.
        case stand
        /// One flat screen: script on top, stage below.
        case stacked
    }

    var mode: Mode
    var script: CGRect
    var stage: CGRect
    /// The hinge area to leave empty (`.null` when stacked).
    var hinge: CGRect

    /// Share of a flat screen the script gets when stacked.
    static let stackedScriptShare: CGFloat = 0.42

    static func make(size: CGSize, activeFold: CGRect?) -> StandLayout {
        if let fold = activeFold, fold.width > fold.height, fold.minY > 0, fold.maxY < size.height {
            return StandLayout(
                mode: .stand,
                script: CGRect(x: 0, y: 0, width: size.width, height: fold.minY),
                stage: CGRect(x: 0, y: fold.maxY, width: size.width, height: size.height - fold.maxY),
                hinge: fold
            )
        }
        let split = (size.height * stackedScriptShare).rounded()
        return StandLayout(
            mode: .stacked,
            script: CGRect(x: 0, y: 0, width: size.width, height: split),
            stage: CGRect(x: 0, y: split, width: size.width, height: size.height - split),
            hinge: .null
        )
    }
}

/// Reads the fold's reserved region for the view it is attached to.
struct FoldReader: ViewModifier {
    @Binding var activeFold: CGRect?

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect?.self) { proxy in
            Self.activeDivision(proxy)
        } action: { newValue in
            activeFold = newValue
        }
    }

    nonisolated private static func activeDivision(_ proxy: GeometryProxy) -> CGRect? {
        #if TALKSTAND_DUO_SDK
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division).first?.frame
        }
        #endif
        return nil
    }
}

extension View {
    func readsFold(into fold: Binding<CGRect?>) -> some View {
        modifier(FoldReader(activeFold: fold))
    }
}
