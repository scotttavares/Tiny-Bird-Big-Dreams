import SwiftUI
import UIKit

/// Named colors from the asset catalog. Each has a warm-paper light variant and a slate dark variant.
enum Theme {
    static let paper = Color("PaperColor")
    static let paperEdge = Color("PaperEdgeColor")
    static let rule = Color("PaperRuleColor")
    static let inkText = Color("InkTextColor")
    static let chrome = Color("ChromeColor")

    static var paperUIColor: UIColor { UIColor(named: "PaperColor") ?? .systemBackground }
    static var ruleUIColor: UIColor { UIColor(named: "PaperRuleColor") ?? .separator }

    /// The light-appearance paper, used for exports so shared images look the same everywhere.
    static var exportPaperUIColor: UIColor {
        paperUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    }

    static var exportRuleUIColor: UIColor {
        ruleUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    }

    /// Posture transitions: ~0.35 s, or a plain crossfade-length change under Reduce Motion.
    static func postureAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : .smooth(duration: 0.35)
    }
}

/// One ink in the palette.
struct InkSwatch: Identifiable, Hashable, Sendable {
    let name: String
    let red: Double
    let green: Double
    let blue: Double

    var id: String { name }
    var color: Color { Color(red: red, green: green, blue: blue) }
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }

    /// Soft field inks. All are at least 4.5:1 against the light paper.
    static let palette: [InkSwatch] = [
        InkSwatch(name: "Ink", red: 0.17, green: 0.16, blue: 0.16),
        InkSwatch(name: "Graphite", red: 0.36, green: 0.36, blue: 0.37),
        InkSwatch(name: "Sepia", red: 0.45, green: 0.30, blue: 0.18),
        InkSwatch(name: "Rust", red: 0.61, green: 0.27, blue: 0.17),
        InkSwatch(name: "Ochre", red: 0.55, green: 0.38, blue: 0.08),
        InkSwatch(name: "Moss", red: 0.29, green: 0.40, blue: 0.21),
        InkSwatch(name: "Slate Blue", red: 0.23, green: 0.35, blue: 0.46),
        InkSwatch(name: "Plum", red: 0.42, green: 0.27, blue: 0.43),
    ]
}

/// The fixed logical page every canvas uses, so strokes keep their coordinates on any screen.
enum PageGeometry {
    static let size = CGSize(width: 800, height: 1100)
    static var rect: CGRect { CGRect(origin: .zero, size: size) }
}
