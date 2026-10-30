import CoreImage
import Foundation
import SwiftData
import UIKit

/// A named collection of pages.
@Model
final class Notebook {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    /// `NotebookTheme` raw value: the cover design. Defaulted so older stores migrate.
    var themeRaw: String = NotebookTheme.pines.rawValue

    @Relationship(deleteRule: .cascade, inverse: \Page.notebook)
    var pages: [Page] = []

    init(title: String, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var theme: NotebookTheme {
        get { NotebookTheme(rawValue: themeRaw) ?? .pines }
        set { themeRaw = newValue.rawValue }
    }

    /// Pages in the order they were added to the notebook.
    var orderedPages: [Page] {
        pages.sorted { lhs, rhs in
            lhs.sortIndex == rhs.sortIndex ? lhs.createdAt < rhs.createdAt : lhs.sortIndex < rhs.sortIndex
        }
    }

    /// Appends a fresh page and returns it.
    @discardableResult
    func addPage(now: Date = .now) -> Page {
        let page = Page(title: Page.defaultTitle(for: now), createdAt: now)
        page.sortIndex = (pages.map(\.sortIndex).max() ?? -1) + 1
        page.notebook = self
        pages.append(page)
        updatedAt = now
        return page
    }
}

/// One spread: a reference slot on the left page, a sketch on the right page.
@Model
final class Page {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var sortIndex: Int

    /// `PKDrawing.dataRepresentation()`; empty data means an empty drawing.
    var drawingData: Data
    var paperStyleRaw: String
    /// `PaperTint` raw value: the paper's colour. Defaulted so older stores migrate.
    var paperTintRaw: String = PaperTint.automatic.rawValue
    /// JSON `[PageItem]`: stickers, photos and tape on the page. Defaulted so older stores migrate.
    var itemsData: Data = Data()
    /// `FieldWeather` raw value, empty if not set. Defaulted so older stores migrate.
    var weatherRaw: String = ""
    /// Written field notes. Defaulted so older stores migrate.
    var fieldNotes: String = ""
    /// JSON `[VoiceNote]`. Defaulted so older stores migrate.
    var voiceNotesData: Data = Data()

    // Field metadata
    var locationName: String
    var fieldDate: Date
    var tags: [String]

    /// Small JPEG rendered on autosave for the gallery grid. Kept out of the main store.
    @Attribute(.externalStorage)
    var thumbnailData: Data?

    var notebook: Notebook?

    @Relationship(deleteRule: .cascade, inverse: \ReferenceAsset.page)
    var reference: ReferenceAsset?

    init(title: String, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.sortIndex = 0
        self.drawingData = Data()
        self.paperStyleRaw = PaperStyle.dotted.rawValue
        self.locationName = ""
        self.fieldDate = createdAt
        self.tags = []
    }

    var paperStyle: PaperStyle {
        get { PaperStyle(rawValue: paperStyleRaw) ?? .dotted }
        set { paperStyleRaw = newValue.rawValue }
    }

    var paperTint: PaperTint {
        get { PaperTint(rawValue: paperTintRaw) ?? .automatic }
        set { paperTintRaw = newValue.rawValue }
    }

    var items: [PageItem] {
        get { (try? JSONDecoder().decode([PageItem].self, from: itemsData)) ?? [] }
        set { itemsData = newValue.isEmpty ? Data() : ((try? JSONEncoder().encode(newValue)) ?? Data()) }
    }

    var weather: FieldWeather? {
        get { FieldWeather(rawValue: weatherRaw) }
        set { weatherRaw = newValue?.rawValue ?? "" }
    }

    var voiceNotes: [VoiceNote] {
        get { (try? JSONDecoder().decode([VoiceNote].self, from: voiceNotesData)) ?? [] }
        set { voiceNotesData = newValue.isEmpty ? Data() : ((try? JSONEncoder().encode(newValue)) ?? Data()) }
    }

    /// The title a page gets when it is created: an auto timestamp.
    static func defaultTitle(for date: Date) -> String {
        "Page · " + date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    /// Case-insensitive match against the title and tags, used by gallery search.
    func matches(search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(query) { return true }
        let tagQuery = query.hasPrefix("#") ? String(query.dropFirst()) : query
        return tags.contains { $0.localizedCaseInsensitiveContains(tagQuery) }
    }
}

/// What sits in the reference slot of a page. Images live on disk; only the relative path is stored.
@Model
final class ReferenceAsset {
    var kindRaw: String
    /// Path relative to `ImageStore.root`, e.g. `References/6F1C….jpg`.
    var relativeImagePath: String?
    var notes: String
    var createdAt: Date
    var page: Page?

    init(kind: ReferenceKind, relativeImagePath: String? = nil, notes: String = "", createdAt: Date = .now) {
        self.kindRaw = kind.rawValue
        self.relativeImagePath = relativeImagePath
        self.notes = notes
        self.createdAt = createdAt
    }

