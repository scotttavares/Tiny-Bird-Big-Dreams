import SwiftUI

/// Today's three quests, with the coin jar and the stars under them.
struct QuestsView: View {
    let store: GameStore
    let sounds: SoundPlayer

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let quests = store.quests
        let progress = store.questProgress
        let collected = store.questsCollected

        VStack(spacing: 0) {
            HStack {
                Text("Rewards")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    heading("Today's quests", line: "Collect all three for +\(GameStore.questBonus) coins and a gem. New quests every day.")
                    ForEach(0..<3, id: \.self) { index in
                        questRow(index, quest: quests[index], count: progress[index], isCollected: collected[index])
                    }

                    heading("Coin jar", line: "Every coin you score in the stage game drops one in the jar. It opens at each big chest stage.")
                    meter(
                        symbol: "banknote.fill",
                        words: "\(store.jar) of \(GameStore.jarLimit) coins",
                        fraction: Double(store.jar) / Double(GameStore.jarLimit)
                    )

                    heading("Stars", line: "Clear a stage quickly for more stars. Stars open star chests.")
                    if let mark = store.nextStarMark {
                        meter(
                            symbol: "star.fill",
                            words: "\(store.starTotal) of \(mark) stars to the next star chest",
                            fraction: Double(store.starTotal) / Double(mark)
                        )
                    } else {
                        meter(symbol: "star.fill", words: "\(store.starTotal) stars: every star chest is open", fraction: 1)
                    }

                    heading("Winning run", line: "Three stages in a row start you with a free bomb. Five in a row, with two.")
                    meter(
                        symbol: "flame.fill",
                        words: store.stageStreak == 1 ? "1 stage in a row" : "\(store.stageStreak) stages in a row",
                        fraction: Double(min(5, store.stageStreak)) / 5
                    )
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .background(Color(hex: 0x070A26).ignoresSafeArea())
    }

    private func heading(_ title: String, line: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
            Text(line)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.label)
        }
        .padding(.top, 8)
    }

    private func bar(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.cellFill)
                Capsule()
                    .fill(LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.height, geo.size.width * CGFloat(max(0, min(1, fraction)))))
            }
        }
        .frame(height: 9)
    }

    private func meter(symbol: String, words: String, fraction: Double) -> some View {
        let card = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.counter)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.cellFill))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(words)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                bar(fraction)
            }
        }
        .padding(12)
        .background(card.fill(Theme.cellFill.opacity(0.5)))
        .overlay(card.strokeBorder(Theme.glassStroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func questRow(_ index: Int, quest: GameStore.Quest, count: Int, isCollected: Bool) -> some View {
        let isDone = count >= quest.target
        let card = RoundedRectangle(cornerRadius: 16, style: .continuous)
        // A tile quest is done or not; the others count up.
        let counted = quest.kind == .bigTile ? (isDone ? "Done" : "Biggest so far: \(count)") : "\(min(count, quest.target)) of \(quest.target)"
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(quest.words)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                bar(Double(count) / Double(max(1, quest.target)))
                Text(counted)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.label)
            }
            if isCollected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(hex: 0x86F2BC))
                    .frame(width: 92)
            } else {
                Button {
                    if store.claimQuest(index) {
                        sounds.play(.bonus)
                    }
                } label: {
                    HStack(spacing: 4) {
                        CoinIcon(size: 16)
                        Text(isDone ? "Collect" : "+\(quest.coins)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 92, height: 36)
                    .background(Capsule().fill(LinearGradient(colors: Theme.flip.reversed(), startPoint: .top, endPoint: .bottom)))
                    .opacity(isDone ? 1 : 0.45)
                }
                .buttonStyle(BounceButtonStyle())
                .disabled(!isDone)
            }
        }
        .padding(12)
        .background(card.fill(Theme.cellFill.opacity(0.5)))
        .overlay(card.strokeBorder(isDone && !isCollected ? Theme.counter : Theme.glassStroke, lineWidth: isDone && !isCollected ? 2 : 1))
        .accessibilityElement(children: .combine)
    }
}
