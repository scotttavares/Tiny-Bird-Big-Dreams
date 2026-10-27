import SwiftData
import SwiftUI

/// Notebooks → gallery. Presented as a sheet from the workspace so the canvas stays alive.
struct LibraryView: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Notebook.updatedAt, order: .reverse) private var notebooks: [Notebook]
    @State private var path: [UUID] = []
    @State private var renaming: Notebook?
    @State private var renameText = ""
    @State private var isCreating = false
    @State private var newTitle = ""

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(notebooks) { notebook in
                    NavigationLink(value: notebook.id) {
                        NotebookRow(notebook: notebook, isCurrent: notebook.id == model.currentNotebook?.id)
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") { startRename(notebook) }
                        Button("Delete", systemImage: "trash", role: .destructive) { model.delete(notebook) }
                    }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) { model.delete(notebook) }
                        Button("Rename", systemImage: "pencil") { startRename(notebook) }
                            .tint(.accentColor)
                    }
                }
            }
            .navigationTitle("Notebooks")
            .navigationDestination(for: UUID.self) { id in
                if let notebook = notebooks.first(where: { $0.id == id }) {
                    GalleryView(model: model, notebook: notebook) { dismiss() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Notebook", systemImage: "plus") {
                        newTitle = ""
                        isCreating = true
                    }
                }
            }
            .alert("New Notebook", isPresented: $isCreating) {
                TextField("Title", text: $newTitle)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let notebook = model.createNotebook(title: title.isEmpty ? "Untitled Notebook" : title)
                    path = [notebook.id]
                }
            }
            .alert("Rename Notebook", isPresented: renameBinding) {
                TextField("Title", text: $renameText)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Rename") {
                    if let renaming { model.rename(renaming, to: renameText) }
                    renaming = nil
                }
            }
        }
        .onAppear {
            if let current = model.currentNotebook, path.isEmpty {
                path = [current.id]
            }
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding { renaming != nil } set: { if !$0 { renaming = nil } }
    }

    private func startRename(_ notebook: Notebook) {
        renameText = notebook.title
        renaming = notebook
    }
}

private struct NotebookRow: View {
    let notebook: Notebook
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let cover = notebook.orderedPages.first {
                PageThumbnail(page: cover)
                    .frame(width: 44, height: 60)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.paper)
                    .frame(width: 44, height: 60)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(notebook.title)
                    .font(.headline)
                Text("\(notebook.pages.count) pages · \(notebook.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if isCurrent {
                Spacer()
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Open notebook")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Grid of page thumbnails, searchable by title and tag.
struct GalleryView: View {
    let model: AppModel
    let notebook: Notebook
    let onOpen: () -> Void

    @State private var search = ""
    @State private var infoPage: Page?
    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 150

    private var pages: [Page] {
        notebook.orderedPages.filter { $0.matches(search: search) }
    }

    private var allTags: [String] {
        Array(Set(notebook.pages.flatMap(\.tags))).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !allTags.isEmpty {
                    TagCloud(tags: allTags, onSelect: { tag in search = "#\(tag)" })
                        .padding(.horizontal)
                }
                if pages.isEmpty {
                    ContentUnavailableView.search(text: search)
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 16)], spacing: 20) {
                        ForEach(pages) { page in
                            Button {
                                model.open(page)
                                onOpen()
                            } label: {
                                GalleryTile(page: page, isCurrent: page.id == model.currentPage?.id)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Page Info", systemImage: "info.circle") { infoPage = page }
                                Button("Delete Page", systemImage: "trash", role: .destructive) { model.delete(page) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Theme.chrome)
        .navigationTitle(notebook.title)
        .searchable(text: $search, prompt: "Search titles and #tags")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Page", systemImage: "square.and.pencil") {
                    model.newPage(in: notebook)
                    onOpen()
                }
            }
        }
        .sheet(item: $infoPage) { page in
            PageInfoSheet(model: model, page: page)
        }
    }
}

private struct GalleryTile: View {
    let page: Page
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PageThumbnail(page: page)
                .aspectRatio(PageGeometry.size.width / PageGeometry.size.height, contentMode: .fit)
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                    }
                }
                .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
            Text(page.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.inkText)
                .lineLimit(2)
            Text(page.fieldDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !page.tags.isEmpty {
                Text(page.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(isCurrent ? "Currently open" : "Opens this page")
    }
}
