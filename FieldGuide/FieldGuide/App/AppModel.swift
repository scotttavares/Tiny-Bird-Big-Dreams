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
    /// Set by the page view: starts an animated page-turn and returns true, or returns false to
    /// let the page change happen straight away (Reduce Motion, nothing to turn to).
    @ObservationIgnored var pageTurnHandler: (@MainActor (Int) -> Bool)?

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
        canvas.onPaperTintChange = { [weak self] tint in
            guard let page = self?.currentPage else { return }
            page.paperTint = tint
            self?.refreshThumbnail(for: page)
            self?.save()
        }
        canvas.onTurnPage = { [weak self] offset in
            self?.turnPage(by: offset)
        }
        PageItemArt.imageStore = imageStore
        canvas.onItemsChange = { [weak self] items in
            guard let page = self?.currentPage else { return }
            page.items = items
            page.updatedAt = .now
            page.notebook?.updatedAt = .now
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
        let count = (try? context.fetchCount(FetchDescriptor<Notebook>())) ?? 0
        notebook.theme = NotebookTheme.next(after: count)
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

    func setTheme(_ theme: NotebookTheme, for notebook: Notebook) {
        notebook.theme = theme
        notebook.updatedAt = .now
        save()
    }

    /// The open notebook's number on the shelf (oldest is № 1), printed on some covers.
    var notebookNumber: Int {
        guard let currentNotebook else { return 1 }
        let all = (try? context.fetch(FetchDescriptor<Notebook>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        return (all.firstIndex { $0.id == currentNotebook.id } ?? 0) + 1
    }

    func delete(_ notebook: Notebook) {
        for page in notebook.pages {
            deleteFiles(of: page)
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
            paperTint: page.paperTint,
            items: page.items,
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
        page.paperTint = canvas.paperTint
        save()
        open(page)
        return page
    }

    func delete(_ page: Page) {
        deleteFiles(of: page)
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
        if let pageTurnHandler, pageTurnHandler(offset) { return }
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
            announceOutOfSpace()
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

    // MARK: Stickers and photos

    func addItem(_ content: PageItem.Content, at point: CGPoint? = nil) {
        switch content {
        case .sticker: canvas.add(content, width: 150, tilt: 0.15, at: point)
        case .tape: canvas.add(content, width: 300, tilt: 0.35, at: point)
        case .photo, .video: canvas.add(content, width: 380, tilt: 0.08, at: point)
        }
    }

    /// Saves `image` and sticks it on the page, at `point` (page coordinates) if given.
    func addPhoto(_ image: UIImage, at point: CGPoint? = nil) {
        guard currentPage != nil else { return }
        guard let path = try? imageStore.save(image) else {
            announceOutOfSpace()
            return
        }
        addItem(.photo(path), at: point)
    }

    /// Sticks a copy of the reference photo on the page: dragged across the hinge.
    func stickReferencePhoto(at point: CGPoint) {
        guard let image = canvas.referenceImage else { return }
        addPhoto(image, at: point)
    }

    /// Makes a short clip from the video at `source` and sticks it on the page.
    func addVideo(from source: URL) async -> Bool {
        guard currentPage != nil, let path = try? imageStore.newVideoPath() else { return false }
        do {
            let poster = try await VideoClip.prepare(source, to: imageStore.url(for: path))
            try imageStore.savePoster(poster, forVideo: path)
            addItem(.video(path))
            return true
        } catch {
            imageStore.deleteVideo(path)
            return false
        }
    }

    /// Copies an item from the previous page onto this one, at `point` (page coordinates).
    func copyPreviousItem(_ id: UUID, at point: CGPoint) {
        guard var item = previousPage?.items.first(where: { $0.id == id }) else { return }
        do {
            switch item.content {
            case .photo(let path): item.content = .photo(try imageStore.copy(path))
            case .video(let path): item.content = .video(try imageStore.copyVideo(path))
            case .sticker, .tape: break
            }
        } catch {
            announceOutOfSpace()
            return
        }
        item.id = UUID()
        item.center = point
        item.overInk = true
        canvas.place(item)
    }

    func deleteVoiceNote(_ note: VoiceNote, from page: Page) {
        imageStore.delete(note.path)
        page.voiceNotes.removeAll { $0.id == note.id }
        save()
    }

    func deleteItem(_ id: UUID) {
        if let removed = canvas.removeItem(id) { deleteFile(of: removed) }
    }

    private func deleteFile(of item: PageItem) {
        switch item.content {
        case .photo(let path): imageStore.delete(path)
        case .video(let path): imageStore.deleteVideo(path)
        case .sticker, .tape: break
        }
    }

    private func deleteFiles(of page: Page) {
        imageStore.delete(page.reference?.relativeImagePath)
        for note in page.voiceNotes {
            imageStore.delete(note.path)
        }
        for item in page.items {
            deleteFile(of: item)
        }
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
        page.thumbnailData = PageRenderer.thumbnailData(drawing: drawing, paperStyle: page.paperStyle,
                                                        paperTint: page.paperTint, items: page.items)
        save()
    }

    func refreshThumbnail(for page: Page) {
        let isOpen = page.id == currentPage?.id
        let drawing = isOpen ? canvas.drawing : CanvasStore.decode(page.drawingData)
        page.thumbnailData = PageRenderer.thumbnailData(drawing: drawing, paperStyle: page.paperStyle, paperTint: page.paperTint,
                                                        items: isOpen ? canvas.items : page.items)
    }

    /// Flushes pending strokes and writes the store. Called on scene phase changes.
    func flushAll() {
        canvas.flush()
        save()
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            announceOutOfSpace()
        }
    }

    private func announceOutOfSpace() {
        canvas.announce("Couldn't save. Your phone may be out of space.", for: 4)
    }

    // MARK: Deep links

    func handle(url: URL) {
        guard url.scheme == "fieldguide" else { return }
        if url.host() == "new-page" {
            newPage()
        }
    }
}
