import PhotosUI
import SwiftUI
import UIKit

/// The left page: a photo or typed notes to sketch from.
struct ReferenceSlot: View {
    let model: AppModel

    @State private var photoItem: PhotosPickerItem?
    @State private var isPickingPhoto = false
    @State private var isShowingCamera = false
    @State private var isEditingNotes = false
    @State private var isExpanded = false
    @State private var notesDraft = ""

    private var reference: ReferenceAsset? { model.currentPage?.reference }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.paper)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 1)

            content
                .clipShape(.rect(cornerRadius: 14))
        }
        .overlay(alignment: .topTrailing) {
            if reference != nil {
                optionsMenu
                    .padding(8)
            }
        }
        .photosPicker(isPresented: $isPickingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                model.setReference(image: image.downscaled(maxDimension: 2400), kind: .camera)
            }
        }
        .fullScreenCover(isPresented: $isExpanded) {
            ExpandedReferenceView(model: model)
        }
        .sheet(isPresented: $isEditingNotes) {
            NotesEditor(text: $notesDraft) {
                model.setReference(notes: notesDraft)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let reference, let image = model.canvas.referenceImage, reference.kind != .notes {
            ZoomableImage(image: image) {
                isExpanded = true
            }
            .accessibilityLabel(reference.kind == .camera ? "Reference photo" : "Reference image")
            .accessibilityHint("Pinch to zoom. Use the Expand action to view full screen.")
        } else if let reference, reference.kind == .notes {
            ScrollView {
                Text(reference.notes.isEmpty ? "Tap to add notes" : reference.notes)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.inkText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .padding(.top, 28)
            }
            .contentShape(.rect)
            .onTapGesture { editNotes() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reference notes")
            .accessibilityValue(reference.notes)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double-tap to edit.")
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.rule)
                    .accessibilityHidden(true)
                Text("Add a reference")
                    .font(.headline)
                    .foregroundStyle(Theme.inkText)
                addButtons(axis: .vertical)
            }
            addButtons(axis: .horizontal)
        }
        .padding()
    }

    private func addButtons(axis: Axis) -> some View {
        let layout = axis == .vertical ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            Button {
                isShowingCamera = true
            } label: {
                Label("Camera", systemImage: "camera")
                    .frame(minWidth: 140, minHeight: 44)
            }
            Button {
                isPickingPhoto = true
            } label: {
                Label("Photos", systemImage: "photo")
                    .frame(minWidth: 140, minHeight: 44)
            }
            Button {
                editNotes()
            } label: {
                Label("Notes", systemImage: "text.alignleft")
                    .frame(minWidth: 140, minHeight: 44)
            }
        }
        .buttonStyle(.bordered)
        .tint(Theme.inkText)
    }

    private var optionsMenu: some View {
        Menu {
            Button("Take Photo", systemImage: "camera") { isShowingCamera = true }
            Button("Choose Photo", systemImage: "photo") { isPickingPhoto = true }
            Button("Edit Notes", systemImage: "text.alignleft") { editNotes() }
            if reference?.kind != .notes {
                Button("Expand", systemImage: "arrow.up.left.and.arrow.down.right") { isExpanded = true }
            }
            Divider()
            Button("Remove Reference", systemImage: "trash", role: .destructive) { model.removeReference() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: .circle)
        }
        .accessibilityLabel("Reference options")
    }

    private func editNotes() {
        notesDraft = reference?.kind == .notes ? (reference?.notes ?? "") : ""
        isEditingNotes = true
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        model.setReference(image: image.downscaled(maxDimension: 2400), kind: .library)
    }
}

/// Pinch to zoom, drag when zoomed, tap to expand, double-tap to reset the zoom.
struct ZoomableImage: View {
    let image: UIImage
    var onExpand: (() -> Void)?

    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(.rect)
                .gesture(magnify.simultaneously(with: pan))
                .onTapGesture(count: 2) {
                    withAnimation(.smooth) { reset() }
                }
                .onTapGesture {
                    onExpand?()
                }
        }
        .clipped()
        .accessibilityElement()
        .accessibilityAddTraits(.isImage)
        .accessibilityAction(named: "Expand") { onExpand?() }
        .accessibilityAction(named: "Reset zoom") { reset() }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(committedScale * value.magnification, 1), 8)
            }
            .onEnded { _ in
                committedScale = scale
                if scale <= 1.01 {
                    withAnimation(.smooth) { reset() }
                }
            }
    }

    private var pan: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(width: committedOffset.width + value.translation.width,
                                height: committedOffset.height + value.translation.height)
            }
            .onEnded { _ in
                committedOffset = offset
            }
    }

    private func reset() {
        scale = 1
        committedScale = 1
        offset = .zero
        committedOffset = .zero
    }
}

/// Tap-to-expand view of the reference image.
struct ExpandedReferenceView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let image = model.canvas.referenceImage {
                    ZoomableImage(image: image)
                } else {
                    ContentUnavailableView("No Reference Image", systemImage: "photo")
                }
            }
            .background(Color.black)
            .navigationTitle(model.currentPage?.title ?? "Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct NotesEditor: View {
    @Binding var text: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.system(.body, design: .serif))
                .scrollContentBackground(.hidden)
                .padding()
                .background(Theme.paper)
                .accessibilityLabel("Reference notes")
                .navigationTitle("Reference Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave()
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

extension UIImage {
    /// Keeps reference files a sensible size on disk.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let factor = maxDimension / longest
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        return preparingThumbnail(of: target) ?? self
    }
}
