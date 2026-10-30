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
        #expect(store.items.allSatisfy(\.overInk))
        #expect(!store.canMove(tape, .forward))

        // Stack, bottom to top: ink, bird, tape. Backward steps past the bird, then under the ink.
        store.move(tape, .backward)
        #expect(PageItem.stacked(store.items).map(\.id) == [tape, bird])
        #expect(store.items.allSatisfy(\.overInk))
        store.move(tape, .backward)
        #expect(try #require(store.items.first { $0.id == tape }).overInk == false)
        #expect(!store.canMove(tape, .backward))

        store.move(tape, .front)
        #expect(PageItem.stacked(store.items).map(\.id) == [bird, tape])
        store.move(bird, .back)
        #expect(try #require(store.items.first { $0.id == bird }).overInk == false)
        #expect(PageItem.stacked(store.items).map(\.id) == [bird, tape])
    }

    @Test func itemsSavedBeforeLayersStayUnderTheInk() throws {
        let json = #"[{"id":"3B2C8E2A-0F4E-4D6A-9A43-2E1C3B5D7F10","content":{"sticker":{"_0":"🍄"}},"center":[10,20],"width":150,"rotation":0}]"#
        let items = try JSONDecoder().decode([PageItem].self, from: Data(json.utf8))
        #expect(items.count == 1)
        #expect(items[0].overInk == false)
    }
}
