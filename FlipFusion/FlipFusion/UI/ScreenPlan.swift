import SwiftUI

/// How the game screen is arranged for the space it has. Pure sums, so it can be
/// tested without a screen.
struct ScreenPlan: Equatable {
    enum Kind: Equatable {
        /// Everything in one column: a phone held upright, an iPad held upright, the
        /// outer screen of a folded phone.
        case tall
        /// The scores and boosters on the left, the board on the right: an iPad or a
        /// phone on its side, and a folding phone opened flat or like a book.
        case wide
        /// A folding phone half open and set down like a laptop: the board on the
        /// upright half, the scores and boosters on the half lying flat.
        case laptop
    }

    var kind: Kind
    /// The scale of the scores and boosters (1 on a 393-point-wide phone).
    var scale: CGFloat
    /// The width the score cards and boosters are laid out to.
    var panelSide: CGFloat
    /// The length of the board's side.
    var boardSide: CGFloat
    /// Wide: the width of the left-hand panel. Laptop: the height of the upright half.
    var firstLength: CGFloat = 0
    /// The width or height kept clear over a fold.
    var gap: CGFloat = 0

    /// `fold` is the strip of screen over the hinge of a partly folded phone, in the
    /// same coordinates as `size`; nil when there is none.
    init(size: CGSize, fold: CGRect? = nil) {
        let width = max(1, size.width)
        let height = max(1, size.height)

        if let fold, fold.width > fold.height, fold.minY > height * 0.25, fold.maxY < height * 0.75 {
            let top = fold.minY
            let bottom = height - fold.maxY
            kind = .laptop
            firstLength = top
            gap = fold.height
            scale = min(width / 393, bottom / 430)
            boardSide = min(width * 0.8, top * 0.74)
            panelSide = 322 * scale
        } else if width > height * 1.1 {
            var first = width / 2
            var clear: CGFloat = 0
            if let fold, fold.height > fold.width, fold.minX > width * 0.25, fold.maxX < width * 0.75 {
                first = fold.minX
                clear = fold.width
            }
            let second = width - first - clear
            kind = .wide
            firstLength = first
            gap = clear
            scale = min(first / 380, (height - 44) / 440)
            boardSide = min(second * 0.8, height * 0.74)
            panelSide = 322 * scale
        } else {
            kind = .tall
            // 44 points at the top are kept for the coin counter and the menu.
            scale = min(width / 393, (height - 44) / 716)
            boardSide = 322 * scale
            panelSide = boardSide
        }
    }
}

/// Reads the fold of a partly folded iPhone Duo: the strip of screen over the hinge,
/// in the coordinates of the view this is put on. Nil on every other device, and on
/// a Duo that is shut or lying flat.
struct FoldReader: ViewModifier {
    @Binding var fold: CGRect?

    func body(content: Content) -> some View {
        #if FLIPFUSION_DUO_SDK
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: CGRect?.self) { proxy in
                proxy.reservedRegions(kind: .division).first?.frame
            } action: { strip in
                fold = strip
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
