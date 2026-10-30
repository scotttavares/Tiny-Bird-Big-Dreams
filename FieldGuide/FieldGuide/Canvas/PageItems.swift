import AVFoundation
import AVKit
import CoreTransferable
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The art for stickers, photos, videos and tape, and how they're drawn onto a page. Thumbnails,
/// page turns and exports draw it here (a video as its first frame); the live page uses its layers.
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

    /// A printed photo's white border, as a fraction of its longest side.
    static let printBorder: CGFloat = 0.035 / 1.07

    static func image(for content: PageItem.Content) -> UIImage? {
        if let cached = cache[content] { return cached }
        let made: UIImage?
        switch content {
        case .sticker(let emoji): made = sticker(emoji)
        case .photo(let path): made = imageStore.image(at: path).map(printedPhoto)
        case .video(let path): made = imageStore.image(at: ImageStore.posterPath(forVideo: path)).map(printedPhoto)
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
/// (between the paper and the drawing) or those over it. Each item is its own layer, so videos
/// keep their place in the stack and items move without redrawing the page.
final class PageItemsLayerView: UIView {
    private final class ItemLayer {
        let layer = CALayer()
        var video: LoopingVideo?
    }

    let overInk: Bool

    var items: [PageItem] = [] {
        didSet {
            let side = items.filter { $0.overInk == overInk }
            if side != shown { shown = side; syncLayers() }
        }
    }

    private var shown: [PageItem] = []
    private var itemLayers: [UUID: ItemLayer] = [:]

    init(frame: CGRect, overInk: Bool) {
        self.overInk = overInk
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        NotificationCenter.default.addObserver(self, selector: #selector(resumeVideos),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The system pauses players in the background.
    @objc private func resumeVideos() {
        itemLayers.values.forEach { $0.video?.play() }
    }

    private func syncLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let keep = Set(shown.map(\.id))
        for (id, entry) in itemLayers where !keep.contains(id) {
            entry.video?.stop()
            entry.layer.removeFromSuperlayer()
            itemLayers[id] = nil
        }
        for (index, item) in shown.enumerated() {
            let entry = itemLayers[item.id] ?? makeLayer(for: item)
            let size = PageItemArt.size(of: item)
            entry.layer.bounds = CGRect(origin: .zero, size: size)
            entry.layer.position = item.center
            entry.layer.setAffineTransform(CGAffineTransform(rotationAngle: item.rotation))
            entry.layer.zPosition = CGFloat(index)
            let border = max(size.width, size.height) * PageItemArt.printBorder
            entry.video?.layer.frame = entry.layer.bounds.insetBy(dx: border, dy: border)
        }
    }

    private func makeLayer(for item: PageItem) -> ItemLayer {
        let entry = ItemLayer()
        entry.layer.contents = PageItemArt.image(for: item.content)?.cgImage
        let isTape: Bool
        if case .tape = item.content { isTape = true } else { isTape = false }
        entry.layer.shadowColor = UIColor.black.cgColor
        entry.layer.shadowOffset = CGSize(width: 0, height: isTape ? 1 : 3)
        entry.layer.shadowRadius = isTape ? 1 : 3
        entry.layer.shadowOpacity = isTape ? 0.12 : 0.25
        if case .video(let path) = item.content {
            let video = LoopingVideo(url: PageItemArt.imageStore.url(for: path))
            entry.layer.addSublayer(video.layer)
            entry.video = video
        }
        layer.addSublayer(entry.layer)
        itemLayers[item.id] = entry
        return entry
    }
}

/// A clip playing silently on the page, round and round.
@MainActor
final class LoopingVideo {
    let layer: AVPlayerLayer

    private let player = AVQueuePlayer()
    private let looper: AVPlayerLooper

    init(url: URL) {
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        // Silent clips shouldn't stop the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player.play()
    }

    func play() {
        player.play()
    }

    func stop() {
        looper.disableLooping()
        player.pause()
    }
}

/// Turns a picked video into a short clip for the page: at most `maxDuration`, at most 720p.
enum VideoClip {
    static let maxDuration: Double = 15

    /// Writes the clip to `target` and returns its first frame.
    @MainActor
    static func prepare(_ source: URL, to target: URL) async throws -> UIImage {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            throw CocoaError(.fileWriteUnknown)
        }
        session.timeRange = CMTimeRange(start: .zero, duration: CMTimeMinimum(duration, CMTime(seconds: maxDuration, preferredTimescale: 600)))
        try await session.export(to: target, as: .mp4)

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: target))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1400, height: 1400)
        let frame = try await generator.image(at: .zero)
        return UIImage(cgImage: frame.image)
    }
}

/// A video from the photo library, copied somewhere the app can read it.
struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedVideo(url: copy)
        }
    }
}

/// A clip full screen, with sound.
struct ClipPlayer: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: player)
                .ignoresSafeArea()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
        }
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
    @State private var playingVideo: URL?

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
        .fullScreenCover(isPresented: Binding { playingVideo != nil } set: { if !$0 { playingVideo = nil } }) {
            if let playingVideo { ClipPlayer(url: playingVideo) }
        }
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
            if let selected, case .video(let path) = selected.content {
                Button("Play with Sound", systemImage: "play.fill") { playingVideo = model.imageStore.url(for: path) }
                    .labelStyle(.iconOnly)
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
            let hit = store.item(at: pagePoint)
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
    @State private var videoItem: PhotosPickerItem?
    @State private var isAddingVideo = false
    @State private var videoFailed = false

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

                    section("Photos and Videos") {
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
                        // The picker's label is a Sendable closure, so it takes a copy, not the state.
                        let videoTitle = isAddingVideo ? "Adding Video…" : "Choose Video"
                        PhotosPicker(selection: $videoItem, matching: .videos) {
                            Label(videoTitle, systemImage: "video")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.inkText)
                        .disabled(isAddingVideo)
                        Text(videoFailed ? "That video couldn't be added." : "Longer videos are trimmed to their first 15 seconds.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
        .onChange(of: videoItem) { _, item in
            guard let item else { return }
            Task { await loadVideo(item) }
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

    private func loadVideo(_ item: PhotosPickerItem) async {
        isAddingVideo = true
        videoFailed = false
        defer {
            isAddingVideo = false
            videoItem = nil
        }
        guard let picked = try? await item.loadTransferable(type: PickedVideo.self) else {
            videoFailed = true
            return
        }
        let added = await model.addVideo(from: picked.url)
        try? FileManager.default.removeItem(at: picked.url)
        if added { dismiss() } else { videoFailed = true }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        model.addPhoto(image.downscaled(maxDimension: 2000))
        dismiss()
    }
}
