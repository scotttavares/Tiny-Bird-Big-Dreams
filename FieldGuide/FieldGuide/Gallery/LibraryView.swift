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
    @State private var choosingCover: Notebook?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(notebooks) { notebook in
                    NavigationLink(value: notebook.id) {
                        NotebookRow(notebook: notebook, isCurrent: notebook.id == model.currentNotebook?.id)
                    }
                    .contextMenu {
                        Button("Change Cover", systemImage: "paintpalette") { choosingCover = notebook }
                        Button("Rename", systemImage: "pencil") { startRename(notebook) }
                        Button("Delete", systemImage: "trash", role: .destructive) { model.delete(notebook) }
                    }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) { model.delete(notebook) }
                        Button("Rename", systemImage: "pencil") { startRename(notebook) }
                            .tint(.accentColor)
                    }
                    .swipeActions(edge: .leading) {
                        Button("Cover", systemImage: "paintpalette") { choosingCover = notebook }
                            .tint(.brown)
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
                    // A new notebook starts by picking how it looks.
                    choosingCover = notebook
                }
            }
            .sheet(item: $choosingCover) { notebook in
                CoverPickerSheet(model: model, notebook: notebook)
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
            NotebookCoverArt(title: notebook.title, theme: notebook.theme, seed: notebook.id.uuidString)
                .frame(width: 44, height: 72)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 5, topTrailingRadius: 5))
                .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 2)
                .accessibilityHidden(true)
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

/// Chooses a notebook's cover: every design, drawn with the notebook's own title.
struct CoverPickerSheet: View {
    let model: AppModel
    let notebook: Notebook

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 160), spacing: 18)], spacing: 22) {
                    ForEach(NotebookTheme.allCases) { theme in
                        coverOption(theme)
                    }
                }
                .padding(20)
            }
            .background(Theme.chrome)
            .navigationTitle("Choose a Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func coverOption(_ theme: NotebookTheme) -> some View {
        let isSelected = notebook.theme == theme
        return Button {
            model.setTheme(theme, for: notebook)
        } label: {
            VStack(spacing: 8) {
                NotebookCoverArt(title: notebook.title, theme: theme, seed: notebook.id.uuidString)
                    .aspectRatio(NotebookCoverArt.designSize.width / NotebookCoverArt.designSize.height, contentMode: .fit)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3, bottomTrailingRadius: 8, topTrailingRadius: 8))
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 1, y: 2)
                    .overlay {
                        UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3, bottomTrailingRadius: 8, topTrailingRadius: 8)
                            .strokeBorder(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                            .padding(-5)
                    }
                Label(theme.name, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : Theme.inkText)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(theme.name) cover")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// Grid of page thumbnails, searchable by title and tag.
struct GalleryView: View {
    let model: AppModel
    let notebook: Notebook
    let onOpen: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isChoosingCover = false
    @State private var search = ""
    @State private var infoPage: Page?
    @State private var sharedFile: SharedFile?
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
                                ExportMenuItems(model: model, page: page, sharedFile: $sharedFile)
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
        // Say what this screen is (the notebook's pages) and where the back button goes.
        .navigationTitle("Pages")
        .navigationSubtitle(notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .searchable(text: $search, prompt: "Search titles and #tags")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Notebooks", systemImage: "chevron.backward")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityLabel("Back to Notebooks")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Cover", systemImage: "paintpalette") { isChoosingCover = true }
            }
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
        .sheet(isPresented: $isChoosingCover) {
            CoverPickerSheet(model: model, notebook: notebook)
        }
        .sheet(item: $sharedFile) { file in
            ShareSheet(file: file)
                .presentationDetents([.medium, .large])
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
