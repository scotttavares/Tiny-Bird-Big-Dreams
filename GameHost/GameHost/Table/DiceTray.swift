import SwiftUI

/// The dice everyone can see. Tap the tray to roll; the last few rolls sit underneath.
struct DiceTray: View {
    let store: GameStore

    @State private var rollCount = 0

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: roll) {
                    HStack(spacing: 8) {
                        ForEach(Array(store.state.dice.enumerated()), id: \.offset) { _, value in
                            Image(systemName: "die.face.\(value)")
                                .font(.system(size: 40))
                                .symbolEffect(.bounce, value: rollCount)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Roll the dice")
                .accessibilityValue(diceDescription(store.state.dice))
                Stepper("Dice: \(store.state.diceCount)", value: Binding(
                    get: { store.state.diceCount },
                    set: { store.state.setDiceCount($0) }
                ), in: 1...GameState.maxDice)
                .labelsHidden()
                .accessibilityLabel("Number of dice")
                .accessibilityValue("\(store.state.diceCount)")
            }
            Text(recentText)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline))
        .sensoryFeedback(.impact(weight: .light), trigger: rollCount)
    }

    private var recentText: String {
        let rolls = store.state.recentRolls
        guard !rolls.isEmpty else { return "Tap the dice to roll" }
        return "Total \(rolls[0].reduce(0, +))  ·  Before: " + rolls.dropFirst().map { roll in
            roll.map(String.init).joined(separator: "+")
        }.joined(separator: "  ")
    }

    private func diceDescription(_ dice: [Int]) -> String {
        dice.map(String.init).joined(separator: ", ")
    }

    private func roll() {
        store.state.roll()
        rollCount += 1
    }
}
