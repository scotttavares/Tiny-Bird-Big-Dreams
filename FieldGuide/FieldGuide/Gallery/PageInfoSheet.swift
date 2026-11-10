import SwiftUI

/// Title and field metadata for a page: location, date, tags, paper.
struct PageInfoSheet: View {
    let model: AppModel
    @Bindable var page: Page

    @Environment(\.dismiss) private var dismiss
    @State private var newTag = ""
    @State private var isLocating = false
    @State private var locationError: String?
    @State private var lookup = LocationLookup()

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $page.title)
                        .font(.headline)
                    LabeledContent("Created", value: page.createdAt.formatted(date: .abbreviated, time: .shortened))
                }

                Section {
                    TextField("Location name", text: $page.locationName)
                        .textContentType(.location)
                    Button {
                        Task { await useCurrentPlace() }
                    } label: {
                        HStack {
                            Label("Use Current Place", systemImage: "location")
                            if isLocating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLocating)
                    DatePicker("Date", selection: $page.fieldDate, displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Text("Field")
                } footer: {
                    if let locationError {
                        Text(locationError)
                    } else {
                        Text("Location is only looked up when you tap Use Current Place.")
                    }
                }

                Section("Tags") {
                    if !page.tags.isEmpty {
                        TagCloud(tags: page.tags) { tag in
                            page.tags.removeAll { $0 == tag }
                        }
                    }
                    HStack {
                        TextField("Add tag", text: $newTag)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit(addTag)
                        Button("Add", action: addTag)
                            .disabled(Tag.normalize(newTag) == nil)
                    }
                }

                Section("Paper") {
                    Picker("Paper style", selection: paperBinding) {
                        ForEach(PaperStyle.allCases) { style in
                            Label(style.title, systemImage: style.symbol).tag(style)
                        }
                    }
                }
            }
            .navigationTitle("Page Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        page.updatedAt = .now
                        model.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private var paperBinding: Binding<PaperStyle> {
        Binding {
            page.paperStyle
        } set: { style in
            if page.id == model.currentPage?.id {
                model.canvas.paperStyle = style
            } else {
                page.paperStyle = style
                model.refreshThumbnail(for: page)
            }
        }
    }

    private func addTag() {
        guard let tag = Tag.normalize(newTag) else { return }
        if !page.tags.contains(tag) {
            page.tags.append(tag)
        }
        newTag = ""
    }

    private func useCurrentPlace() async {
        isLocating = true
        locationError = nil
        defer { isLocating = false }
        do {
            page.locationName = try await lookup.currentPlaceName()
        } catch {
            locationError = error.localizedDescription
        }
    }
}

enum Tag {
    /// Lowercased, trimmed, without a leading "#". Nil when empty.
    static func normalize(_ raw: String) -> String? {
        var tag = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while tag.hasPrefix("#") { tag.removeFirst() }
        tag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        return tag.isEmpty ? nil : tag
    }
}

/// A scrolling row of tag chips.
struct TagCloud: View {
    let tags: [String]
    var onRemove: ((String) -> Void)?
    var onSelect: ((String) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        if let onSelect { onSelect(tag) } else { onRemove?(tag) }
                    } label: {
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                            if onRemove != nil {
                                Image(systemName: "xmark.circle.fill")
                                    .imageScale(.small)
                            }
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 32)
                        .background(Theme.paperEdge, in: .capsule)
                        .foregroundStyle(Theme.inkText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(onRemove != nil ? "Remove tag \(tag)" : "Tag \(tag)")
                }
            }
        }
    }
}
