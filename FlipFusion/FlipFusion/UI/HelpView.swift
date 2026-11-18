import StoreKit
import SwiftUI

/// The menu: game mode, themes, settings and a new game at the top, then "How to
/// play" (the rules, the boosters, the power-ups and the two modes), all on one sheet.
struct HelpView: View {
    let store: GameStore
    let shop: GemShop?
    let onReplayIntro: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SoundPlayer.enabledKey) private var soundOn = true
    @AppStorage(SoundPlayer.musicKey) private var musicOn = true
    @AppStorage("ff.hapticsOn") private var hapticsOn = true
    @AppStorage(Skin.key) private var skinID = "neon"

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

                section("Themes") {
                    HStack(spacing: 6) {
                        gem(size: 16)
                        Text("\(store.gems) gems")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)
                    }
                    ForEach(Skin.all) { skin in
                        themeRow(skin)
                    }
                    Text("Win gems with super combos, chains, big scores and new best scores.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.label)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let shop {
                    section("Get more gems") {
                        gemPacks(shop)
                    }
                }

                section("Settings") {
                    Toggle("Music", isOn: $musicOn)
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
                    row(symbol: "sparkles", title: "Super combo", text: "Line up three or four of the same tile and they all merge at once: three 2s make an 8, four make a 16, and each wins a gem or more.")
                    row(symbol: "link", title: "Chain", text: "When falling tiles merge, and those merge again, that is a chain. Each step of a chain scores more than the last.")
                }

                section("Boosters and coins") {
                    row(symbol: BoosterBar.symbol(.flip), title: "Flip", text: "Turns the board right now, without using up a move.")
                    row(symbol: BoosterBar.symbol(.sweep), title: "Sweep", text: "Clears every 2 and 4 off the board.")
                    row(symbol: BoosterBar.symbol(.fever), title: "Double", text: "Starts double points for \(Int(GameStore.feverSeconds)) seconds.")
                    row(symbol: BoosterBar.symbol(.arm), title: "Bombs", text: "Turns up to \(GameStore.armedTiles) of your tiles into bomb tiles.")
                    row(symbol: "circle.circle.fill", title: "Coins", text: "You start with \(GameStore.freeBoosters) free uses of each booster. After that a use costs coins, and you earn a coin for every \(GameStore.pointsPerCoin) points.")
                    row(symbol: "bolt.fill", title: "Speed bonus", text: "Merge again within \(Int(GameStore.streakWindow)) seconds and your points multiply, up to x\(GameStore.maxStreak + 1).")
                }

                section("Power-ups") {
                    tileRow(value: 2, kind: .time, title: "Clock tile", text: "Merge it to add \(Int(GameStore.timeBonus)) seconds to the clock. Timed game only.")
                    tileRow(value: 4, kind: .bomb, title: "Bomb tile", text: "Merge it to blast away every tile touching it. Each one scores its number, and a bomb caught in the blast goes off too.")
                    row(symbol: "flame.fill", title: "Double points", text: "A chain of \(GameStore.feverChain) or more doubles every point for \(Int(GameStore.feverSeconds)) seconds. The board glows pink while it lasts.")
                    row(symbol: "gift.fill", title: "Chain reward", text: "Every chain also drops a clock or bomb tile onto the board.")
                }

                section("Game modes") {
                    row(symbol: "timer", title: "Timed", text: "Two minutes to score as much as you can. The clock starts on your first swipe.")
                    row(symbol: "infinity", title: "Endless", text: "No clock. An extra tile lands after every rotation, and the game ends when no move is left.")
                    Text("Tap 2 Minutes or Endless under the board to switch. Each mode keeps its own game and best score.")
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
                .id(skinID)
                .accessibilityHidden(true)
            words(title: title, text: text)
        }
        .accessibilityElement(children: .combine)
    }

    private func gem(size: CGFloat) -> some View {
        Image(systemName: "diamond.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(LinearGradient(colors: [Color(hex: 0x8FF0FF), Color(hex: 0xC08CFF)], startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)
    }

    /// The packs of gems on sale, with the App Store's own prices.
    @ViewBuilder
    private func gemPacks(_ shop: GemShop) -> some View {
        if shop.products.isEmpty {
            Text(shop.isUnavailable ? "The gem shop is not available right now." : "Opening the gem shop…")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.label)
            if shop.isUnavailable {
                Button {
                    Task {
                        await shop.load()
                    }
                } label: {
                    chip {
                        Text("Try again")
                    }
                }
                .buttonStyle(BounceButtonStyle())
            }
        } else {
            ForEach(shop.products, id: \.id) { product in
                let count = GemShop.pack(for: product.id)?.gems ?? 0
                HStack(spacing: 12) {
                    gem(size: 22)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.cellFill))
                    Text("\(count) gems")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                    Spacer(minLength: 8)
                    Button {
                        Task {
                            await shop.buy(product)
                        }
                    } label: {
                        chip {
                            Text(product.displayPrice)
                        }
                    }
                    .buttonStyle(BounceButtonStyle())
                    .disabled(shop.isBuying)
                    .accessibilityLabel(Text("Buy \(count) gems for \(product.displayPrice)"))
                }
            }
            Text("Gems are bought with real money through the App Store. They buy themes and cannot be exchanged or refunded for cash.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let notice = shop.notice {
            Text(notice)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.counter)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Puts a theme on. The screen behind the menu redraws in its colours.
    private func use(_ skin: Skin) {
        Skin.current = skin
        skinID = skin.id
    }

    /// One theme: its colours, its name, and a button to use or buy it.
    private func themeRow(_ skin: Skin) -> some View {
        let owned = store.owns(skin)
        let inUse = skinID == skin.id
        let colors = Theme.preview(skin)
        return HStack(spacing: 12) {
            HStack(spacing: -7) {
                ForEach(0..<colors.count, id: \.self) { index in
                    Circle()
                        .fill(colors[index])
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 1))
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(skin.name)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                Text(inUse ? "In use" : (owned ? "Yours" : skin.howToGet))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.tagline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            themeButton(skin, owned: owned, inUse: inUse)
        }
    }

    @ViewBuilder
    private func themeButton(_ skin: Skin, owned: Bool, inUse: Bool) -> some View {
        if inUse {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(hex: 0x86F2BC))
                .accessibilityLabel(Text("In use"))
        } else if owned {
            Button {
                use(skin)
            } label: {
                chip {
                    Text("Use")
                }
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityLabel(Text("Use the \(skin.name) theme"))
        } else if case .gems(let price) = skin.unlock {
            Button {
                if store.buy(skin) {
                    use(skin)
                }
            } label: {
                chip {
                    gem(size: 13)
                    Text("\(price)")
                }
            }
            .buttonStyle(BounceButtonStyle())
            .opacity(store.gems >= price ? 1 : 0.45)
            .accessibilityLabel(Text("Buy the \(skin.name) theme for \(price) gems"))
        } else {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.label)
                .frame(width: 44, height: 36)
                .accessibilityLabel(Text("Locked"))
        }
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 4) {
            content()
        }
        .font(.system(size: 15, weight: .heavy, design: .rounded))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 14)
        .frame(minWidth: 62, minHeight: 36)
        .background(Capsule().fill(LinearGradient(colors: [Theme.pillTop, Theme.pillBottom], startPoint: .top, endPoint: .bottom)))
        .overlay(Capsule().strokeBorder(Theme.pillStroke, lineWidth: 1.5))
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
