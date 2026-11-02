import SwiftUI
import UIKit

/// A color saved with a page item.
struct ItemColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    static let clear = ItemColor(red: 0, green: 0, blue: 0, alpha: 0)

    var isClear: Bool { alpha == 0 }
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
    var color: Color { Color(uiColor) }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: min(max(red, 0), 1), green: min(max(green, 0), 1), blue: min(max(blue, 0), 1), alpha: alpha)
    }
}

/// The typefaces a text box can use.
enum TextBoxFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case serif, marker, handwritten, typewriter, chalk, bold, script, rounded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serif: "Serif"
        case .marker: "Marker"
        case .handwritten: "Handwritten"
        case .typewriter: "Typewriter"
        case .chalk: "Chalk"
        case .bold: "Bold"
        case .script: "Script"
        case .rounded: "Rounded"
        }
    }

    private var postScriptName: String? {
        switch self {
        case .serif: "Georgia-Bold"
        case .marker: "MarkerFelt-Wide"
        case .handwritten: "Noteworthy-Bold"
        case .typewriter: "AmericanTypewriter-Semibold"
        case .chalk: "ChalkboardSE-Bold"
        case .bold: "AvenirNext-Heavy"
        case .script: "SnellRoundhand-Bold"
        case .rounded: nil
        }
    }

    func uiFont(size: CGFloat) -> UIFont {
        if let postScriptName, let font = UIFont(name: postScriptName, size: size) { return font }
        let system = UIFont.systemFont(ofSize: size, weight: .bold)
        return system.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? system
    }
}

/// The words in a text box and how they look. The box can be any color, or clear.
struct TextBox: Codable, Hashable, Sendable {
    var text: String
    var font = TextBoxFont.handwritten
    var textColor = TextBox.textColors[0]
    var boxColor = ItemColor.clear

    static let textColors = InkSwatch.palette.map { ItemColor(red: $0.red, green: $0.green, blue: $0.blue) }
        + [ItemColor(red: 1, green: 1, blue: 1)]
    static let boxColors = [
        ItemColor.clear,
        ItemColor(red: 1, green: 1, blue: 1),
        ItemColor(red: 0.96, green: 0.92, blue: 0.84),
        ItemColor(red: 0.91, green: 0.70, blue: 0.25),
        ItemColor(red: 0.50, green: 0.60, blue: 0.49),
        ItemColor(red: 0.55, green: 0.73, blue: 0.88),
        ItemColor(red: 0.91, green: 0.62, blue: 0.62),
        ItemColor(red: 0.77, green: 0.33, blue: 0.17),
        ItemColor(red: 0.13, green: 0.22, blue: 0.18),
    ]

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension PageItemArt {
    /// Text is laid out at this size and scaled with the item, like any other art.
    private static let textPointSize: CGFloat = 72
    private static let textMaxWidth: CGFloat = 640
    private static let textPadding: CGFloat = 32
    /// How much of the art's size a new text box starts at on the page.
    private static let textPageScale: CGFloat = 0.6

    static func textArt(_ box: TextBox) -> UIImage {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let text = NSAttributedString(string: box.trimmedText.isEmpty ? " " : box.trimmedText, attributes: [
            .font: box.font.uiFont(size: textPointSize),
            .foregroundColor: box.textColor.uiColor,
            .paragraphStyle: style,
        ])
        let measured = text.boundingRect(with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                                         options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let size = CGSize(width: ceil(measured.width) + textPadding * 2, height: ceil(measured.height) + textPadding * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            if !box.boxColor.isClear {
                box.boxColor.uiColor.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 22).fill()
            }
            text.draw(with: CGRect(x: textPadding, y: textPadding, width: size.width - textPadding * 2,
                                   height: size.height - textPadding * 2),
                      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
    }

    /// The width a new text box starts at on the page.
    static func startingWidth(for box: TextBox) -> CGFloat {
        min(textArt(box).size.width * textPageScale, PageGeometry.size.width * 0.9)
    }

    /// The width that keeps the letters the same size after the box's words or font change.
    static func width(of item: PageItem, afterChangingTo box: TextBox) -> CGFloat {
        guard case .text(let old) = item.content else { return item.width }
        let change = textArt(box).size.width / max(textArt(old).size.width, 1)
        return min(max(item.width * change, 40), PageGeometry.size.width * 1.2)
    }
}

/// Writes a text box and picks its font, text color and box color, showing it as it will look.
struct TextBoxEditor: View {
    let title: String
    let onSave: (TextBox) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var box: TextBox
    @FocusState private var isWriting: Bool

    init(title: String, box: TextBox = TextBox(text: ""), onSave: @escaping (TextBox) -> Void) {
        self.title = title
        self.onSave = onSave
        _box = State(initialValue: box)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(uiImage: PageItemArt.textArt(previewBox))
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 140)
                        .padding(12)
                        .background(Theme.paper, in: .rect(cornerRadius: 10))
                        .accessibilityLabel("Preview of the text box")

                    TextField("Write something", text: $box.text, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($isWriting)
                        .padding(12)
                        .background(Theme.paper, in: .rect(cornerRadius: 10))

                    labeled("Font") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(TextBoxFont.allCases) { fontButton($0) }
                            }
                        }
                    }
                    labeled("Text Color") {
                        swatches(TextBox.textColors, selection: $box.textColor, supportsOpacity: false)
                    }
                    labeled("Box Color") {
                        swatches(TextBox.boxColors, selection: $box.boxColor, supportsOpacity: true)
                    }
                }
                .padding(20)
            }
            .background(Theme.chrome)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        box.text = box.trimmedText
                        onSave(box)
                        dismiss()
                    }
                    .disabled(box.trimmedText.isEmpty)
                }
            }
        }
        .onAppear { isWriting = box.text.isEmpty }
    }

    /// The words on screen, or a stand-in until something is written.
    private var previewBox: TextBox {
        var preview = box
        if preview.trimmedText.isEmpty { preview.text = "Your words" }
        return preview
    }

    private func labeled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.inkText)
            content()
        }
    }

    private func fontButton(_ font: TextBoxFont) -> some View {
        let isSelected = box.font == font
        return Button {
            box.font = font
        } label: {
            Text(font.title)
                .font(Font(font.uiFont(size: 19)))
                .lineLimit(1)
                .foregroundStyle(Theme.inkText)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Theme.paper, in: .rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Ready-made colors, then the system picker for any other.
    private func swatches(_ colors: [ItemColor], selection: Binding<ItemColor>, supportsOpacity: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
            ForEach(colors, id: \.self) { color in
                swatch(color, selection: selection)
            }
            ColorPicker("Any Color", selection: Binding { selection.wrappedValue.color } set: { selection.wrappedValue = ItemColor($0) },
                        supportsOpacity: supportsOpacity)
                .labelsHidden()
                .frame(width: 44, height: 44)
        }
    }

    private func swatch(_ color: ItemColor, selection: Binding<ItemColor>) -> some View {
        let isSelected = selection.wrappedValue == color
        return Button {
            selection.wrappedValue = color
        } label: {
            ZStack {
                Circle().fill(color.isClear ? Theme.paper : color.color)
                if color.isClear {
                    Image(systemName: "slash.circle")
                        .font(.title2)
                        .foregroundStyle(Theme.inkText)
                }
            }
            .frame(width: 36, height: 36)
            .overlay {
                Circle().strokeBorder(Theme.rule, lineWidth: 1)
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                    .padding(-4)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.isClear ? "Transparent" : "Color")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
