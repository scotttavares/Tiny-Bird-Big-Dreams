import Foundation
import SwiftData

/// A named collection of pages.
@Model
final class Notebook {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Page.notebook)
    var pages: [Page] = []

    init(title: String, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
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
