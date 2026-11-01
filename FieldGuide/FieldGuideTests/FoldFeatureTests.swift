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
