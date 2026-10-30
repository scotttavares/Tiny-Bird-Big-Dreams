import SwiftUI
import UIKit

/// Drawing tools. `.full` for the open postures, `.compact` for the closed (outer display) strip.
struct ToolStrip: View {
    enum Style {
        case full
        case compact
    }

    @Bindable var store: CanvasStore
    var style: Style = .full
    /// Opens the stickers and photos sheet.
    var onStickers: () -> Void = {}

    @State private var customColor: Color = .black
    @State private var tuningTool: CanvasStore.ToolKind?
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 44

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                toolButtons
                Button(action: onStickers) {
                    Image(systemName: store.isArranging ? "face.smiling.inverse" : "face.smiling")
                        .font(.title3)
                        .frame(width: buttonSize, height: buttonSize)
                        .foregroundStyle(store.isArranging ? Theme.onAccent : Theme.inkText)
                        .background(store.isArranging ? Color.accentColor : .clear, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stickers and photos")
                divider
                if style == .full {
                    swatches
                    ColorPicker("Custom ink", selection: customColorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: buttonSize, height: buttonSize)
                        .accessibilityLabel("Custom ink color")
                    divider
                    widthSlider
                        .frame(width: 140)
                    divider
                } else {
                    colorMenu
                    widthMenu
                    PaperStylePicker(store: store)
                    if store.referenceImage != nil {
                        TracingToggle(store: store)
                    }
                    divider
                }
                undoRedo
                if style == .full {
                    divider
                    PaperStylePicker(store: store)
                    TracingToggle(store: store)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(.regularMaterial, in: .rect(cornerRadius: 18))
        .sensoryFeedback(.selection, trigger: store.toolKind)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drawing tools")
    }

    // MARK: Pieces

    private var toolButtons: some View {
        ForEach(CanvasStore.ToolKind.allCases) { kind in
            let isSelected = store.toolKind == kind
            Button {
                store.toolKind = kind
            } label: {
                Image(systemName: kind.symbol)
                    .font(.title3)
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundStyle(isSelected ? Theme.onAccent : Theme.inkText)
                    .background(isSelected ? Color.accentColor : .clear, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            // Hold a tool for its colour and size, wherever they are on this strip.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                    store.toolKind = kind
                    if kind != .eraser { tuningTool = kind }
                }
            )
            .popover(isPresented: Binding { tuningTool == kind } set: { if !$0 { tuningTool = nil } }) {
                toolTuning(kind)
            }
            .accessibilityLabel(kind.title)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private func toolTuning(_ kind: CanvasStore.ToolKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.title)
                .font(.headline)
                .foregroundStyle(Theme.inkText)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(buttonSize * 0.85), spacing: 4), count: 5), spacing: 4) {
                swatches
            }
            widthSlider
                .frame(width: 220)
        }
        .padding(14)
        .presentationCompactAdaptation(.popover)
    }

    private var swatches: some View {
        ForEach(InkSwatch.palette) { swatch in
            let isSelected = store.inkColor.isApproximately(swatch.uiColor)
            Button {
                store.inkColor = swatch.uiColor
                if store.toolKind == .eraser { store.toolKind = .pen }
            } label: {
                Circle()
                    .fill(swatch.color)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Circle()
                            .strokeBorder(Theme.inkText, lineWidth: isSelected ? 2.5 : 0)
                            .padding(-5)
                    }
                    .frame(width: buttonSize * 0.85, height: buttonSize)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(swatch.name) ink")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private var colorMenu: some View {
        Menu {
            ForEach(InkSwatch.palette) { swatch in
                Button {
                    store.inkColor = swatch.uiColor
                    if store.toolKind == .eraser { store.toolKind = .pen }
                } label: {
                    Label(swatch.name, systemImage: store.inkColor.isApproximately(swatch.uiColor) ? "checkmark.circle.fill" : "circle.fill")
                }
                .tint(swatch.color)
            }
        } label: {
            Circle()
                .fill(Color(uiColor: store.inkColor))
                .frame(width: 26, height: 26)
                .frame(width: buttonSize, height: buttonSize)
        }
        .accessibilityLabel("Ink color")
    }

    private var widthMenu: some View {
        Menu {
            Slider(value: $store.widthFraction, in: 0...1) {
                Text("Stroke width")
            }
            Picker("Width", selection: $store.widthFraction) {
                Text("Fine").tag(0.1)
                Text("Medium").tag(0.25)
                Text("Bold").tag(0.6)
            }
        } label: {
            Image(systemName: "lineweight")
                .font(.title3)
                .frame(width: buttonSize, height: buttonSize)
        }
        .accessibilityLabel("Stroke width")
    }

    private var widthSlider: some View {
        HStack(spacing: 6) {
            Circle().frame(width: 4, height: 4)
            Slider(value: $store.widthFraction, in: 0...1)
                .accessibilityLabel("Stroke width")
                .accessibilityValue("\(Int(store.widthFraction * 100)) percent")
            Circle().frame(width: 12, height: 12)
        }
        .foregroundStyle(Theme.inkText)
    }

    private var undoRedo: some View {
        HStack(spacing: 2) {
            Button {
                store.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
                    .frame(width: buttonSize, height: buttonSize)
            }
            .disabled(!store.canUndo)
            .accessibilityLabel("Undo")

            Button {
                store.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.title3)
                    .frame(width: buttonSize, height: buttonSize)
            }
            .disabled(!store.canRedo)
            .accessibilityLabel("Redo")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.inkText)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(width: 1, height: buttonSize * 0.6)
            .accessibilityHidden(true)
    }

    private var customColorBinding: Binding<Color> {
        Binding {
            customColor
        } set: { newValue in
            customColor = newValue
            store.inkColor = UIColor(newValue)
            if store.toolKind == .eraser { store.toolKind = .pen }
        }
    }
}

