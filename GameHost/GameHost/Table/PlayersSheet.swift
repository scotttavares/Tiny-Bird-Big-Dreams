import SwiftUI

/// Add, rename and remove players, and start a new game with the same group.
struct PlayersSheet: View {
    let store: GameStore

    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var isConfirmingNewGame = false

    var body: some View {
        NavigationStack {
            List {
                Section("Players") {
                    ForEach(store.state.players) { player in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Theme.text(player.color))
                                .frame(width: 12, height: 12)
                                .accessibilityHidden(true)
                            TextField("Name", text: Binding(
                                get: { player.name },
                                set: { store.state.renamePlayer(player.id, to: $0) }
                            ))
                            Text("\(player.score)")
                                .monospacedDigit()
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }
                    .onDelete { offsets in
                        for id in offsets.map({ store.state.players[$0].id }) {
                            store.state.removePlayer(id)
                        }
                    }
                    if store.state.players.count < GameState.maxPlayers {
                        HStack {
                            TextField("Add a player", text: $newName)
                                .onSubmit(add)
                            Button("Add", systemImage: "plus.circle.fill", action: add)
                                .labelStyle(.iconOnly)
                                .tint(Theme.accent)
                        }
                    }
                }
                Section {
                    Button("New Game", systemImage: "arrow.counterclockwise") { isConfirmingNewGame = true }
                        .tint(Theme.accent)
                } footer: {
                    Text("Keeps everyone at the table and sets every score back to 0.")
                }
            }
            .navigationTitle("Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Start a new game?", isPresented: $isConfirmingNewGame, titleVisibility: .visible) {
                Button("New Game", role: .destructive) {
                    store.state.newGame(now: .now)
                    dismiss()
                }
            } message: {
                Text("Every score goes back to 0.")
            }
        }
    }

    private func add() {
        store.state.addPlayer(named: newName)
        newName = ""
    }
}
