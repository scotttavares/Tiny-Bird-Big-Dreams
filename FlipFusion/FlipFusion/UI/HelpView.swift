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
    /// A line under the themes after a tap on one that is not yet the player's.
    @State private var themeNotice: String?

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
                        Text("Shape Shift").tag(GameStore.Mode.shift)
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
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(Skin.all) { skin in
                            themeCard(skin)
                        }
                    }
                    if let themeNotice {
                        Text(themeNotice)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.counter)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Every theme has its own moving backdrop, tile shape and sparks. Win gems with super combos, chains, level prizes, big scores and new best scores.")
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

                section("Levels") {
                    row(symbol: "chart.bar.fill", title: "Level up", text: "The bar under your score fills as you play. Each new level changes the board's shape and colour, spins the prize reel and, in the timed game, adds \(Int(GameStore.levelTimeBonus)) seconds.")
                    row(symbol: "gift.fill", title: "Prize reel", text: "Every new level wins coins, a free booster or gems. Now and then it stops on the jackpot: 5 gems.")
                    tileRow(value: 2, kind: .stone, title: "Stone block", text: "From level 3. It never merges and gets in the way. A bomb's blast or the Sweep booster clears it.")
                    row(symbol: "hare.fill", title: "Faster drops", text: "From level 4 a move sometimes drops two new tiles, more often the higher you go.")
                    row(symbol: "star.fill", title: "Stars", text: "A game earns one star at level 2, two at level 4 and three at level 6.")
                    row(symbol: "arrow.uturn.forward", title: "Keep going", text: "Once in a game that has ended, \(GameStore.continueCost) gems buy \(Int(GameStore.continueSeconds)) more seconds, or clear \(GameStore.continueClears) tiles when no move is left.")
                }

                section("Board shapes") {
                    row(symbol: "square.grid.2x2.fill", title: "Walls", text: "Solid blocks on the board. Tiles stop beside them and cannot merge across them.")
                    row(symbol: "circle.dashed", title: "Holes", text: "Gaps cut out of the board. Tiles stop beside them too.")
                    row(symbol: "shippingbox.fill", title: "Crates", text: "They block like walls, but a merge right beside one, or a bomb's blast, smashes it for \(GameStore.cratePoints) points.")
                    row(symbol: "arrow.clockwise", title: "They turn too", text: "Walls, holes and crates turn with the board. A tile that is in the way when the shape changes jumps to an empty cell.")
                }

                section("Boosters and coins") {
                    row(symbol: BoosterBar.symbol(.flip), title: "Flip", text: "Turns the board right now, without using up a move.")
                    row(symbol: BoosterBar.symbol(.sweep), title: "Sweep", text: "Clears every 2, 4 and stone block off the board.")
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
                    row(symbol: "timer", title: "Timed", text: "Two minutes on the clock, which starts on your first swipe. Level up and merge clock tiles to win more time.")
                    row(symbol: "infinity", title: "Endless", text: "No clock. An extra tile lands after every rotation, and the game ends when no move is left.")
                    row(symbol: "shuffle", title: "Shape Shift", text: "No clock. Every \(GameEngine.movesPerShift) moves the board changes to a new shape picked at random. The game ends when no move is left.")
                    Text("Tap 2 Minutes, Endless or Shape Shift under the board to switch. Each mode keeps its own game and best score.")
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
            ForEach(Array(shop.products.enumerated()), id: \.element.id) { index, product in
                packCard(shop, product, index: index)
            }
            Text("Gems unlock themes and let you keep a finished game going. They are bought with real money through the App Store and cannot be exchanged or refunded for cash.")
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

    /// One pack of gems: a pile of gems, how many, what it saves, and the price.
    private func packCard(_ shop: GemShop, _ product: Product, index: Int) -> some View {
        let count = GemShop.pack(for: product.id)?.gems ?? 0
        let isBest = index > 0 && index == shop.products.count - 1
        let isPopular = index == 1 && shop.products.count > 2
        let bonus = shop.bonusPercent(for: product)
        let card = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let gold = Color(hex: 0xFFD23F)
        return Button {
            Task {
                await shop.buy(product)
            }
        } label: {
            HStack(spacing: 12) {
                gemPile(index + 1)
                VStack(alignment: .leading, spacing: 3) {
                    if isBest || isPopular {
                        Text(isBest ? "BEST VALUE" : "POPULAR")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: 0x201400))
                            .padding(.horizontal, 8)
                            .frame(height: 18)
                            .background(Capsule().fill(gold))
                    }
                    Text("\(count) gems")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                    if bonus > 0 {
                        Text("\(bonus)% more gems per dollar")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(gold)
                    }
                }
                Spacer(minLength: 8)
                Text(product.displayPrice)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(Capsule().fill(LinearGradient(colors: Theme.flip.reversed(), startPoint: .top, endPoint: .bottom)))
                    .shadow(color: Theme.flip[1].opacity(0.6), radius: 6)
            }
            .padding(12)
            .background(card.fill(Theme.cellFill))
            .overlay(card.strokeBorder(isBest ? gold : Theme.glassStroke, lineWidth: isBest ? 2 : 1))
        }
        .buttonStyle(BounceButtonStyle())
        .disabled(shop.isBuying)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Buy \(count) gems for \(product.displayPrice)"))
    }

    /// One, two or three gems in a little pile.
    private func gemPile(_ count: Int) -> some View {
        let shown = max(1, min(3, count))
        return ZStack {
            ForEach(0..<shown, id: \.self) { index in
                gem(size: 22)
                    .offset(x: (CGFloat(index) - CGFloat(shown - 1) / 2) * 12, y: index == 1 ? -8 : 0)
            }
        }
        .frame(width: 56, height: 48)
        .background(Circle().fill(Theme.boardFill))
    }

    /// Puts a theme on. The screen behind the menu redraws in its colours.
    private func use(_ skin: Skin) {
        Skin.current = skin
        skinID = skin.id
    }

    /// A tap on a theme card: put it on, buy it, or say what it takes to get it.
    private func pick(_ skin: Skin) {
        themeNotice = nil
        if store.owns(skin) {
            use(skin)
        } else if case .gems(let price) = skin.unlock {
            if store.buy(skin) {
                use(skin)
            } else {
                themeNotice = "\(skin.name) costs \(price) gems. You need \(price - store.gems) more."
            }
        } else {
            themeNotice = "\(skin.name): \(skin.howToGet.lowercased()) to unlock it."
        }
    }

    /// One theme as a card: three of its tiles in front of its moving backdrop.
    private func themeCard(_ skin: Skin) -> some View {
        let owned = store.owns(skin)
        let inUse = skinID == skin.id
        let card = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let state = inUse ? "In use" : (owned ? "Yours, tap to use" : skin.howToGet)
        return Button {
            pick(skin)
        } label: {
            VStack(spacing: 7) {
                HStack(spacing: 5) {
                    TileView(value: 2, size: 36, skin: skin)
                    TileView(value: 8, size: 36, skin: skin)
                    TileView(value: 32, size: 36, skin: skin)
                }
                .padding(.top, 16)
                Text(skin.name)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(skin.blurb)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)
                themeTag(skin, owned: owned, inUse: inUse)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Theme.chrome(0x1D2F8F, skin: skin), Theme.chrome(0x070A26, skin: skin)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    SceneView(skin: skin)
                }
            }
            .clipShape(card)
            .overlay(card.strokeBorder(inUse ? Color(hex: 0x86F2BC) : Color.white.opacity(0.28), lineWidth: inUse ? 3 : 1))
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(skin.name) theme. \(state)"))
    }

    /// The label at the foot of a theme card: in use, yours, its price, or its lock.
    @ViewBuilder
    private func themeTag(_ skin: Skin, owned: Bool, inUse: Bool) -> some View {
        if inUse {
            tag(fill: Color(hex: 0x1F9D63)) {
                Image(systemName: "checkmark")
                Text("In use")
            }
        } else if owned {
            tag(fill: Color.white.opacity(0.22)) {
                Text("Use")
            }
        } else if case .gems(let price) = skin.unlock {
            tag(fill: Color(hex: 0x4332C8)) {
                gem(size: 12)
                Text("\(price)")
            }
            .opacity(store.gems >= price ? 1 : 0.7)
        } else {
            tag(fill: Color.black.opacity(0.4)) {
                Image(systemName: "lock.fill")
                Text(skin.lockLabel)
            }
        }
    }

    private func tag<Content: View>(fill: Color, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 4) {
            content()
        }
        .font(.system(size: 13, weight: .heavy, design: .rounded))
        .foregroundStyle(Color.white)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
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
