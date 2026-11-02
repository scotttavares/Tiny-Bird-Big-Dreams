import Foundation
import Testing
@testable import Talkstand

@Suite("PrompterEngine")
struct PrompterEngineTests {
    private let text = """
    Hi, it's me. I made the team!
    Wait... really?
    """

    @Test func splitsSentencesAndLineBreaks() {
        let lines = PrompterEngine.split(text).map(\.text)
        #expect(lines == ["Hi, it's me.", "I made the team!", "Wait...", "really?"])
    }

    @Test func countsWordsAcrossLines() {
        let lines = PrompterEngine.split(text)
        #expect(lines.map(\.firstWord) == [0, 3, 7, 8])
        #expect(PrompterEngine(text: text).totalWords == 9)
    }

    @Test func emptyScriptHasNoLines() {
        let engine = PrompterEngine(text: "  \n\n ")
        #expect(engine.lines.isEmpty)
        #expect(engine.isFinished)
    }

    @Test func scrollsAtWordsPerMinute() {
        var engine = PrompterEngine(text: text, wordsPerMinute: 60)
        engine.play(at: 0)
        engine.tick(at: 3)
        #expect(engine.position == 3)
        #expect(engine.currentLine == 1)
    }

    @Test func doesNotMoveWhilePaused() {
        var engine = PrompterEngine(text: text, wordsPerMinute: 60)
        engine.tick(at: 5)
        #expect(engine.position == 0)
    }

    @Test func stopsAtTheEnd() {
        var engine = PrompterEngine(text: text, wordsPerMinute: 60)
        engine.play(at: 0)
        engine.tick(at: 100)
        #expect(engine.isFinished)
        #expect(!engine.isPlaying)
        #expect(engine.position == 9)
    }

    @Test func backGoesToStartOfLineAndMarksStumble() {
        var engine = PrompterEngine(text: text, wordsPerMinute: 60)
        engine.play(at: 0)
        engine.tick(at: 3)   // enters line 1 at t=3
        engine.tick(at: 5)   // halfway through line 1
        engine.backOneLine(at: 5)
        #expect(engine.position == 3)
        #expect(engine.flubs == [3...5])
    }

    @Test func backEarlyInLineGoesToPreviousLine() {
        var engine = PrompterEngine(text: text, wordsPerMinute: 60)
        engine.play(at: 0)
        engine.tick(at: 3)   // just started line 1
        engine.backOneLine(at: 3)
        #expect(engine.position == 0)
        #expect(engine.flubs == [0...3])
    }

    @Test func backWithoutRecordingKeepsNoStumbles() {
        var engine = PrompterEngine(text: text, wordsPerMinute: 60)
        engine.play(at: 0)
        engine.tick(at: 5)
        engine.backOneLine(at: nil)
        #expect(engine.flubs.isEmpty)
    }

    @Test func restartClearsEverything() {
        var engine = PrompterEngine(text: text, wordsPerMinute: 60)
        engine.play(at: 0)
        engine.tick(at: 5)
        engine.backOneLine(at: 5)
        engine.restart()
        #expect(engine.position == 0)
        #expect(engine.flubs.isEmpty)
        #expect(!engine.isPlaying)
    }
}
