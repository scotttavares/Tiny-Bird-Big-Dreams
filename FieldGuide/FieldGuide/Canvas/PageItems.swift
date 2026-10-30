import PhotosUI
import SwiftUI
import UIKit

/// The art for stickers, photos and tape, and how they're drawn onto a page.
/// One drawing path for the live page, thumbnails, page turns and exports.
@MainActor
enum PageItemArt {
    /// Where photo items are read from. Set by `AppModel`.
    static var imageStore: ImageStore = .standard

    /// Emoji offered as stickers, field-journal things first.
    static let stickers = [
        "🌿", "🍃", "🍂", "🍁", "🌸", "🌻", "🌼", "🍄", "🌲", "🌵", "🪨", "⛰️",
        "🏕️", "☀️", "🌙", "⭐️", "🌈", "☁️", "❄️", "💧", "🐦", "🦉", "🦆", "🦅",
        "🐝", "🦋", "🐞", "🐌", "🐛", "🐸", "🐿️", "🦊", "🦌", "🐢", "🐟", "🐚",
        "🪶", "🐾", "🔭", "🧭", "🗺️", "📷", "✏️", "❤️", "✨", "✅",
    ]

    struct Tape {
        let name: String
        let color: UIColor
        let stripes: Bool
    }

    static let tapes = [
        Tape(name: "Kraft", color: UIColor(red: 0.80, green: 0.66, blue: 0.45, alpha: 1), stripes: false),
        Tape(name: "Sage", color: UIColor(red: 0.60, green: 0.72, blue: 0.58, alpha: 1), stripes: true),
        Tape(name: "Rose", color: UIColor(red: 0.91, green: 0.62, blue: 0.62, alpha: 1), stripes: false),
        Tape(name: "Sky", color: UIColor(red: 0.55, green: 0.73, blue: 0.88, alpha: 1), stripes: true),
        Tape(name: "Mustard", color: UIColor(red: 0.90, green: 0.75, blue: 0.35, alpha: 1), stripes: false),
        Tape(name: "Ink", color: UIColor(red: 0.25, green: 0.30, blue: 0.40, alpha: 1), stripes: true),
    ]

    private static var cache: [PageItem.Content: UIImage] = [:]

    static func image(for content: PageItem.Content) -> UIImage? {
        if let cached = cache[content] { return cached }
        let made: UIImage?
        switch content {
        case .sticker(let emoji): made = sticker(emoji)
        case .photo(let path): made = imageStore.image(at: path).map(printedPhoto)
        case .tape(let index): made = tape(tapes[((index % tapes.count) + tapes.count) % tapes.count])
        }
        if let made {
            if cache.count > 120 { cache.removeAll() }
            cache[content] = made
        }
        return made
    }

    /// The item's size on the page: its width, and the height its art calls for.
    static func size(of item: PageItem) -> CGSize {
        guard let image = image(for: item.content), image.size.width > 0 else {
            return CGSize(width: item.width, height: item.width)
        }
        return CGSize(width: item.width, height: item.width * image.size.height / image.size.width)
    }

    /// Draws `items` in page coordinates into the current UIKit graphics context.
    static func draw(_ items: [PageItem], in context: CGContext) {
        for item in items {
            guard let image = image(for: item.content) else { continue }
            let drawn = size(of: item)
            context.saveGState()
            context.translateBy(x: item.center.x, y: item.center.y)
            context.rotate(by: item.rotation)
            let isTape: Bool
            if case .tape = item.content { isTape = true } else { isTape = false }
            context.setShadow(offset: CGSize(width: 0, height: isTape ? 1 : 3), blur: isTape ? 2 : 6,
                              color: UIColor.black.withAlphaComponent(isTape ? 0.12 : 0.25).cgColor)
            image.draw(in: CGRect(x: -drawn.width / 2, y: -drawn.height / 2, width: drawn.width, height: drawn.height))
            context.restoreGState()
        }
    }

    // MARK: Art