    var kind: ReferenceKind {
        get { ReferenceKind(rawValue: kindRaw) ?? .notes }
        set { kindRaw = newValue.rawValue }
    }
}

/// Something stuck on a page, under or over the ink: a sticker, a photo, a video or a strip of tape.
/// Placed in page coordinates (`PageGeometry`); its height follows from its art.
struct PageItem: Codable, Identifiable, Equatable, Sendable {
    enum Content: Codable, Hashable, Sendable {
        /// An emoji, cut out with a white border.
        case sticker(String)
        /// A photo file, path relative to `ImageStore.root`.
        case photo(String)
        /// A short clip, path relative to `ImageStore.root`, its first frame beside it.
        case video(String)
        /// A strip of washi tape, by index into `PageItemArt.tapes`.
        case tape(Int)
    }

    var id: UUID
    var content: Content
    var center: CGPoint
    var width: CGFloat
    /// Radians, clockwise.
    var rotation: Double = 0
    /// Lies on top of the drawing rather than under it.
    var overInk = false
    /// How a photo or video is mounted.
    var frame = ItemFrame.print
    /// The color treatment of a photo or video.
    var look = ItemLook.original

    init(id: UUID = UUID(), content: Content, center: CGPoint, width: CGFloat, rotation: Double = 0, overInk: Bool = false,
         frame: ItemFrame = .print, look: ItemLook = .original) {
        self.id = id
        self.content = content
        self.center = center
        self.width = width
        self.rotation = rotation
        self.overInk = overInk
        self.frame = frame
        self.look = look
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, center, width, rotation, overInk, frame, look
    }

    /// Pages saved before items could sit over the ink have no `overInk`; they stay under it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(Content.self, forKey: .content)
        center = try container.decode(CGPoint.self, forKey: .center)
        width = try container.decode(CGFloat.self, forKey: .width)
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        overInk = try container.decodeIfPresent(Bool.self, forKey: .overInk) ?? false
        frame = try container.decodeIfPresent(ItemFrame.self, forKey: .frame) ?? .print
        look = try container.decodeIfPresent(ItemLook.self, forKey: .look) ?? .original
    }

    /// Photos and videos can change their frame and color.
    var canBeStyled: Bool {
        switch content {
        case .photo, .video: true
        case .sticker, .tape: false
        }
    }

    /// Bottom to top: the items under the ink, then those over it, each group in array order.
    static func stacked(_ items: [PageItem]) -> [PageItem] {
        items.filter { !$0.overInk } + items.filter(\.overInk)
    }

    /// Whether `point` (page coordinates) lands on this item when it is `size` big.
    func contains(_ point: CGPoint, size: CGSize) -> Bool {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let c = cos(-rotation)
        let s = sin(-rotation)
        let x = dx * c - dy * s
        let y = dx * s + dy * c
        return abs(x) <= size.width / 2 && abs(y) <= size.height / 2
    }
}

/// The weather noted on a page.
enum FieldWeather: String, CaseIterable, Identifiable, Sendable {
    case sunny
    case partlyCloudy
    case cloudy
    case rainy
    case stormy
    case snowy
    case windy
    case foggy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunny: "Sunny"
        case .partlyCloudy: "Partly Cloudy"
        case .cloudy: "Cloudy"
        case .rainy: "Rainy"
        case .stormy: "Stormy"
        case .snowy: "Snowy"
        case .windy: "Windy"
        case .foggy: "Foggy"
        }
    }

    var symbol: String {
        switch self {
        case .sunny: "sun.max"
        case .partlyCloudy: "cloud.sun"
        case .cloudy: "cloud"
        case .rainy: "cloud.rain"
        case .stormy: "cloud.bolt.rain"
        case .snowy: "cloud.snow"
        case .windy: "wind"
        case .foggy: "cloud.fog"
        }
    }
}

/// A short recording kept with a page, in a file beside its photos.
struct VoiceNote: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    /// Path relative to `ImageStore.root`.
    var path: String
    var date: Date
    /// Seconds.
    var duration: Double
}

