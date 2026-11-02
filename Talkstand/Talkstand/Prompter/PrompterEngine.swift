import Foundation

/// The teleprompter's reading position, kept free of UI so it can be tested.
///
/// The script is split into lines (sentences and line breaks). The position is measured in
/// words and moves at a steady words-per-minute pace while playing. Going back a line also
/// records the stumble as a time range in the take, so a later pass can cut it out.
struct PrompterEngine: Equatable, Sendable {
    struct Line: Equatable, Sendable {
        var text: String
        /// Index of this line's first word in the whole script.
        var firstWord: Int
        var wordCount: Int
    }

    private(set) var lines: [Line]
    /// Words read so far; fractional while scrolling.
    private(set) var position: Double = 0
    var wordsPerMinute: Double
    private(set) var isPlaying = false
    /// Recording-clock times when each line was last started.
    private var lineStartedAt: [Int: TimeInterval] = [:]
    /// Stumbles to cut, in recording-clock seconds.
    private(set) var flubs: [ClosedRange<TimeInterval>] = []
    private var lastTick: TimeInterval?

    init(text: String, wordsPerMinute: Double = 140) {
        lines = Self.split(text)
        self.wordsPerMinute = wordsPerMinute
    }

    var totalWords: Int {
        lines.last.map { $0.firstWord + $0.wordCount } ?? 0
    }

    var isFinished: Bool {
        position >= Double(totalWords)
    }

    /// The line being read now.
    var currentLine: Int {
        guard !lines.isEmpty else { return 0 }
        let word = Int(position)
        return lines.lastIndex { $0.firstWord <= word } ?? 0
    }

    /// How far through the current line, 0...1.
    var lineProgress: Double {
        guard lines.indices.contains(currentLine) else { return 0 }
        let line = lines[currentLine]
        guard line.wordCount > 0 else { return 0 }
        return min(1, max(0, (position - Double(line.firstWord)) / Double(line.wordCount)))
    }

    mutating func play(at time: TimeInterval) {
        guard !isPlaying, !lines.isEmpty else { return }
        isPlaying = true
        lastTick = time
        lineStartedAt[currentLine] = lineStartedAt[currentLine] ?? time
    }

    mutating func pause() {
        isPlaying = false
        lastTick = nil
    }

    /// Advances the position to `time` (seconds on the recording clock).
    mutating func tick(at time: TimeInterval) {
        guard isPlaying, let last = lastTick else { return }
        lastTick = time
        let before = currentLine
        position = min(Double(totalWords), position + max(0, time - last) * wordsPerMinute / 60)
        let after = currentLine
        if after != before {
            lineStartedAt[after] = time
        }
        if isFinished { pause() }
    }

    /// Jumps to the start of the current line, or the previous one if this line has barely
    /// started. While recording, marks everything since that line began as a stumble.
    mutating func backOneLine(at time: TimeInterval?) {
        guard !lines.isEmpty else { return }
        var target = currentLine
        if lineProgress < 0.25 && target > 0 {
            target -= 1
        }
        if let time, let started = lineStartedAt[target], started < time {
            flubs.append(started...time)
        }
        position = Double(lines[target].firstWord)
        if let time {
            lineStartedAt[target] = time
            if isPlaying { lastTick = time }
        }
    }

    mutating func restart() {
        position = 0
        flubs = []
        lineStartedAt = [:]
        pause()
    }

    /// Splits on line breaks and sentence ends, keeping the punctuation.
    static func split(_ text: String) -> [Line] {
        var result: [Line] = []
        var word = 0

        func append(_ sentence: inout String) {
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            sentence = ""
            let count = trimmed.split(whereSeparator: { $0.isWhitespace }).count
            guard count > 0 else { return }
            // A lone "." or "..." after a word stays with the line before it.
            if trimmed.allSatisfy({ ".!?".contains($0) }), !result.isEmpty {
                result[result.count - 1].text += trimmed
                return
            }
            result.append(Line(text: trimmed, firstWord: word, wordCount: count))
            word += count
        }

        for paragraph in text.split(whereSeparator: \.isNewline) {
            var sentence = ""
            for character in paragraph {
                sentence.append(character)
                if ".!?".contains(character) {
                    append(&sentence)
                }
            }
            append(&sentence)
        }
        return result
    }
}