    /// The emoji with a white die-cut edge, like a vinyl sticker.
    private static func sticker(_ emoji: String) -> UIImage {
        let text = NSAttributedString(string: emoji, attributes: [.font: UIFont.systemFont(ofSize: 200)])
        let measured = text.size()
        let glyph = CGSize(width: ceil(measured.width), height: ceil(measured.height))
        let border: CGFloat = 14
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let art = UIGraphicsImageRenderer(size: glyph, format: format).image { _ in
            text.draw(at: .zero)
        }
        let silhouette = UIGraphicsImageRenderer(size: glyph, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: glyph))
            art.draw(at: .zero, blendMode: .destinationIn, alpha: 1)
        }
        let size = CGSize(width: glyph.width + border * 2, height: glyph.height + border * 2)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            for step in 0..<24 {
                let angle = Double(step) / 24 * 2 * .pi
                silhouette.draw(at: CGPoint(x: border + cos(angle) * border, y: border + sin(angle) * border))
            }
            art.draw(at: CGPoint(x: border, y: border))
        }
    }

    /// A photo printed with a thin white border.
    private static func printedPhoto(_ photo: UIImage) -> UIImage {
        let longest = max(photo.size.width, photo.size.height, 1)
        let fit = min(1, 1400 / longest)
        let inner = CGSize(width: photo.size.width * fit, height: photo.size.height * fit)
        let border = max(inner.width, inner.height) * 0.035
        let size = CGSize(width: inner.width + border * 2, height: inner.height + border * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.98, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            photo.draw(in: CGRect(x: border, y: border, width: inner.width, height: inner.height))
        }
    }

    /// A see-through strip with torn, zigzag ends.
    private static func tape(_ tape: Tape) -> UIImage {
        let size = CGSize(width: 480, height: 110)
        let tooth: CGFloat = 9
        let teeth = Int(size.height / 11)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: tooth, y: 0))
        path.addLine(to: CGPoint(x: size.width - tooth, y: 0))
        for step in 1...teeth {
            let y = size.height * CGFloat(step) / CGFloat(teeth)
            path.addLine(to: CGPoint(x: size.width - (step.isMultiple(of: 2) ? tooth : 0), y: y))
        }
        path.addLine(to: CGPoint(x: tooth, y: size.height))
        for step in stride(from: teeth - 1, through: 0, by: -1) {
            let y = size.height * CGFloat(step) / CGFloat(teeth)
            path.addLine(to: CGPoint(x: step.isMultiple(of: 2) ? tooth : 0, y: y))
        }
        path.close()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            tape.color.withAlphaComponent(0.72).setFill()
            path.fill()
            if tape.stripes {
                cg.saveGState()
                path.addClip()
                UIColor.white.withAlphaComponent(0.35).setStroke()
                let stripes = UIBezierPath()
                stripes.lineWidth = 12
                var x: CGFloat = -size.height
                while x < size.width {
                    stripes.move(to: CGPoint(x: x, y: size.height))
                    stripes.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += 34
                }
                stripes.stroke()
                cg.restoreGState()
            }
        }
    }
}

/// One side of the page's items in the live canvas, in page coordinates: those under the ink
/// (between the paper and the drawing) or those over it.
final class PageItemsLayerView: UIView {
    let overInk: Bool

    var items: [PageItem] = [] {
        didSet {
            let side = items.filter { $0.overInk == overInk }
            if side != drawn { drawn = side; setNeedsDisplay() }
        }
    }

    private var drawn: [PageItem] = []

    init(frame: CGRect, overInk: Bool) {
        self.overInk = overInk
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), !drawn.isEmpty else { return }
        PageItemArt.draw(drawn, in: context)
    }
}

/// Over the page while arranging: tap an item to pick it, drag to move it, pinch to resize it
/// and twist to turn it. The canvas sits at "whole page fits" meanwhile, so page and screen line up.
struct PageItemsEditor: View {
    let model: AppModel
    /// The page's size on screen.
    let size: CGSize

    /// The selected item as it was when the current gestures began.
    @State private var base: PageItem?
    @State private var offset: CGSize = .zero
    @State private var magnification: CGFloat = 1
    @State private var turn: Angle = .zero

    private var store: CanvasStore { model.canvas }
    /// Screen points per page point.
    private var scale: CGFloat { size.width / PageGeometry.size.width }
    private var selected: PageItem? { store.items.first { $0.id == store.selectedItemID } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.04)
                .contentShape(.rect)
                .gesture(drag)
                .simultaneousGesture(pinch)
                .simultaneousGesture(twist)
                .accessibilityHidden(true)

