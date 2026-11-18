import SwiftUI

/// The menu: game mode, settings and a new game at the top, then "How to play"
/// (the rules, the power-ups and the two modes), all on one sheet.
struct HelpView: View {
    let store: GameStore
    let onReplayIntro: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SoundPlayer.enabledKey) private var soundOn = true
    @AppStorage("ff.hapticsOn") private var hapticsOn = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Menu")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing))
                    .accessibilityAddTraits(.isHeader)

                section("Game") {
                    Picker("Game mode", selection: Binding(
                        get: { store.mode },
                        set: { store.switchMode($0) }
                    )) {
                        Text("Timed").tag(GameStore.Mode.timed)
                        Text("Endless").tag(GameStore.Mode.endless)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        store.newGame()
                        dismiss()
                    } label: {
                        Text("Start a new game")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Capsule().fill(LinearGradient(colors: [Theme.pillTop, Theme.pillBottom], startPoint: .top, endPoint: .bottom)))
                            .overlay(Capsule().strokeBorder(Theme.pillStroke, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }

                section("Settings") {
                    Toggle("Sound effects", isOn: $soundOn)
                    Toggle("Vibration", isOn: $hapticsOn)
                    Button {
                        dismiss()
                        onReplayIntro()
                    } label: {
                        Text("Replay the intro")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.flip[0])
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .tint(Theme.pillStroke)

                Text("How to play")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white)
                    .accessibilityAddTraits(.isHeader)

                section("The basics") {
                    row(symbol: "hand.draw.fill", title: "Swipe", text: "Every tile slides as far as it can. Two tiles with the same number merge into one worth double.")
                    row(symbol: "arrow.clockwise", title: "Rotate", text: "After every two moves the board makes a quarter turn and gravity pulls the tiles down.")
                    row(symbol: "link", title: "Chain", text: "When falling tiles merge, and those merge again, that is a chain. Each step of a chain scores more than the last.")
                }

                section("Power-ups") {
                    tileRow(value: 2, kind: .time, title: "Clock tile", text: "Merge it to add \(Int(GameStore.timeBonus)) seconds to the clock. Timed game only.")
                    tileRow(value: 4, kind: .bomb, title: "Bomb tile", text: "Merge it to blast away every tile touching it. Each one scores its number.")
                    row(symbol: "flame.fill", title: "Double points", text: "A chain of \(GameStore.feverChain) or more doubles every point for \(Int(GameStore.feverSeconds)) seconds. The board glows pink while it lasts.")
                    row(symbol: "gift.fill", title: "Chain reward", text: "Every chain also drops a clock or bomb tile onto the board.")
                }

                section("Game modes") {
                    row(symbol: "timer", title: "Timed", text: "Two minutes to score as much as you can. The clock starts on your first swipe.")
                    row(symbol: "infinity", title: "Endless", text: "No clock. An extra tile lands after every rotation, and the game ends when no move is left.")
                    Text("Tap the dots under the board to switch. Each mode keeps its own game and best score.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.label)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Back to the game")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(LinearGradient(colors: Theme.flip.reversed(), startPoint: .top, endPoint: .bottom)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(24)
        }
        .background(
            LinearGradient(colors: [Theme.backgroundTop, Theme.backgroundBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .presentationDragIndicator(.visible)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.counter)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.glassFill))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.glassStroke, lineWidth: 1))
    }

    private func row(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.flip[0])
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.cellFill))
                .accessibilityHidden(true)
            words(title: title, text: text)
        }
        .accessibilityElement(children: .combine)
    }

    private func tileRow(value: Int, kind: TileKind, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            TileView(value: value, kind: kind, size: 44)
                .accessibilityHidden(true)
            words(title: title, text: text)
        }
        .accessibilityElement(children: .combine)
    }

    private func words(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.tagline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
