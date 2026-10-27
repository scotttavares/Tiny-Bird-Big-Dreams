import Foundation
import SwiftData
import Testing
import UIKit
@testable import FieldGuide

@MainActor
@Suite("Models, search and tags")
struct ModelTests {
    @Test func searchMatchesTitleAndTags() {
        let page = Page(title: "Lady fern, creek bank")
        page.tags = ["fern", "riparian"]
        #expect(page.matches(search: ""))
        #expect(page.matches(search: "creek"))
        #expect(page.matches(search: "FERN"))
        #expect(page.matches(search: "#ripar"))
        #expect(!page.matches(search: "bird"))
    }

    @Test(arguments: [
        ("  #Fern ", "fern"),
        ("##Moss", "moss"),
        ("Bird Song", "bird song"),
    ])
    func tagNormalization(raw: String, expected: String) {
        #expect(Tag.normalize(raw) == expected)
    }

    @Test func emptyTagIsRejected() {
        #expect(Tag.normalize("   ") == nil)
        #expect(Tag.normalize("#") == nil)
    }

    @Test func pagesAreOrderedAndTitledWithTimestamp() {
        let notebook = Notebook(title: "Walk")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = notebook.addPage(now: date)
        let second = notebook.addPage(now: date.addingTimeInterval(60))
        #expect(notebook.orderedPages.map(\.id) == [first.id, second.id])
        #expect(first.title.hasPrefix("Page · "))
        #expect(second.sortIndex == first.sortIndex + 1)
        #expect(first.fieldDate == date)
    }

    @Test func imageStoreUsesRelativePaths() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ImageStore(root: root)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let path = try store.save(image)
        #expect(path.hasPrefix("References/"))
        #expect(!path.hasPrefix("/"))
        #expect(store.image(at: path) != nil)
        store.delete(path)
        #expect(store.image(at: path) == nil)
        try? FileManager.default.removeItem(at: root)
    }

    @Test func appModelBootstrapsNotebookAndAppliesReferences() throws {
        let container = try ModelContainer(
            for: Schema(FieldGuideSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let model = AppModel(context: container.mainContext, imageStore: ImageStore(root: root))
        model.bootstrap()

        let page = try #require(model.currentPage)
        #expect(model.currentNotebook?.title == "Field Notes")

        model.setReference(notes: "Two white wing bars")
        #expect(page.reference?.kind == .notes)
        #expect(page.reference?.notes == "Two white wing bars")

        let second = model.newPage()
        #expect(model.currentPage?.id == second.id)
        #expect(model.previousPage?.id == page.id)
        model.turnPage(by: -1)
        #expect(model.currentPage?.id == page.id)
        try? FileManager.default.removeItem(at: root)
    }
}
