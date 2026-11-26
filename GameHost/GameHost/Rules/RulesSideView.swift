import SwiftUI

/// The host's side: the rules for the game on the table, jumpable by section.
struct RulesSideView: View {
    let store: GameStore

    var body: some View {
        if let game = RulesLibrary.game(id: store.state.rulesGameID) {
            RulesPage(game: game, onChooseGame: choose)
        } else {
            GameChooser(onChoose: choose)
        }
    }

    private func choose(_ id: String?) {
        store.state.rulesGameID = id
    }
}

private struct RulesPage: View {
    let game: RulesGame
    let onChooseGame: (String?) -> Void

    var body: some View {
        ScrollViewReader { reader in
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rules")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.inkSecondary)
                        Text(game.name)
                            .font(.title2.bold())
                    }
                    Spacer()
                    GameMenu(selectedID: game.id, onChoose: onChooseGame)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(game.sections) { section in
                            Button(section.title) {
                                withAnimation { reader.scrollTo(section.id, anchor: .top) }
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                            .controlSize(.small)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(game.summary)
                            .font(.callout.italic())
                            .foregroundStyle(Theme.inkSecondary)
                        Text(game.players)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.inkSecondary)
                        ForEach(game.sections) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.title)
                                    .font(.headline)
                                    .accessibilityAddTraits(.isHeader)
                                Text(section.body)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .id(section.id)
                        }
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }
}

private struct GameMenu: View {
    let selectedID: String?
    let onChoose: (String?) -> Void

    var body: some View {
        Menu {
            ForEach(RulesGame.Kind.allCases, id: \.self) { kind in
                Section(kind.rawValue) {
                    ForEach(RulesLibrary.games(of: kind)) { game in
                        Button(game.name) { onChoose(game.id) }
                    }
                }
            }
            Divider()
            Button("All Games", systemImage: "square.grid.2x2") { onChoose(nil) }
        } label: {
            Label("Change Game", systemImage: "book")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .tint(Theme.accent)
    }
}

/// Shown until the host picks a game.
private struct GameChooser: View {
    let onChoose: (String?) -> Void

    var body: some View {
        List {
            ForEach(RulesGame.Kind.allCases, id: \.self) { kind in
                Section(kind.rawValue) {
                    ForEach(RulesLibrary.games(of: kind)) { game in
                        Button {
                            onChoose(game.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.name)
                                    .font(.headline)
                                    .foregroundStyle(Theme.ink)
                                Text(game.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
