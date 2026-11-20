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
    /// A line under the games after a tap on one that is still locked.
    @State private var modeNotice: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Menu")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing))
                    .accessibilityAddTraits(.isHeader)

                section("Game modes") {
                    modeRow(.timed, symbol: "timer", title: "2 Minutes", text: "Two minutes on the clock, which starts on your first swipe. Level up and merge clock tiles to win more time.")
                    modeRow(.endless, symbol: "infinity", title: "Endless", text: "No clock. An extra tile lands after every rotation, and the game ends when no move is left.")
                    modeRow(.fruit, symbol: "leaf.fill", title: "Fruit Salad", text: "No clock, and no numbers: every tile is a fruit. Two cherries make a strawberry, two strawberries an orange, and on up to a star.")
                    modeRow(.shift, symbol: "shuffle", title: "Shape Shift", text: "No clock. Every \(GameEngine.movesPerShift) moves the board itself becomes a new shape: a triangle, a circle, a ring, a cup and more. Unlocks with your first new theme.")
                    modeRow(.twist, symbol: "arrow.left.arrow.right", title: "Twist", text: "No clock. After any turn the board may start turning the other way, and the arrow shows which way is next. An extra tile lands after every turn. Unlocks with your second new theme.")
                    modeRow(.fusion, symbol: "wand.and.stars", title: "Fusion", text: "No clock. After every move one tile changes by itself: it usually doubles, and sometimes halves. Unlocks with your third new theme.")
                    if let modeNotice {
                        Text(modeNotice)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.counter)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Tap a game to play it. Each keeps its own board and best score.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.label)
                        .fixedSize(horizontal: false, vertical: true)

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
                    Text("Every theme has its own moving backdrop, tile shape and sparks. A new theme also brings two boards of its own and bigger effects, and your first one unlocks the Shape Shift game. Win gems with super combos, chains, level prizes, big scores and new best scores.")
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
                    row(symbol: "flame.fill", title: "Combo", text: "Every merge you make before the board turns makes the next burst bigger. Make \(GameStore.heatCombo) or more for a combo; the turn starts the count again.")
                    row(symbol: "link", title: "Chain", text: "When falling tiles merge, and those merge again, that is a chain. Each step of a chain scores more than the last.")
                }

                section("Levels") {
                    row(symbol: "chart.bar.fill", title: "Level up", text: "The bar under your score fills as you play. Each new level changes the board's shape and colour, spins the prize reel and, in the timed game, adds \(Int(GameStore.levelTimeBonus)) seconds.")
                    row(symbol: "gift.fill", title: "Prize reel", text: "Every new level wins coins, a free booster or gems. Now and then it stops on the jackpot: 5 gems.")
                    tileRow(value: 2, kind: .stone, title: "Stone block", text: "From level 2. It never merges and gets in the way. A bomb's blast or the Sweep booster clears it.")
                    row(symbol: "hare.fill", title: "Faster drops", text: "From level 2 a move sometimes drops two new tiles, more often the higher you go. From level \(GameEngine.turnTileLevel) the timed game also drops a tile each time the board turns.")
                    row(symbol: "star.fill", title: "Stars", text: "A game earns one star at level 2, two at level 4 and three at level 6.")
                    row(symbol: "arrow.uturn.forward", title: "Keep going", text: "Once in a game that has ended, \(GameStore.continueCost) gems buy \(Int(GameStore.continueSeconds)) more seconds, or clear \(GameStore.continueClears) tiles when no move is left.")
                }

                section("Board shapes") {
                    blockRow(.wall, title: "Walls", text: "Solid blocks on the board. Tiles stop beside them and cannot merge across them.")
                    blockRow(.hole, title: "Holes", text: "Dark pits in the board. The first tile to slide or fall up to one drops in and is gone, stone blocks too, and it scores nothing. A hole closes after \(GameStore.holeAppetite) tiles. In Shape Shift, holes cut the whole board into a new outline and swallow nothing.")
                    blockRow(.crate, title: "Crates", text: "They block like walls. A merge right beside one, or a bomb's blast, smashes it for \(GameStore.cratePoints) points. Or tap one to open it: that uses a move, and inside may be coins, a gem, a free booster or double points, or trouble: a load of rocks, or the creature that lives in your theme. Every theme has its own: a robot, a crab, a shark, a gum monster, a monkey, a dragon, a T-rex, a yeti, a mole, a pinata or a flying saucer, each with its own trick.")
                    row(symbol: "arrow.clockwise", title: "They turn too", text: "Walls, holes and crates turn with the board. A tile that is in the way when the shape changes jumps to an empty cell.")
                }

                section("Boosters and coins") {
                    boosterRow(.flip, title: "Flip", text: "Turns the board right now, without using up a move.")
                    boosterRow(.sweep, title: "Sweep", text: "Clears every 2, 4 and stone block off the board.")
                    boosterRow(.fever, title: "Double", text: "Starts double points for \(Int(GameStore.feverSeconds)) seconds.")
                    boosterRow(.arm, title: "Bombs", text: "Turns up to \(GameStore.armedTiles) of your tiles into bomb tiles.")
                    coinRow(title: "Coins", text: "You start with \(GameStore.freeBoosters) free uses of each booster. After that a use costs coins, and you earn a coin for every \(GameStore.pointsPerCoin) points.")
                    streakRow(title: "Speed bonus", text: "Merge again within \(Int(GameStore.streakWindow)) seconds and your points multiply, up to x\(GameStore.maxStreak + 1). Lightning strikes each time it goes up.")
                }

                section("Power-ups") {
                    tileRow(value: 2, kind: .time, title: "Clock tile", text: "Merge it to add \(Int(GameStore.timeBonus)) seconds to the clock. Timed game only.")
                    tileRow(value: 4, kind: .bomb, title: "Bomb tile", text: "Merge it to blast away every tile touching it. Each one scores its number, and a bomb caught in the blast goes off too.")
                    row(symbol: "flame.fill", title: "Double points", text: "A chain of \(GameStore.feverChain) or more doubles every point for \(Int(GameStore.feverSeconds)) seconds. The board glows pink while it lasts.")
                    row(symbol: "gift.fill", title: "Chain reward", text: "Every chain also drops a clock or bomb tile onto the board, with a flash, and sets off your theme's big moment.")
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

    /// A row whose picture is the booster's own button.
    private func boosterRow(_ booster: GameStore.Booster, title: String, text: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        let tones = BoosterBar.colors(booster)
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: BoosterBar.symbol(booster))
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
                .background(shape.fill(LinearGradient(colors: tones, startPoint: .top, endPoint: .bottom)))
                .overlay(shape.strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5))
                .shadow(color: tones[1].opacity(0.7), radius: 5)
                .accessibilityHidden(true)
            words(title: title, text: text)
        }
        .accessibilityElement(children: .combine)
    }

    /// A row whose picture is a gold coin, as in the counter at the top of the game.
    private func coinRow(title: String, text: String) -> some View {
        let gold = LinearGradient(colors: [Color(hex: 0xFFE26A), Color(hex: 0xFF9F2E)], startPoint: .top, endPoint: .bottom)
        return HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(gold)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5))
                .frame(width: 30, height: 30)
                .shadow(color: Color(hex: 0xFFB02E).opacity(0.8), radius: 5)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            words(title: title, text: text)
        }
        .accessibilityElement(children: .combine)
    }

    /// A row whose picture is the speed-bonus chip that shows beside the board.
    private func streakRow(title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            StreakChip(multiplier: 2, scale: 0.85)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            words(title: title, text: text)
        }
        .accessibilityElement(children: .combine)
    }

    /// A row whose picture is the obstacle itself, drawn as it is on the board.
    private func blockRow(_ kind: BlockKind, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if kind == .hole {
                    PitView(size: 44)
                } else {
                    ObstacleView(kind: kind, size: 44)
                }
            }
            .frame(width: 44, height: 44)
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

    /// One game in the list: tap it to play it.
    private func modeRow(_ mode: GameStore.Mode, symbol: String, title: String, text: String) -> some View {
        let isOn = store.mode == mode
        let isLocked = !store.isUnlocked(mode)
        let card = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            if isLocked {
                let needed = GameStore.themesNeeded(for: mode)
                modeNotice = needed > 1
                    ? "\(title) unlocks once you have \(needed) new themes."
                    : "\(title) unlocks with your first new theme."
            } else {
                modeNotice = nil
                store.switchMode(mode)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isLocked ? "lock.fill" : symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isOn ? Color.white : Theme.flip[0])
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(isOn ? Theme.pillTop : Theme.cellFill))
                words(title: title, text: text)
                Spacer(minLength: 4)
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: 0x86F2BC))
                }
            }
            .multilineTextAlignment(.leading)
            .padding(10)
            .background(card.fill(Theme.cellFill.opacity(isOn ? 0.9 : 0.4)))
            .overlay(card.strokeBorder(isOn ? Color(hex: 0x86F2BC) : Theme.glassStroke, lineWidth: isOn ? 2 : 1))
            .opacity(isLocked ? 0.7 : 1)
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title). \(text)" + (isOn ? " Playing now." : "") + (isLocked ? " Locked." : "")))
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
                if skin.isPremium {
                    Text("+\(skin.boards.count) boards · bigger effects")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.counter)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                themeTag(skin, owned: owned, inUse: inUse)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    if PaintedBackdrop.has(skin) {
                        PaintedBackdrop(skin: skin, isLive: false)
                        SceneView(skin: skin, isPainted: true)
                    } else {
                        LinearGradient(
                            colors: [Theme.chrome(0x1D2F8F, skin: skin), Theme.chrome(0x070A26, skin: skin)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        SceneView(skin: skin)
                    }
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
