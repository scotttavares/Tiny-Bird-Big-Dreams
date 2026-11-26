import SwiftUI

/// The coin shop: packs of boosters, and gems, paid for with the coins won by playing.
/// Nothing here costs money.
struct ShopView: View {
    let store: GameStore
    let sounds: SoundPlayer

    @Environment(\.dismiss) private var dismiss
    @State private var notice: String?

    private static func title(_ item: GameStore.ShopItem) -> String {
        if let booster = item.booster {
            return "3 x " + BoosterBar.name(booster)
        }
        return item == .mixed ? "Booster box" : "1 gem"
    }

    private static func line(_ item: GameStore.ShopItem) -> String {
        if item.booster != nil {
            return "Three for the price of two"
        }
        return item == .mixed ? "One of every booster" : "Gems carry a finished game on"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Coin Shop")
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

            HStack(spacing: 6) {
                CoinIcon(size: 22)
                Text(store.coins.formatted(.number.grouping(.automatic)))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.counter)
                    .contentTransition(.numericText())
                Text("to spend")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.label)
            }
            .padding(.top, 8)

            Text(notice ?? "Win coins by scoring, clearing stages and opening the daily chest.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(notice == nil ? Theme.label : Theme.counter)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .frame(minHeight: 40)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(GameStore.ShopItem.allCases) { item in
                        row(item)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .background(Color(hex: 0x070A26).ignoresSafeArea())
    }

    @ViewBuilder
    private func picture(_ item: GameStore.ShopItem) -> some View {
        if let booster = item.booster {
            BoosterIcon(booster: booster, side: 46)
        } else if item == .mixed {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE26A), Color(hex: 0xFF9F2E)], startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 46)
        } else {
            Image(systemName: "diamond.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0x8FF0FF), Color(hex: 0xC08CFF)], startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 46)
        }
    }

    private func row(_ item: GameStore.ShopItem) -> some View {
        let canPay = store.coins >= item.price
        let title = Self.title(item)
        let card = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            if store.buy(item) {
                sounds.play(.bonus)
                notice = title + " bought!"
            } else {
                sounds.play(.tick)
                let short = (item.price - store.coins).formatted(.number.grouping(.automatic))
                notice = "You need \(short) more coins for that."
            }
        } label: {
            HStack(spacing: 12) {
                picture(item)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(Self.line(item))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.label)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    CoinIcon(size: 18)
                    Text(item.price.formatted(.number.grouping(.automatic)))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Capsule().fill(LinearGradient(colors: Theme.flip.reversed(), startPoint: .top, endPoint: .bottom)))
                .opacity(canPay ? 1 : 0.45)
            }
            .padding(12)
            .background(card.fill(Theme.cellFill.opacity(0.5)))
            .overlay(card.strokeBorder(Theme.glassStroke, lineWidth: 1))
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title), \(item.price) coins." + (canPay ? "" : " Not enough coins.")))
    }
}
