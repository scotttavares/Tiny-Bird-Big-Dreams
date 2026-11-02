import Foundation
import PencilKit
import Testing
import UIKit
@testable import FieldGuide

@MainActor
struct FoldFeatureTests {
    @Test func replayStepsEndOnTheWholeDrawing() {
        #expect(SketchReplay.steps(strokeCount: 0) == [0])
        #expect(SketchReplay.steps(strokeCount: 3) == [1, 2, 3])
        let long = SketchReplay.steps(strokeCount: 1000, maxSteps: 240)
        #expect(long.count == 240)
        #expect(long.last == 1000)
        #expect(long == long.sorted())
    }

    private func sticker(addedAt: Date? = nil) -> PageItem {
        PageItem(content: .sticker("🦋"), center: CGPoint(x: 200, y: 200), width: 150, addedAt: addedAt)
    }

    @Test func itemsLandBetweenTheStrokesTheyWereAddedBetween() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let dates = [0, 10, 20].map { start.addingTimeInterval($0) }
        let item = sticker(addedAt: start.addingTimeInterval(5))
        let frames = SketchReplay.timeline(strokeDates: dates, items: [item])
        let landing = try #require(frames.first { $0.entering == item.id })
        #expect(landing.strokes == 1)
        #expect(!landing.shown.contains(item.id))
        let last = try #require(frames.last)
        #expect(last.strokes == 3)
        #expect(last.shown == [item.id])
        #expect(last.entering == nil)
    }

    @Test func itemsWithNoDateAreSpreadThroughTheDrawing() throws {
        let dates = (0..<4).map { Date(timeIntervalSince1970: Double($0)) }
        let first = sticker()
        let second = sticker()
        let frames = SketchReplay.timeline(strokeDates: dates, items: [first, second])
        #expect(try #require(frames.first { $0.entering == first.id }).strokes == 0)
        #expect(try #require(frames.first { $0.entering == second.id }).strokes == 2)
    }

    @Test func aPageOfOnlyItemsStillReplaysAndSettles() throws {
        let item = sticker()
        let frames = SketchReplay.timeline(strokeDates: [], items: [item])
        #expect(frames.count == SketchReplay.entranceFrames(itemCount: 1) + 1)
        #expect(try #require(frames.last).shown == [item.id])
        #expect(SketchReplay.timeline(strokeDates: [], items: []).count == 1)
    }

    @Test func anEntranceFallsBigAndSettlesExactlyInPlace() {
        #expect(SketchReplay.entrancePose(progress: 0).scale > 3)
        #expect(SketchReplay.entrancePose(progress: 0.56).scale < 1)
        #expect(SketchReplay.entrancePose(progress: 0.56).burst != nil)
        let rest = SketchReplay.entrancePose(progress: 1)
        #expect(abs(rest.scale - 1) < 0.0001)
        #expect(abs(rest.spin) < 0.0001)
        #expect(rest.burst == nil)
    }

    @Test func aTextBoxGrowsWithItsWordsAndKeepsItsLetterSize() {
        let short = TextBox(text: "Owl")
        let long = TextBox(text: "A very long line about an owl we saw at the edge of the field")
        #expect(PageItemArt.textArt(long).size.height > PageItemArt.textArt(short).size.height)
        let item = PageItem(content: .text(short), center: .zero, width: PageItemArt.startingWidth(for: short))
        #expect(PageItemArt.width(of: item, afterChangingTo: short) == item.width)
        #expect(PageItemArt.width(of: item, afterChangingTo: long) > item.width)
    }

    @Test func aTextBoxCanBeClearOrColored() throws {
        var box = TextBox(text: "Owl")
        #expect(box.boxColor.isClear)
        #expect(PageItem(content: .text(box), center: .zero, width: 100).liesFlat)
        let clear = try #require(PageItemArt.textArt(box).pngData())
        box.boxColor = TextBox.boxColors[3]
        #expect(!PageItem(content: .text(box), center: .zero, width: 100).liesFlat)
        #expect(try #require(PageItemArt.textArt(box).pngData()) != clear)
    }

    @Test func everyTextBoxFontIsInstalled() {
        for font in TextBoxFont.allCases {
            #expect(font.uiFont(size: 20).pointSize == 20)
        }
        #expect(TextBoxFont.marker.uiFont(size: 20).fontName != TextBoxFont.serif.uiFont(size: 20).fontName)
    }

    @Test func aReplayDrawsItsItems() {
        let item = sticker()
        let page = ExportPage(title: "Replay", fieldDate: .now, locationName: "", tags: [], drawing: PKDrawing(), paperStyle: .blank, items: [item])
        let frames = SketchReplay.timeline(for: page)
        #expect(SketchReplay.image(page, frame: frames[0], width: 200).size.width == 200)
    }

    @Test func aGuessedWordScoresAndASkippedOneDoesNot() {
        var game = DrawingGame(words: ["owl", "fox", "bear"])
        #expect(game.word == "owl")
        game.next(guessed: true)
        #expect(game.word == "fox")
        #expect(game.score == 1)
        game.next(guessed: false)
        #expect(game.word == "bear")
        #expect(game.score == 1)
    }

    @Test func theGameNeverRunsOutOfWords() {
        var game = DrawingGame(words: ["owl"])
        game.next(guessed: true)
        #expect(!game.word.isEmpty)
    }

    @Test func theCloseSoundIsAValidWAV() {
        let sound = BookSound.closeSound(sampleRate: 1000, duration: 0.1)
        #expect(sound.prefix(4) == Data("RIFF".utf8))
        #expect(sound.count == 44 + 100 * 2)
    }

    @Test func clearingADrawingCanBeUndone() {
        let store = CanvasStore()
        let point = PKStrokePoint(location: .zero, timeOffset: 0, size: CGSize(width: 4, height: 4),
                                  opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: [point, point], creationDate: .now))
        store.drawingDidChange(PKDrawing(strokes: [stroke]))
        store.clearDrawing()
        #expect(store.drawing.strokes.isEmpty)
        store.undo()
        #expect(store.drawing.strokes.count == 1)
    }

    @Test func fieldRecordsAreSavedOnThePage() {
        let page = Page(title: "Test")
        page.weather = .rainy
        page.voiceNotes = [VoiceNote(path: "References/a.m4a", date: .now, duration: 3)]
        #expect(page.weather == .rainy)
        #expect(page.voiceNotes.first?.path == "References/a.m4a")
        page.weather = nil
        #expect(page.weather == nil)
    }
}