/// How a photo or video is mounted on the page.
enum ItemFrame: String, Codable, CaseIterable, Identifiable, Sendable {
    case print
    case instant
    case film
    case kraft
    case rounded
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .print: "White Border"
        case .instant: "Instant Photo"
        case .film: "Film Strip"
        case .kraft: "Kraft Mat"
        case .rounded: "Rounded"
        case .none: "No Frame"
        }
    }

    /// Margins around the picture, as fractions of its longest side.
    var margins: (top: CGFloat, side: CGFloat, bottom: CGFloat) {
        switch self {
        case .print: (0.035, 0.035, 0.035)
        case .instant: (0.05, 0.05, 0.18)
        case .film: (0.09, 0.02, 0.09)
        case .kraft: (0.07, 0.07, 0.07)
        case .rounded, .none: (0, 0, 0)
        }
    }

    /// Corner radius of the `.rounded` frame, as a fraction of the picture's longest side.
    static let cornerRadius: CGFloat = 0.05

    /// Where the picture sits in framed art of size `art`.
    func photoRect(in art: CGSize) -> CGRect {
        let (top, side, bottom) = margins
        let across = side * 2
        let down = top + bottom
        var longest = art.width / (1 + across)
        if art.height - down * longest > longest { longest = art.height / (1 + down) }
        return CGRect(x: side * longest, y: top * longest,
                      width: art.width - across * longest, height: art.height - down * longest)
    }
}

/// A color treatment for a photo or video.
enum ItemLook: String, Codable, CaseIterable, Identifiable, Sendable {
    case original
    case blackAndWhite
    case noir
    case sepia
    case faded
    case vivid
    case warm
    case cool

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: "Original"
        case .blackAndWhite: "Black & White"
        case .noir: "Noir"
        case .sepia: "Sepia"
        case .faded: "Faded"
        case .vivid: "Vivid"
        case .warm: "Warm"
        case .cool: "Cool"
        }
    }

    private var filterName: String? {
        switch self {
        case .original: nil
        case .blackAndWhite: "CIPhotoEffectMono"
        case .noir: "CIPhotoEffectNoir"
        case .sepia: "CISepiaTone"
        case .faded: "CIPhotoEffectFade"
        case .vivid: "CIPhotoEffectChrome"
        case .warm: "CIPhotoEffectInstant"
        case .cool: "CIPhotoEffectProcess"
        }
    }

    func filtered(_ image: CIImage) -> CIImage {
        guard let filterName, let filter = CIFilter(name: filterName) else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }
}

enum ReferenceKind: String, CaseIterable, Sendable {
    case camera
    case library
    case notes
}

enum PaperStyle: String, CaseIterable, Identifiable, Sendable {
    case blank
    case dotted
    case grid
    case lined

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: "Blank"
        case .dotted: "Dotted"
        case .grid: "Grid"
        case .lined: "Lined"
        }
    }

    var symbol: String {
        switch self {
        case .blank: "square"
        case .dotted: "circle.grid.3x3"
        case .grid: "grid"
        case .lined: "line.3.horizontal"
        }
    }
}

enum FieldGuideSchema {
    static var models: [any PersistentModel.Type] { [Notebook.self, Page.self, ReferenceAsset.self] }
}

/// The colour of a page's paper. `automatic` is warm cream in light appearance and slate in dark;
/// the others stay the same whatever the device is set to.
enum PaperTint: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case cream
    case white
    case kraft
    case sage
    case night
    case blueprint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Match Device"
        case .cream: "Cream"
        case .white: "White"
        case .kraft: "Kraft"
        case .sage: "Sage"
        case .night: "Night"
        case .blueprint: "Blueprint"
        }
    }

    /// Whether the paper is light or dark. Ink is shown as it would be in that appearance, so
    /// PencilKit lightens dark inks on dark paper. `.unspecified` follows the device.
    var appearance: UIUserInterfaceStyle {
        switch self {
        case .automatic: .unspecified
        case .night, .blueprint: .dark
        case .cream, .white, .kraft, .sage: .light
        }
    }

    /// The paper colour for `traits` (only `automatic` depends on them).
    @MainActor
    func paperColor(for traits: UITraitCollection) -> UIColor {
        switch self {
        case .automatic: Theme.paperUIColor.resolvedColor(with: traits)
        case .cream: Theme.paperUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        case .white: UIColor(white: 1, alpha: 1)
        case .kraft: UIColor(red: 0.86, green: 0.78, blue: 0.63, alpha: 1)
        case .sage: UIColor(red: 0.87, green: 0.90, blue: 0.83, alpha: 1)
        case .night: Theme.paperUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        case .blueprint: UIColor(red: 0.13, green: 0.24, blue: 0.42, alpha: 1)
        }
    }

    /// Dots, grid and lines on this paper.
    @MainActor
    func ruleColor(for traits: UITraitCollection) -> UIColor {
        switch self {
        case .automatic: Theme.ruleUIColor.resolvedColor(with: traits)
        case .cream, .night: Theme.ruleUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: appearance))
        case .white, .kraft, .sage: UIColor(white: 0, alpha: 0.16)
        case .blueprint: UIColor(white: 1, alpha: 0.28)
        }
    }

    /// The appearance ink and paper are drawn in: the tint's own, or `fallback` for `automatic`.
    func resolvedAppearance(_ fallback: UIUserInterfaceStyle) -> UIUserInterfaceStyle {
        appearance == .unspecified ? fallback : appearance
    }
}
