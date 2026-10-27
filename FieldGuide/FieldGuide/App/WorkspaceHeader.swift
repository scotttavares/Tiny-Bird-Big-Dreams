import SwiftUI

/// Title bar for the current page. Lives on the left page in book posture and on the top
/// half in laptop posture, so it never crosses the hinge.
struct WorkspaceHeader: View {
    let model: AppModel
    let postureProvider: any PostureProvider
    let posture: Posture

    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 4) {
            pageTurnButton(offset: -1)
            titleBlock
            Spacer(minLength: 4)
            pageTurnButton(offset: 1)
            layoutMenu
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .foregroundStyle(Theme.inkText)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.currentPage?.title ?? "Field Guide")
                .font(.headline)
                .lineLimit(1)
            if let page = model.currentPage, let number = model.pageNumber(of: page) {
                Text("\(model.currentNotebook?.title ?? "") · \(number.index) of \(number.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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

    private var layoutMenu: some View {
        Menu {
            Button("New Page", systemImage: "plus") { model.newPage() }
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