            if let selected {
                let itemSize = PageItemArt.size(of: selected)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: itemSize.width * scale + 12, height: itemSize.height * scale + 12)
                    .rotationEffect(.radians(selected.rotation))
                    .position(x: selected.center.x * scale, y: selected.center.y * scale)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .top) { controls.padding(8) }
        .overlay(alignment: .bottom) {
            Text(selected == nil ? "Tap a sticker or photo to move it" : "Drag to move · Pinch to resize · Twist to turn")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: .capsule)
                .padding(10)
                .allowsHitTesting(false)
        }
    }

    private var controls: some View {
        HStack(spacing: 4) {
            if let selected {
                Button("Delete", systemImage: "trash", role: .destructive) { model.deleteItem(selected.id) }
                Menu {
                    stackButton("Bring to Front", "square.3.layers.3d.top.filled", .front, selected.id)
                    stackButton("Bring Forward", "square.2.layers.3d.top.filled", .forward, selected.id)
                    stackButton("Send Backward", "square.2.layers.3d.bottom.filled", .backward, selected.id)
                    stackButton("Send to Back", "square.3.layers.3d.bottom.filled", .back, selected.id)
                } label: {
                    Label("Arrange", systemImage: "square.3.layers.3d")
                        .labelStyle(.iconOnly)
                }
            }
            Button("Done") { store.endArranging() }
                .fontWeight(.semibold)
        }
        .buttonStyle(.bordered)
        .padding(6)
        .background(.regularMaterial, in: .capsule)
    }

    /// Moves the item one way through the stack, where the drawing counts as a layer.
    private func stackButton(_ title: String, _ icon: String, _ move: CanvasStore.StackMove, _ id: UUID) -> some View {
        Button(title, systemImage: icon) { store.move(id, move) }
            .disabled(!store.canMove(id, move))
    }

    // MARK: Gestures

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if base == nil { begin(at: value.startLocation) }
                offset = value.translation
                apply()
            }
            .onEnded { value in
                if let center = moved(base?.center, by: value.translation) { base?.center = center }
                offset = .zero
                finishIfIdle()
            }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if base == nil { begin(at: nil) }
                magnification = value.magnification
                apply()
            }
            .onEnded { value in
                if let width = base?.width { base?.width = clampedWidth(width * value.magnification) }
                magnification = 1
                finishIfIdle()
            }
    }

    private var twist: some Gesture {
        RotateGesture()
            .onChanged { value in
                if base == nil { begin(at: nil) }
                turn = value.rotation
                apply()
            }
            .onEnded { value in
                base?.rotation += value.rotation.radians
                turn = .zero
                finishIfIdle()
            }
    }

    /// Picks the item under `point` (a drag start), or keeps the selection for a pinch or twist.
    private func begin(at point: CGPoint?) {
        if let point {
            let pagePoint = CGPoint(x: point.x / scale, y: point.y / scale)
            let hit = PageItem.stacked(store.items).last { $0.contains(pagePoint, size: PageItemArt.size(of: $0)) }
            store.selectedItemID = hit?.id
        }
        base = selected
    }

    private func apply() {
        guard var item = base else { return }
        item.center = moved(item.center, by: offset) ?? item.center
        item.width = clampedWidth(item.width * magnification)
        item.rotation += turn.radians
        store.update(item)
    }

    private func moved(_ center: CGPoint?, by translation: CGSize) -> CGPoint? {
        guard let center else { return nil }
        let page = PageGeometry.size
        return CGPoint(x: min(max(center.x + translation.width / scale, 0), page.width),
                       y: min(max(center.y + translation.height / scale, 0), page.height))
    }

    private func clampedWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, 40), PageGeometry.size.width * 1.2)
    }

    /// Once every finger is up, saves the page.
    private func finishIfIdle() {
        guard offset == .zero, magnification == 1, turn == .zero else { return }
        if base != nil { store.commitItems() }
        base = nil
    }
}

/// Stickers, tape and photos to put on the page.
struct StickerPicker: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var addedFromCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !model.canvas.items.isEmpty {
                        Button {
                            model.canvas.beginArranging()
                            dismiss()
                        } label: {
                            Label("Move, Resize or Remove", systemImage: "hand.draw")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    section("Photos") {
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("Choose Photo", systemImage: "photo")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            Button {
                                isShowingCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.inkText)
                    }

                    section("Stickers") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 10)], spacing: 10) {
                            ForEach(PageItemArt.stickers, id: \.self) { emoji in
                                Button {
                                    model.addItem(.sticker(emoji))
                                    dismiss()
                                } label: {
                                    art(.sticker(emoji))
                                        .frame(width: 54, height: 54)
                                        .frame(maxWidth: .infinity, minHeight: 60)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(emoji) sticker")
                            }
                        }
                    }

                    section("Tape") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                            ForEach(PageItemArt.tapes.indices, id: \.self) { index in
                                Button {
                                    model.addItem(.tape(index))
                                    dismiss()
                                } label: {
                                    art(.tape(index))
                                        .frame(height: 34)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(PageItemArt.tapes[index].name) tape")
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.chrome)
            .navigationTitle("Stickers & Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                model.addPhoto(image.downscaled(maxDimension: 2000))
                addedFromCamera = true
            }
        }
        .onChange(of: isShowingCamera) { _, showing in
            if !showing && addedFromCamera { dismiss() }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.inkText)
            content()
        }
    }

    @ViewBuilder
    private func art(_ content: PageItem.Content) -> some View {
        if let image = PageItemArt.image(for: content) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        model.addPhoto(image.downscaled(maxDimension: 2000))
        dismiss()
    }
}
