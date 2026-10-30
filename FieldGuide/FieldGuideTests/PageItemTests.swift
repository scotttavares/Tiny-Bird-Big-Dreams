import CoreImage
import Foundation
import Testing
import UIKit
@testable import FieldGuide

@MainActor
@Suite("Stickers, photos and tape on a page")
struct PageItemTests {
    @Test func itemsRoundTripThroughThePage() {
        let page = Page(title: "Creek")
        #expect(page.items.isEmpty)
        let items = [
            PageItem(content: .sticker("🍄"), center: CGPoint(x: 120, y: 300), width: 150, rotation: 0.1),
            PageItem(content: .photo("References/a.jpg"), center: CGPoint(x: 400, y: 500), width: 380),
            PageItem(content: .tape(2), center: CGPoint(x: 400, y: 320), width: 300, rotation: -0.2),
        ]
        page.items = items
        #expect(page.items == items)
        page.items = []
        #expect(page.itemsData.isEmpty)
    }

    @Test func hitTestFollowsRotation() {
        let item = PageItem(content: .sticker("🐦"), center: CGPoint(x: 100, y: 100), width: 100, rotation: .pi / 2)
        let size = CGSize(width: 100, height: 50)
        // Turned a quarter, the long side runs up and down.
        #expect(item.contains(CGPoint(x: 100, y: 145), size: size))
        #expect(!item.contains(CGPoint(x: 145, y: 100), size: size))
        #expect(!item.contains(CGPoint(x: 300, y: 300), size: size))
    }

    @Test func stickerArtHasAWhiteBorderAroundTheEmoji() throws {
        let image = try #require(PageItemArt.image(for: .sticker("🌿")))
        #expect(image.size.width > 200)
        let size = PageItemArt.size(of: PageItem(content: .sticker("🌿"), center: .zero, width: 150))
        #expect(size.width == 150)
        #expect(size.height > 0)
    }

    @Test func storeAddsArrangesAndRemovesItems() {
        let store = CanvasStore(autosaveDelay: .zero)
        var saved: [[PageItem]] = []
        store.onItemsChange = { saved.append($0) }
        store.add(.tape(0), width: 300)
        #expect(store.items.count == 1)
        #expect(store.isArranging)
        #expect(store.selectedItemID == store.items.first?.id)
        let id = store.items[0].id
        store.removeItem(id)
        #expect(store.items.isEmpty)
        #expect(store.selectedItemID == nil)
        #expect(saved.count == 2)
        store.toolKind = .pencil
        #expect(!store.isArranging)
    }

    @Test func newItemsGoOverTheInkAndStepThroughIt() throws {
        let store = CanvasStore(autosaveDelay: .zero)
        store.add(.sticker("🐦"), width: 150)
        store.add(.tape(1), width: 300)
        let bird = store.items[0].id, tape = store.items[1].id
        #expect(allOverInk(store))
        #expect(!store.canMove(tape, .forward))

        // Stack, bottom to top: ink, bird, tape. Backward steps past the bird, then under the ink.
        store.move(tape, .backward)
        #expect(PageItem.stacked(store.items).map(\.id) == [tape, bird])
        #expect(allOverInk(store))
        store.move(tape, .backward)
        #expect(try #require(store.items.first { $0.id == tape }).overInk == false)
        #expect(!store.canMove(tape, .backward))

        store.move(tape, .front)
        #expect(PageItem.stacked(store.items).map(\.id) == [bird, tape])
        store.move(bird, .back)
        #expect(try #require(store.items.first { $0.id == bird }).overInk == false)
        #expect(PageItem.stacked(store.items).map(\.id) == [bird, tape])
    }

    private func allOverInk(_ store: CanvasStore) -> Bool {
        store.items.allSatisfy(\.overInk)
    }

    @Test func theFrontmostItemIsTheOneHeld() throws {
        let store = CanvasStore(autosaveDelay: .zero)
        store.add(.sticker("🐦"), width: 150)
        store.add(.sticker("🍄"), width: 150)
        var (under, over) = (store.items[0], store.items[1])
        under.center = CGPoint(x: 400, y: 500)
        over.center = CGPoint(x: 400, y: 500)
        store.update(under)
        store.update(over)
        let held = store.item(at: CGPoint(x: 400, y: 500))
        #expect(held?.id == over.id)
        let missed = store.item(at: .zero)
        #expect(missed == nil)
    }

    @Test func videoKeepsItsFirstFrameBesideIt() throws {
        #expect(ImageStore.posterPath(forVideo: "References/a.mp4") == "References/a.jpg")
        let item = PageItem(content: .video("References/a.mp4"), center: .zero, width: 380)
        let data = try JSONEncoder().encode([item])
        let decoded = try JSONDecoder().decode([PageItem].self, from: data)
        #expect(decoded == [item])
    }

    @Test func itemsSavedBeforeLayersStayUnderTheInk() throws {
        let json = #"[{"id":"3B2C8E2A-0F4E-4D6A-9A43-2E1C3B5D7F10","content":{"sticker":{"_0":"🍄"}},"center":[10,20],"width":150,"rotation":0}]"#
        let items = try JSONDecoder().decode([PageItem].self, from: Data(json.utf8))
        #expect(items.count == 1)
        #expect(items[0].overInk == false)
    }

    @Test func itemsSavedBeforeStylesKeepTheWhiteBorderAndOriginalColor() throws {
        let saved = #"""
        {"id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","content":{"photo":{"_0":"References/a.jpg"}},
         "center":[10,20],"width":100}
        """#
        let item = try JSONDecoder().decode(PageItem.self, from: Data(saved.utf8))
        #expect(item.frame == .print)
        #expect(item.look == .original)
    }

    @Test func frameAndLookSurviveSaving() throws {
        let item = PageItem(content: .photo("References/a.jpg"), center: .zero, width: 100, frame: .film, look: .sepia)
        let copy = try JSONDecoder().decode(PageItem.self, from: JSONEncoder().encode(item))
        #expect(copy == item)
    }

    @Test func onlyPhotosAndVideosCanBeStyled() {
        func item(_ content: PageItem.Content) -> PageItem { PageItem(content: content, center: .zero, width: 100) }
        #expect(item(.photo("a.jpg")).canBeStyled)
        #expect(item(.video("a.mp4")).canBeStyled)
        #expect(!item(.sticker("🌿")).canBeStyled)
        #expect(!item(.tape(0)).canBeStyled)
    }

    @Test(arguments: ItemFrame.allCases)
    func framedPictureSitsInsideItsMargins(frame: ItemFrame) {
        let (top, side, bottom) = frame.margins
        for picture in [CGSize(width: 1000, height: 600), CGSize(width: 600, height: 1000)] {
            let longest = max(picture.width, picture.height)
            let art = CGSize(width: picture.width + side * 2 * longest,
                             height: picture.height + (top + bottom) * longest)
            let rect = frame.photoRect(in: art)
            #expect(abs(rect.width - picture.width) < 0.01)
            #expect(abs(rect.height - picture.height) < 0.01)
            #expect(abs(rect.minX - side * longest) < 0.01)
            #expect(abs(rect.minY - top * longest) < 0.01)
        }
    }

    @Test func everyLookFiltersAnImage() {
        let image = CIImage(color: CIColor(red: 0.8, green: 0.2, blue: 0.1)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        for look in ItemLook.allCases {
            #expect(look.filtered(image).extent == image.extent)
        }
    }
}
