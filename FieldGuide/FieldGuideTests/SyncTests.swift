import CoreData
import Foundation
import SwiftData
import Testing
@testable import FieldGuide

/// The store as builds up to 22 shipped it, to prove those notebooks open after the iCloud change.
enum StoreBeforeICloud: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Notebook.self, Page.self, ReferenceAsset.self] }

    @Model
    final class Notebook {
        var id: UUID
        var title: String
        var createdAt: Date
        var updatedAt: Date
        var themeRaw: String = "pines"
        @Relationship(deleteRule: .cascade, inverse: \Page.notebook)
        var pages: [Page] = []

        init(title: String) {
            id = UUID()
            self.title = title
            createdAt = .now
            updatedAt = .now
        }
    }

    @Model
    final class Page {
        var id: UUID
        var title: String
        var createdAt: Date
        var updatedAt: Date
        var sortIndex: Int
        var drawingData: Data
        var paperStyleRaw: String
        var paperTintRaw: String = "automatic"
        var itemsData: Data = Data()
        var weatherRaw: String = ""
        var fieldNotes: String = ""
        var voiceNotesData: Data = Data()
        var locationName: String
        var fieldDate: Date
        var tags: [String]
        @Attribute(.externalStorage)
        var thumbnailData: Data?
        var notebook: Notebook?
        @Relationship(deleteRule: .cascade, inverse: \ReferenceAsset.page)
        var reference: ReferenceAsset?

        init(title: String) {
            id = UUID()
            self.title = title
            createdAt = .now
            updatedAt = .now
            sortIndex = 0
            drawingData = Data([1, 2, 3])
            paperStyleRaw = "grid"
            locationName = "Trail"
            fieldDate = .now
            tags = ["fern"]
        }
    }

    @Model
    final class ReferenceAsset {
        var kindRaw: String
        var relativeImagePath: String?
        var notes: String
        var createdAt: Date
        var page: Page?

        init(notes: String) {
            kindRaw = "notes"
            self.notes = notes
            createdAt = .now
        }
    }
}

@MainActor
struct SyncTests {
    private func temporaryDirectory() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func memoryContext() throws -> ModelContext {
        let container = try ModelContainer(for: Schema(FieldGuideSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    /// iCloud refuses a store with a required value that has no default, a required relationship,
    /// or a unique attribute. An unsigned test run can't reach it, so check its rules here.
    @Test func theStoreFollowsICloudRules() throws {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: FieldGuideSchema.models))
        for entity in model.entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name ?? "")")
            for attribute in entity.attributesByName.values {
                #expect(attribute.isOptional || attribute.defaultValue != nil, "\(entity.name ?? "").\(attribute.name)")
            }
            for relationship in entity.relationshipsByName.values {
                #expect(relationship.isOptional, "\(entity.name ?? "").\(relationship.name)")
                #expect(relationship.inverseRelationship != nil, "\(entity.name ?? "").\(relationship.name)")
                #expect(relationship.deleteRule != .denyDeleteRule, "\(entity.name ?? "").\(relationship.name)")
            }
        }
    }

    @Test func notebooksFromBeforeICloudStillOpen() throws {
        let url = try temporaryDirectory().appending(path: "old.store")
        do {
            let container = try ModelContainer(for: Schema(versionedSchema: StoreBeforeICloud.self),
                                               configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let notebook = StoreBeforeICloud.Notebook(title: "Spring Walk")
            context.insert(notebook)
            let page = StoreBeforeICloud.Page(title: "Fern")
            page.notebook = notebook
            page.reference = StoreBeforeICloud.ReferenceAsset(notes: "Ferny")
            try context.save()
        }

        let container = try ModelContainer(for: Schema(FieldGuideSchema.models),
                                           configurations: ModelConfiguration(url: url))
        let notebook = try #require(try ModelContext(container).fetch(FetchDescriptor<FieldGuide.Notebook>()).first)
        #expect(notebook.title == "Spring Walk")
        #expect(!notebook.isStarter)
        let page = try #require(notebook.allPages.first)
        #expect(page.title == "Fern")
        #expect(page.drawingData == Data([1, 2, 3]))
        #expect(page.tags == ["fern"])
        #expect(page.reference?.notes == "Ferny")
    }

    @Test func anEmptyStarterGivesWayToRealNotebooks() throws {
        let context = try memoryContext()
        let starter = Notebook(title: "Field Notes")
        starter.isStarter = true
        starter.addPage()
        let real = Notebook(title: "Field Notes")
        real.addPage().fieldNotes = "A wren"
        context.insert(starter)
        context.insert(real)
        #expect(Notebook.redundantStarters(in: [starter, real]) == [starter])

        starter.allPages.first?.fieldNotes = "Used it after all"
        #expect(Notebook.redundantStarters(in: [starter, real]).isEmpty)
    }

    @Test func twoNewDevicesKeepTheSameStarter() throws {
        let context = try memoryContext()
        let date = Date.now
        let first = Notebook(title: "Field Notes", createdAt: date)
        let second = Notebook(title: "Field Notes", createdAt: date.addingTimeInterval(5))
        first.isStarter = true
        second.isStarter = true
        context.insert(first)
        context.insert(second)
        #expect(Notebook.redundantStarters(in: [first, second]) == [second])
        #expect(Notebook.redundantStarters(in: [second, first]) == [second])
    }

    @Test func aPageListsAllItsMedia() throws {
        let page = Page(title: "Walk")
        page.items = [PageItem(content: .photo("References/a.jpg"), center: .zero, width: 10),
                      PageItem(content: .video("References/b.mp4"), center: .zero, width: 10),
                      PageItem(content: .sticker("🌿"), center: .zero, width: 10)]
        page.voiceNotes = [VoiceNote(path: "References/c.m4a", date: .now, duration: 1)]
        #expect(Set(page.mediaPaths) == ["References/a.jpg", "References/b.mp4", "References/b.jpg", "References/c.m4a"])
    }

    @Test func mediaTravelsBetweenDevices() async throws {
        let container = try ModelContainer(for: Schema(FieldGuideSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let here = ImageStore(root: try temporaryDirectory())
        let there = ImageStore(root: try temporaryDirectory())
        let sync = MediaSync(modelContainer: container)

        let path = try here.save(jpegData: Data([9, 9]))
        let page = Page(title: "Walk")
        page.items = [PageItem(content: .photo(path), center: .zero, width: 10)]
        context.insert(page)
        try context.save()

        // This device makes the copy; nothing has arrived here.
        #expect(await sync.reconcile(imageStore: here) == false)
        // The store is shared in this test, so the other device sees the copy straight away.
        #expect(await sync.reconcile(imageStore: there) == true)
        #expect(try Data(contentsOf: there.url(for: path)) == Data([9, 9]))
        #expect(await sync.reconcile(imageStore: there) == false)
    }
}
