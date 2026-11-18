import SpriteKit
import SwiftUI
import UIKit

/// One level, laid out for the current posture:
/// - closed (any iPhone, or iPhone Duo folded): board + mood tray at the bottom
/// - book (Duo unfolded, iPad, wide windows): board on the left page, companion on the right
/// - laptop (Duo half-folded, horizontal hinge): board on top, a big mood controller below
/// - tent: the board alone, like a little stage, for showing off a solve
struct GameView: View {
    let postureProvider: SystemPostureProvider
    @Binding var path: [Route]
    @EnvironmentObject private var progress: ProgressStore
    @StateObject private var model: GameModel

    init(level: LevelData, postureProvider: SystemPostureProvider, path: Binding<[Route]>) {
        self.postureProvider = postureProvider
        _path = path
        _model = StateObject(wrappedValue: GameModel(level: level, progress: nil))
    }

    private var posture: Posture { postureProvider.posture }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.backdrop.ignoresSafeArea()
                switch posture {
                case .closed: closedLayout
                case .book: bookLayout(in: geo.size)
                case .laptop: laptopLayout(in: geo.size)
                case .tent: tentLayout
                }
                resultOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            model.attach(progress)
            model.scene.acceptsTouches = posture != .tent
        }
        .onChange(of: posture) { _, newValue in
            model.scene.acceptsTouches = newValue != .tent
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: posture)
    }

    // MARK: Layouts

    private var closedLayout: some View {
        VStack(spacing: 10) {
            TopBar(model: model, postureProvider: postureProvider, onBack: back)
            Board(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if model.showingHint { HintBubble(text: model.level.hint) }
            MoodTray(model: model, style: .compact)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func bookLayout(in size: CGSize) -> some View {
        let hinge = postureProvider.hingeRect
        let left = hinge.isNull ? size.width / 2 : max(0, hinge.minX)
        let gutter = hinge.isNull ? 24 : hinge.width
        return HStack(spacing: 0) {
            VStack(spacing: 10) {
                TopBar(model: model, postureProvider: postureProvider, onBack: back)
                Board(model: model).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(14)
            .frame(width: left)
            Color.clear.frame(width: gutter)
            CompanionPage(model: model)
                .padding(18)
                .frame(maxWidth: .infinity)
        }
    }

    private func laptopLayout(in size: CGSize) -> some View {
        let hinge = postureProvider.hingeRect
        let top = hinge.isNull ? size.height / 2 : max(0, hinge.minY)
        let gutter = hinge.isNull ? 24 : hinge.height
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Board(model: model).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(10)
            .frame(height: top)
            Color.clear.frame(height: gutter)
            VStack(spacing: 12) {
                TopBar(model: model, postureProvider: postureProvider, onBack: back)
                MoodTray(model: model, style: .controller)
                    .frame(maxHeight: .infinity)
            }
            .padding(14)
        }
    }

    private var tentLayout: some View {
        ZStack(alignment: .topLeading) {
            Board(model: model)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button {
                postureProvider.override = nil
            } label: {
                Label("Back to play", systemImage: "hand.tap.fill")
                    .font(Theme.body(14, weight: .bold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.75)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.ink)
            .padding(20)
            .opacity(postureProvider.override == .tent ? 1 : 0)
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultOverlay: some View {
        switch model.phase {
        case .playing:
            EmptyView()
        case .won(let stars, let moves):
            let isLast = progress.next(after: model.level) == nil
            let primaryTitle = isLast ? "All done!" : "Next level"
            let primaryAction: () -> Void = isLast ? { back() } : { next() }
            ResultCard(
                title: stars == 3 ? "Sweet!" : "Nice!",
                message: "Solved in \(moves) mood \(moves == 1 ? "change" : "changes"). Par is \(model.level.par).",
                stars: stars,
                primary: (primaryTitle, primaryAction),
                secondary: ("Replay", { model.restart() })
            )
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        case .failed:
            ResultCard(
                title: "Oops!",
                message: "A jelly slipped into the gloom.",
                stars: nil,
                primary: ("Try again", { model.restart() }),
                secondary: ("Levels", { back() })
            )
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    private func back() {
        if !path.isEmpty { path.removeLast() }
    }

    private func next() {
        guard let upcoming = progress.next(after: model.level) else { return }
        model.load(upcoming)
    }
}

// MARK: - Pieces

private struct Board: View {
    @ObservedObject var model: GameModel

    var body: some View {
        SpriteView(scene: model.scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
            .aspectRatio(CGFloat(model.level.width / model.level.height), contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.8), lineWidth: 3))
            .shadow(color: Theme.ink.opacity(0.18), radius: 16, y: 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Level board")
    }
}

private struct TopBar: View {
    @ObservedObject var model: GameModel
    let postureProvider: SystemPostureProvider
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            IconButton(systemName: "chevron.left", label: "Back", action: onBack)
            VStack(alignment: .leading, spacing: 1) {
                Text("Level \(model.level.id)")
                    .font(Theme.body(13, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                Text(model.level.name)
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            VStack(spacing: 0) {
                Text("\(model.moves)")
                    .font(Theme.display(20))
                    .contentTransition(.numericText())
                Text("par \(model.level.par)")
                    .font(Theme.body(11, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }
            .foregroundStyle(Theme.ink)
            .frame(minWidth: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(model.moves) moves, par \(model.level.par)")
            IconButton(systemName: "lightbulb.fill", label: "Hint") { model.hint() }
            IconButton(systemName: "arrow.counterclockwise", label: "Restart") { model.restart() }
            Menu {
                Picker("Layout", selection: Binding(
                    get: { postureProvider.override },
                    set: { postureProvider.override = $0 }
                )) {
                    Text("Automatic").tag(Posture?.none)
                    ForEach(Posture.allCases) { posture in
                        Label(posture.title, systemImage: posture.symbol).tag(Posture?.some(posture))
                    }
                }
            } label: {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.white.opacity(0.75)))
            }
            .accessibilityLabel("Layout")
        }
    }
}

/// The mood picker. `.compact` is the bottom tray; `.controller` is the big laptop-posture pad.
private struct MoodTray: View {
    enum Style { case compact, controller }
    @ObservedObject var model: GameModel
    let style: Style

    var body: some View {
        HStack(spacing: style == .controller ? 24 : 12) {
            ForEach(model.palette) { mood in
                let selected = mood == model.selectedMood
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { model.selectedMood = mood }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    VStack(spacing: 4) {
                        JellyBadge(mood: mood, size: badgeSize(selected: selected), wobble: selected)
                        Text(mood.title)
                            .font(Theme.body(style == .controller ? 17 : 13, weight: .heavy))
                            .foregroundStyle(selected ? MoodPalette.deepColor(mood) : Theme.ink.opacity(0.55))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white.opacity(selected ? 0.85 : 0.35))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(selected ? MoodPalette.color(mood) : .clear, lineWidth: 3))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mood.title) mood")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func badgeSize(selected: Bool) -> CGFloat {
        switch style {
        case .compact: return selected ? 50 : 40
        case .controller: return selected ? 86 : 68
        }
    }
}

/// Book posture's right page: the level's story, the cast, and a roomy mood picker.
private struct CompanionPage: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Level \(model.level.id)").font(Theme.body(15, weight: .bold)).foregroundStyle(Theme.ink.opacity(0.6))
                    Text(model.level.name).font(Theme.display(34)).foregroundStyle(Theme.ink)
                    Text(model.level.hint).font(Theme.body(17, weight: .medium)).foregroundStyle(Theme.ink.opacity(0.85))
                }
                section("Choose a mood") {
                    VStack(spacing: 10) {
                        ForEach(model.palette) { mood in
                            let selected = mood == model.selectedMood
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { model.selectedMood = mood }
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                HStack(spacing: 14) {
                                    JellyBadge(mood: mood, size: selected ? 58 : 48, wobble: selected)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mood.title).font(Theme.display(19)).foregroundStyle(MoodPalette.deepColor(mood))
                                        Text(mood.blurb).font(Theme.body(14, weight: .medium)).foregroundStyle(Theme.ink.opacity(0.8))
                                    }
                                    Spacer(minLength: 0)
                                    if selected { Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(MoodPalette.color(mood)) }
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.white.opacity(selected ? 0.9 : 0.45))
                                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(selected ? MoodPalette.color(mood) : .clear, lineWidth: 3)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                section("The cast") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                        ForEach(model.cast) { member in
                            HStack(spacing: 8) {
                                if member.isStone {
                                    Circle().fill(MoodPalette.color(member.mood)).frame(width: 26, height: 26)
                                        .overlay(Circle().strokeBorder(Color(uiColor: MoodPalette.stoneDeep), lineWidth: 4))
                                } else {
                                    JellyBadge(mood: member.mood, size: 30)
                                }
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(member.id.capitalized).font(Theme.body(14, weight: .heavy))
                                    Text(member.swappable ? member.mood.title : "\(member.mood.title) · fixed")
                                        .font(Theme.body(12, weight: .semibold)).foregroundStyle(Theme.ink.opacity(0.6))
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.55)))
                        }
                    }
                }
                HStack {
                    Label("\(model.nestsDone) of \(model.nestsTotal) nests filled", systemImage: "house.fill")
                    Spacer()
                    Label("\(model.moves) / par \(model.level.par)", systemImage: "sparkles")
                }
                .font(Theme.body(15, weight: .bold))
                .foregroundStyle(Theme.ink.opacity(0.75))
            }
            .foregroundStyle(Theme.ink)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(Theme.body(12, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.ink.opacity(0.5))
            content()
        }
    }
}

private struct HintBubble: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "lightbulb.fill")
            .font(Theme.body(14, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.8)))
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct ResultCard: View {
    let title: String
    let message: String
    let stars: Int?
    let primary: (String, () -> Void)
    let secondary: (String, () -> Void)

    var body: some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(title).font(Theme.display(40)).foregroundStyle(Theme.ink)
                if let stars { StarRow(earned: stars, size: 34) }
                Text(message)
                    .font(Theme.body(16, weight: .medium))
                    .foregroundStyle(Theme.ink.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button(primary.0, action: primary.1).buttonStyle(JellyButtonStyle())
                Button(secondary.0, action: secondary.1)
                    .font(Theme.body(16, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Theme.cream)
                    .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(.white, lineWidth: 3))
                    .shadow(color: Theme.ink.opacity(0.25), radius: 24, y: 10)
            )
            .padding(24)
        }
    }
}
