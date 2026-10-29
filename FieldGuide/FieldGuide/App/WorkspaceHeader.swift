import SwiftUI

/// Title bar for the current page. Lives on the left page in book posture and on the top
/// half in laptop posture, so it never crosses the hinge.
///
/// - Closed: quick capture. Last-page peek, camera shortcut and a one-tap new page.
/// - Tent: the page title and a large "Return to draw" prompt.
/// - Book/laptop: page navigation and the full menu.
struct WorkspaceHeader: View {
    let model: AppModel
    let postureProvider: any PostureProvider
    let posture: Posture
    let onReturnToDraw: () -> Void

    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 44
    @State private var isShowingCamera = false
    @State private var isShowingReference = false
    @State private var isShowingLibrary = false
    @State private var infoPage: Page?
    @State private var sharedFile: SharedFile?

    var body: some View {
        Group {
            switch posture {
            case .tent:
                tentBar
            case .closed:
                closedBar
            case .book, .laptop:
                openBar
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .foregroundStyle(Theme.inkText)
        .sheet(isPresented: $isShowingLibrary) {
            LibraryView(model: model)
        }
        .sheet(item: $infoPage) { page in
            PageInfoSheet(model: model, page: page)
        }
        .sheet(item: $sharedFile) { file in
            ShareSheet(file: file)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                model.setReference(image: image.downscaled(maxDimension: 2400), kind: .camera)
                // Folded, there's no reference page to show it on, so show it under the sketch.
                model.canvas.isTracing = true
            }
        }
        .fullScreenCover(isPresented: $isShowingReference) {
            ExpandedReferenceView(model: model)
        }
    }

    // MARK: Bars

    private var openBar: some View {
        HStack(spacing: 4) {
            libraryButton
            pageTurnButton(offset: -1)
            titleBlock
            Spacer(minLength: 4)
            pageTurnButton(offset: 1)
            moreMenu
        }
    }

    private var closedBar: some View {
        HStack(spacing: 4) {
            libraryButton
            lastPagePeek
            titleBlock
            Spacer(minLength: 4)
            referencePeek
            Button {
                isShowingCamera = true
            } label: {
                Image(systemName: "camera")
                    .font(.title3)
                    .frame(width: buttonSize, height: buttonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Capture reference photo")
            Button {
                model.newPage()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(Color.accentColor, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New page")
            moreMenu
        }
    }

    private var tentBar: some View {
        HStack(spacing: 12) {
            titleText
                .padding(.leading, 8)
            Spacer(minLength: 8)
            Button(action: onReturnToDraw) {
                Label("Return to draw", systemImage: "pencil.tip.crop.circle")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .frame(minHeight: buttonSize)
                    .foregroundStyle(Theme.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Leaves presentation mode so you can keep sketching.")
        }
    }

    // MARK: Pieces

    private var libraryButton: some View {
        Button {
            isShowingLibrary = true
        } label: {
            Image(systemName: "books.vertical")
                .font(.title3)
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notebooks and gallery")
    }

    private var titleBlock: some View {
        Button {
            infoPage = model.currentPage
        } label: {
            titleText
        }
        .buttonStyle(.plain)
        .accessibilityHint("Edits the title, place, date and tags.")
    }

    private var titleText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.currentPage?.title ?? "Field Guide")
                .font(.headline)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var subtitle: String? {
        guard let page = model.currentPage else { return nil }
        var parts: [String] = []
        if posture == .tent {
            parts.append(page.fieldDate.formatted(date: .abbreviated, time: .omitted))
            if !page.locationName.isEmpty { parts.append(page.locationName) }
        } else {
            if let notebook = model.currentNotebook { parts.append(notebook.title) }
            if let number = model.pageNumber(of: page) { parts.append("\(number.index) of \(number.count)") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var lastPagePeek: some View {
        if let previous = model.previousPage {
            Button {
                model.turnPage(by: -1)
            } label: {
                PageThumbnail(page: previous)
                    .frame(width: buttonSize * 0.75, height: buttonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous page: \(previous.title)")
        }
    }

    /// Folded, the reference page is hidden: the photo shows here instead.
    /// Tap to view it full screen; press and hold for tracing, retake and remove.
    @ViewBuilder
    private var referencePeek: some View {
        if let image = model.canvas.referenceImage, model.currentPage?.reference?.kind != .notes {
            Menu {
                Button("View Photo", systemImage: "arrow.up.left.and.arrow.down.right") { isShowingReference = true }
                Toggle("Trace Over It", systemImage: "square.on.square",
                       isOn: Binding { model.canvas.isTracing } set: { model.canvas.isTracing = $0 })
                Button("Retake", systemImage: "camera") { isShowingCamera = true }
                Divider()
                Button("Remove Photo", systemImage: "trash", role: .destructive) { model.removeReference() }
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: buttonSize * 0.8, height: buttonSize)
                    .clipShape(.rect(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(model.canvas.isTracing ? Color.accentColor : Theme.rule, lineWidth: model.canvas.isTracing ? 2 : 0.5)
                    }
            } primaryAction: {
                isShowingReference = true
            }
            .accessibilityLabel("Reference photo")
            .accessibilityHint("Opens the photo. Press and hold for tracing and more.")
        }
    }

    private func pageTurnButton(offset: Int) -> some View {
        Button {
            model.turnPage(by: offset)
        } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
                .font(.body.weight(.semibold))
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(.plain)
        .disabled(offset < 0 ? model.previousPage == nil : model.nextPage == nil)
        .accessibilityLabel(offset < 0 ? "Previous page" : "Next page")
    }

    private var moreMenu: some View {
        Menu {
            Button("New Page", systemImage: "plus") { model.newPage() }
            Button("Page Info", systemImage: "info.circle") { infoPage = model.currentPage }
            Menu("Paper", systemImage: "doc.plaintext") {
                Picker("Paper Color", selection: Binding { model.canvas.paperTint } set: { model.canvas.paperTint = $0 }) {
                    ForEach(PaperTint.allCases) { tint in
                        Text(tint.title).tag(tint)
                    }
                }
                Picker("Pattern", selection: Binding { model.canvas.paperStyle } set: { model.canvas.paperStyle = $0 }) {
                    ForEach(PaperStyle.allCases) { style in
                        Label(style.title, systemImage: style.symbol).tag(style)
                    }
                }
            }
            Button("Present", systemImage: "triangle") { postureProvider.override = .tent }
            ExportMenuItems(model: model, sharedFile: $sharedFile)
            Section("Layout") {
                Button {
                    postureProvider.override = nil
                } label: {
                    Label("Automatic", systemImage: postureProvider.override == nil ? "checkmark" : "rectangle.split.2x1")
                }
                ForEach(Posture.allCases) { option in
                    Button {
                        postureProvider.override = option
                    } label: {
                        Label(option.title, systemImage: postureProvider.override == option ? "checkmark" : option.symbol)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(width: buttonSize, height: buttonSize)
        }
        .accessibilityLabel("More")
    }
}

/// A page's gallery thumbnail on paper.
struct PageThumbnail: View {
    let page: Page

    var body: some View {
        ZStack {
            Theme.paper
            if let data = page.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipShape(.rect(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Theme.rule, lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }
}
