import SwiftUI

enum Route: Hashable {
    case levels
    case play(Int)
}

struct RootView: View {
    let postureProvider: SystemPostureProvider
    @EnvironmentObject private var progress: ProgressStore
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .levels:
                        LevelSelectView(path: $path)
                    case .play(let id):
                        if let level = progress.levels.first(where: { $0.id == id }) {
                            GameView(level: level, postureProvider: postureProvider, path: $path)
                        }
                    }
                }
        }
        .tint(Theme.ink)
        .readsPosture(into: postureProvider)
        .onAppear {
            // `-MMStartLevel 3` jumps straight into a level (screenshots, testing).
            let defaults = UserDefaults.standard
            let start = defaults.integer(forKey: "MMStartLevel")
            if start > 0, path.isEmpty {
                path = [.levels, .play(start)]
            }
        }
    }
}

struct HomeView: View {
    @Binding var path: [Route]
    @EnvironmentObject private var progress: ProgressStore
    @State private var showingHowTo = false
    @State private var float = false

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer(minLength: 20)
                HStack(alignment: .bottom, spacing: -10) {
                    JellyBadge(mood: .grumpy, size: 86, wobble: true)
                        .offset(y: float ? -6 : 4)
                    JellyBadge(mood: .happy, size: 118, wobble: true)
                        .offset(y: float ? 4 : -8)
                        .zIndex(1)
                    JellyBadge(mood: .nervous, size: 86, wobble: true)
                        .offset(y: float ? -8 : 2)
                }
                .padding(.bottom, 6)
                VStack(spacing: 6) {
                    Text("Mood Magnets")
                        .font(Theme.display(46))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("Change their moods. Watch them move.")
                        .font(Theme.body(17))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
                Spacer(minLength: 10)
                VStack(spacing: 14) {
                    Button {
                        if let level = progress.resumeLevel { path = [.levels, .play(level.id)] }
                    } label: {
                        Label(progress.totalStars == 0 ? "Play" : "Continue", systemImage: "play.fill")
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(JellyButtonStyle())
                    Button {
                        path = [.levels]
                    } label: {
                        Label("Levels", systemImage: "square.grid.2x2.fill")
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(JellyButtonStyle(color: MoodPalette.color(.nervous)))
                    Button("How to play") { showingHowTo = true }
                        .font(Theme.body(17, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.75))
                        .padding(.top, 4)
                }
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundStyle(Color(uiColor: UIColor(hex: 0xFFB020)))
                    Text("\(progress.totalStars) / \(progress.levels.count * 3)")
                        .font(Theme.body(15, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingHowTo) { HowToPlayView() }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { float = true }
        }
    }
}

struct LevelSelectView: View {
    @Binding var path: [Route]
    @EnvironmentObject private var progress: ProgressStore

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        IconButton(systemName: "chevron.left", label: "Back") { path.removeAll() }
                        Spacer()
                        Text("Levels").font(Theme.display(30)).foregroundStyle(Theme.ink)
                        Spacer()
                        Color.clear.frame(width: 42, height: 42)
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(progress.levels) { level in
                            LevelCard(level: level, stars: progress.stars(for: level), unlocked: progress.isUnlocked(level)) {
                                path.append(.play(level.id))
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct LevelCard: View {
    let level: LevelData
    let stars: Int
    let unlocked: Bool
    let action: () -> Void

    private var featured: Mood {
        level.jellies.first?.mood ?? .happy
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    if unlocked {
                        JellyBadge(mood: featured, size: 52)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Theme.ink.opacity(0.35))
                            .frame(width: 52, height: 52)
                    }
                }
                Text("\(level.id)")
                    .font(Theme.display(24))
                Text(level.name)
                    .font(Theme.body(14, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                StarRow(earned: stars, size: 14)
            }
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white.opacity(unlocked ? 0.72 : 0.38))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white, lineWidth: 2))
                    .shadow(color: Theme.ink.opacity(0.1), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(unlocked ? "Level \(level.id), \(level.name), \(stars) stars" : "Level \(level.id), locked")
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("How to play").font(Theme.display(32))
                        Spacer()
                        IconButton(systemName: "xmark", label: "Close") { dismiss() }
                    }
                    Text("Every jelly has a mood, and moods act like magnets. Pick a mood from the tray, then tap a jelly with a dotted ring to give it that mood. Fill every nest with the right jellies to win.")
                        .font(Theme.body(17, weight: .medium))
                    ForEach(Mood.allCases) { mood in
                        HStack(spacing: 16) {
                            JellyBadge(mood: mood, size: 64, wobble: true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mood.title).font(Theme.display(22)).foregroundStyle(MoodPalette.deepColor(mood))
                                Text(mood.blurb).font(Theme.body(16, weight: .medium))
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.7)))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("A Happy hug cheers a Nervous jelly up.", systemImage: "heart.fill")
                        Label("Nervous jellies jump in fright when they bump something Grumpy.", systemImage: "exclamationmark.triangle.fill")
                        Label("Stones with a ring can change mood too.", systemImage: "circle.dashed")
                        Label("Don't let anyone fall off the bottom!", systemImage: "arrow.down.to.line")
                        Label("Fewer mood changes earn more stars.", systemImage: "star.fill")
                    }
                    .font(Theme.body(16, weight: .semibold))
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.7)))
                }
                .foregroundStyle(Theme.ink)
                .padding(22)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
