import Observation
import PencilKit
import SwiftData
import SwiftUI

/// App-wide state: which notebook and page are open, plus the one `CanvasStore`.
///
/// The canvas store lives here, above every posture layout, so folding and unfolding
/// only moves views around; the drawing, tool and undo history never leave this object.
@MainActor
@Observable
final class AppModel {
    let context: ModelContext
    let canvas: CanvasStore
    let imageStore: ImageStore

    private(set) var currentNotebook: Notebook?
    private(set) var currentPage: Page?
    /// Bumped on every page change; drives the page-turn animation and haptic.
    private(set) var pageTurnCount = 0
    private(set) var lastTurnDirection: Int = 1

    init(context: ModelContext, canvas: CanvasStore = CanvasStore(), imageStore: ImageStore = .standard) {
        self.context = context
        self.canvas = canvas
        self.imageStore = imageStore
        canvas.onPersist = { [weak self] pageID, drawing in
            self?.persist(drawing: drawing, pageID: pageID)
        }
        canvas.onPaperStyleChange = { [weak self] style in
            guard let page = self?.currentPage else { return }
            page.paperStyle = style
            self?.refreshThumbnail(for: page)
            self?.save()
        }
    }

    // MARK: Startup

    /// Opens the most recently edited page, creating a first notebook and page if needed.
    func bootstrap(seedDemo: Bool = false) {
        if seedDemo {
            DemoContent.seed(into: context, imageStore: imageStore)
        }
        let notebooks = (try? context.fetch(FetchDescriptor<Notebook>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
        let notebook = notebooks.first ?? createNotebook(title: "Field Notes")
        let page = notebook.pages.max { $0.updatedAt < $1.updatedAt } ?? notebook.addPage()
        save()
        open(page)
    }

    // MARK: Notebooks

    @discardableResult
    func createNotebook(title: String) -> Notebook {
        let notebook = Notebook(title: title)
        context.insert(notebook)
        save()
        return notebook
    }

    func rename(_ notebook: Notebook, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notebook.title = trimmed
        notebook.updatedAt = .now
        save()
    }

    func delete(_ notebook: Notebook) {
        for page in notebook.pages {
            imageStore.delete(page.reference?.relativeImagePath)
        }
        let wasCurrent = notebook.id == currentNotebook?.id
        context.delete(notebook)
        save()
        if wasCurrent {
            currentPage = nil
            currentNotebook = nil
            bootstrap()
        }
    }

    // MARK: Pages

    func open(_ page: Page, direction: Int = 1) {
        guard page.id != currentPage?.id else { return }
        canvas.flush()
        currentPage = page
        currentNotebook = page.notebook
        lastTurnDirection = direction
        pageTurnCount += 1
        canvas.load(
            pageID: page.id,
            drawingData: page.drawingData,
            paperStyle: page.paperStyle,
            referenceImage: imageStore.image(at: page.reference?.relativeImagePath)
        )
        if canvas.referenceImage == nil {
            canvas.isTracing = false
        }
    }

    /// One-tap new page in the current notebook (closed-posture capture, widget deep link).
    @discardableResult
    func newPage(in notebook: Notebook? = nil) -> Page {
        let target = notebook ?? currentNotebook ?? createNotebook(title: "Field Notes")
        let page = target.addPage()
        page.paperStyle = canvas.paperStyle
        save()
        open(page)
        return page
    }

    func delete(_ page: Page) {
        imageStore.delete(page.reference?.relativeImagePath)
        let notebook = page.notebook
        let wasCurrent = page.id == currentPage?.id
        context.delete(page)
        save()
        if wasCurrent {
            currentPage = nil
            if let next = notebook?.orderedPages.last {
                open(next)
            } else {
                newPage(in: notebook)
            }
        }
    }

    var previousPage: Page? { neighbor(offset: -1) }
    var nextPage: Page? { neighbor(offset: 1) }

    func turnPage(by offset: Int) {
        guard let page = neighbor(offset: offset) else { return }
        open(page, direction: offset)
    }

    private func neighbor(offset: Int) -> Page? {
        guard let currentPage, let pages = currentNotebook?.orderedPages,
              let index = pages.firstIndex(where: { $0.id == currentPage.id }) else { return nil }
        let target = index + offset
        return pages.indices.contains(target) ? pages[target] : nil
    }

    func pageNumber(of page: Page) -> (index: Int, count: Int)? {
        guard let pages = page.notebook?.orderedPages,
              let index = pages.firstIndex(where: { $0.id == page.id }) else { return nil }
        return (index + 1, pages.count)
    }

    // MARK: Reference slot

    func setReference(image: UIImage, kind: ReferenceKind) {
        guard let page = currentPage else { return }
        do {
            let path = try imageStore.save(image)
            replaceReference(on: page, with: ReferenceAsset(kind: kind, relativeImagePath: path))
            canvas.referenceImage = image
        } catch {
            // Leave the slot unchanged if the file can't be written.
        }
    }

    func setReference(notes: String) {
        guard let page = currentPage else { return }
        if let existing = page.reference, existing.kind == .notes {
            existing.notes = notes
            page.updatedAt = .now
            save()
        } else {
            replaceReference(on: page, with: ReferenceAsset(kind: .notes, notes: notes))
            canvas.referenceImage = nil
            canvas.isTracing = false
        }
    }

    func removeReference() {
        guard let page = currentPage, let reference = page.reference else { return }
        imageStore.delete(reference.relativeImagePath)
        page.reference = nil
        context.delete(reference)
        canvas.referenceImage = nil
        canvas.isTracing = false
        page.updatedAt = .now
        save()
    }

    private func replaceReference(on page: Page, with asset: ReferenceAsset) {
        if let old = page.reference {
            imageStore.delete(old.relativeImagePath)
            context.delete(old)
        }
        context.insert(asset)
        page.reference = asset
        page.updatedAt = .now
        save()
    }

    // MARK: Persistence

    private func persist(drawing: PKDrawing, pageID: UUID) {
        let page: Page?
        if currentPage?.id == pageID {
            page = currentPage
        } else {
            page = try? context.fetch(FetchDescriptor<Page>(predicate: #Predicate { $0.id == pageID })).first
        }
        guard let page else { return }
        page.drawingData = CanvasStore.encode(drawing)
        page.updatedAt = .now
        page.notebook?.updatedAt = .now
        page.thumbnailData = PageRenderer.thumbnailData(drawing: drawing, paperStyle: page.paperStyle)
        save()
    }

    func refreshThumbnail(for page: Page) {
        let drawing = page.id == currentPage?.id ? canvas.drawing : CanvasStore.decode(page.drawingData)
        page.thumbnailData = PageRenderer.thumbnailData(drawing: drawing, paperStyle: page.paperStyle)
    }

    /// Flushes pending strokes and writes the store. Called on scene phase changes.
    func flushAll() {
        canvas.flush()
        save()
    }

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }

    // MARK: Deep links

    func handle(url: URL) {
        guard url.scheme == "fieldguide" else { return }
        if url.host() == "new-page" {
            newPage()
        }
    }
}