struct PaperStylePicker: View {
    @Bindable var store: CanvasStore
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 44

    var body: some View {
        Menu {
            Picker("Pattern", selection: $store.paperStyle) {
                ForEach(PaperStyle.allCases) { style in
                    Label(style.title, systemImage: style.symbol).tag(style)
                }
            }
            Picker("Paper Color", selection: $store.paperTint) {
                ForEach(PaperTint.allCases) { tint in
                    Label {
                        Text(tint.title)
                    } icon: {
                        Image(uiImage: Self.swatch(for: tint))
                    }
                    .tag(tint)
                }
            }
        } label: {
            Image(systemName: store.paperStyle.symbol)
                .font(.title3)
                .frame(width: buttonSize, height: buttonSize)
                .foregroundStyle(Theme.inkText)
        }
        .accessibilityLabel("Paper")
        .accessibilityValue("\(store.paperStyle.title), \(store.paperTint.title)")
    }

    /// A small round chip of the paper colour for the menu (menus drop SwiftUI tints, so it's an image).
    private static func swatch(for tint: PaperTint) -> UIImage {
        let size = CGSize(width: 22, height: 22)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
            if tint == .automatic {
                // Half light, half dark: it follows the device.
                let light = PaperTint.cream.paperColor(for: UITraitCollection(userInterfaceStyle: .light))
                let dark = PaperTint.night.paperColor(for: UITraitCollection(userInterfaceStyle: .dark))
                light.setFill()
                UIBezierPath(ovalIn: rect).fill()
                context.cgContext.saveGState()
                UIBezierPath(ovalIn: rect).addClip()
                dark.setFill()
                UIRectFill(CGRect(x: rect.midX, y: 0, width: size.width, height: size.height))
                context.cgContext.restoreGState()
            } else {
                tint.paperColor(for: UITraitCollection(userInterfaceStyle: tint.appearance)).setFill()
                UIBezierPath(ovalIn: rect).fill()
            }
            UIColor(white: 0.5, alpha: 0.6).setStroke()
            let ring = UIBezierPath(ovalIn: rect)
            ring.lineWidth = 1
            ring.stroke()
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}

struct TracingToggle: View {
    @Bindable var store: CanvasStore
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 44

    var body: some View {
        Button {
            store.isTracing.toggle()
        } label: {
            Image(systemName: store.isTracing ? "square.on.square.fill" : "square.on.square")
                .font(.title3)
                .frame(width: buttonSize, height: buttonSize)
                .foregroundStyle(store.isTracing ? Color.accentColor : Theme.inkText)
        }
        .buttonStyle(.plain)
        .disabled(store.referenceImage == nil)
        .accessibilityLabel("Tracing mode")
        .accessibilityValue(store.isTracing ? "On" : "Off")
        .accessibilityHint("Shows the reference photo faintly under the canvas.")
        .sensoryFeedback(.selection, trigger: store.isTracing)
    }
}

extension UIColor {
    /// Compares sRGB components; used to highlight the selected swatch.
    func isApproximately(_ other: UIColor, tolerance: CGFloat = 0.01) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else { return false }
        return abs(r1 - r2) < tolerance && abs(g1 - g2) < tolerance && abs(b1 - b2) < tolerance
    }
}
