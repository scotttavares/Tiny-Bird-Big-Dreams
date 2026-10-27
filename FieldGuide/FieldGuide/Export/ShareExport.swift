import SwiftUI
import UIKit

enum ExportKind: String, CaseIterable, Identifiable {
    case pagePNG
    case spreadPNG
    case notebookPDF

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pagePNG: "Share Page (PNG)"
        case .spreadPNG: "Share Spread (PNG)"
        case .notebookPDF: "Share Notebook (PDF)"
        }
    }

    var symbol: String {
        switch self {
        case .pagePNG: "photo"
        case .spreadPNG: "book.pages"
        case .notebookPDF: "doc.richtext"
        }
    }
}

/// A file ready for the share sheet.
struct SharedFile: Identifiable {
    let url: URL
    var id: URL { url }
}

extension AppModel {
    /// Renders an export to a temporary file. Defaults to the open page and its notebook.
    func exportFile(_ kind: ExportKind, page: Page? = nil) -> SharedFile? {
        guard let page = page ?? currentPage else { return nil }
        if page.id == currentPage?.id { canvas.flush() }

        func snapshot(_ page: Page) -> ExportPage {
            ExportPage(page: page, imageStore: imageStore, liveDrawing: page.id == currentPage?.id ? canvas.drawing : nil)
        }

        let url: URL?
        switch kind {
        case .pagePNG:
            url = try? ExportService.temporaryFile(data: ExportService.pagePNG(snapshot(page)), name: page.title, fileExtension: "png")
        case .spreadPNG:
            url = try? ExportService.temporaryFile(data: ExportService.spreadPNG(snapshot(page)), name: "\(page.title) spread", fileExtension: "png")
        case .notebookPDF:
            let notebook = page.notebook
            let pages = (notebook?.orderedPages ?? [page]).map(snapshot)
            let title = notebook?.title ?? page.title
            url = try? ExportService.temporaryFile(data: ExportService.notebookPDF(title: title, pages: pages), name: title, fileExtension: "pdf")
        }
        return url.map(SharedFile.init)
    }
}

/// `UIActivityViewController` for a rendered file.
struct ShareSheet: UIViewControllerRepresentable {
    let file: SharedFile

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Menu section with the three export options.
struct ExportMenuItems: View {
    let model: AppModel
    var page: Page?
    @Binding var sharedFile: SharedFile?

    var body: some View {
        Section("Export") {
            ForEach(ExportKind.allCases) { kind in
                Button(kind.title, systemImage: kind.symbol) {
                    sharedFile = model.exportFile(kind, page: page)
                }
            }
        }
    }
}
