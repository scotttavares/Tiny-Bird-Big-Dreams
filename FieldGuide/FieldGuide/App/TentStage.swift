import SwiftUI

/// What the two sides of a tent are doing.
enum TentStage: Equatable {
    /// The audience sees the page; you turn the pages.
    case show
    /// You draw a word; the audience guesses from a live copy.
    case game
}

/// A round of the drawing game: words to get through and how many were guessed.
struct DrawingGame {
    static let roundSeconds = 60
    static let words = [
        "owl", "mushroom", "mountain", "campfire", "canoe", "fox", "pine tree", "waterfall", "tent", "compass",
        "butterfly", "beaver", "lighthouse", "snail", "acorn", "bear", "kite", "rainbow", "turtle", "lantern",
        "hedgehog", "binoculars", "river", "cactus", "dragonfly", "moon", "backpack", "frog", "volcano", "bicycle",
    ]

    private var remaining: [String]
    private(set) var word: String
    private(set) var score = 0

    init(words: [String] = Self.words.shuffled()) {
        var words = words
        word = words.removeFirst()
        remaining = words
    }

    /// Moves to the next word, counting this one if it was guessed.
    mutating func next(guessed: Bool) {
        if guessed { score += 1 }
        if remaining.isEmpty { remaining = Self.words.shuffled() }
        word = remaining.removeFirst()
    }
}

/// Fills a tent: the half facing away shows the page upside down from here, which is upright for
/// whoever is sitting there. This half keeps the controls, around the canvas when drawing.
struct TentStageView: View {
    let model: AppModel
    let stage: TentStage
    let onEnd: () -> Void

    @State private var isFlipped = false
    @State private var game = DrawingGame()
    @State private var secondsLeft = DrawingGame.roundSeconds
    @State private var isRoundOver = false
    @State private var roundID = 0

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                audienceSide
                    .frame(height: proxy.size.height / 2)
                    .rotationEffect(.degrees(isFlipped ? 0 : 180))
                Spacer()
                controls
                    .padding(10)
            }
        }
        .task(id: roundID) {
            guard stage == .game else { return }
            while secondsLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsLeft -= 1
            }
            isRoundOver = true
        }
        .onAppear { if stage == .game { startPage() } }
    }

    private var audienceSide: some View {
        ZStack(alignment: .top) {
            Theme.chrome
            if isRoundOver {
                VStack(spacing: 8) {
                    Text("Time!")
                        .font(.largeTitle.bold())
                    Text("\(game.score) guessed")
                        .font(.title2)
                }
                .frame(maxHeight: .infinity)
            } else {
                LivePageImage(model: model)
                    .padding(8)
                if stage == .game {
                    Text("What is it?  \(secondsLeft)")
                        .font(.headline.monospacedDigit())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: .capsule)
                        .padding(12)
                }
            }
        }
        .foregroundStyle(Theme.inkText)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 8) {
            Button("Flip Other Side", systemImage: "arrow.up.arrow.down") { isFlipped.toggle() }
                .labelStyle(.iconOnly)
            switch stage {
            case .show:
                Button("Previous Page", systemImage: "chevron.left") { model.turnPage(by: -1) }
                    .labelStyle(.iconOnly)
                    .disabled(model.previousPage == nil)
                Text(model.currentPage?.title ?? "")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                Button("Next Page", systemImage: "chevron.right") { model.turnPage(by: 1) }
                    .labelStyle(.iconOnly)
                    .disabled(model.nextPage == nil)
            case .game:
                gameControls
            }
            Button("End", action: onEnd)
                .fontWeight(.semibold)
        }
        .buttonStyle(.bordered)
        .padding(8)
        .background(.regularMaterial, in: .capsule)
    }

    @ViewBuilder
    private var gameControls: some View {
        if isRoundOver {
            Text("\(game.score) guessed")
                .font(.headline)
                .frame(maxWidth: .infinity)
            Button("Play Again") {
                game = DrawingGame()
                secondsLeft = DrawingGame.roundSeconds
                isRoundOver = false
                model.canvas.clearDrawing()
                roundID += 1
            }
        } else {
            VStack(spacing: 0) {
                Text("Draw")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(game.word)
                    .font(.headline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            Text("\(secondsLeft)")
                .font(.headline.monospacedDigit())
            Button("Skip") { advance(guessed: false) }
            Button("Got It") { advance(guessed: true) }
                .buttonStyle(.borderedProminent)
        }
    }

    private func advance(guessed: Bool) {
        game.next(guessed: guessed)
        model.canvas.clearDrawing()
    }

    /// The game gets its own page, so nobody scribbles on a finished sketch.
    private func startPage() {
        let page = model.newPage()
        page.title = "Drawing Game"
        model.save()
    }
}
