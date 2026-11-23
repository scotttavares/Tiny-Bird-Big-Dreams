import SwiftUI

/// The daily chest: a card over the game, once a day. It shows which day of the
/// seven-day run this is and what is inside.
struct DailyChestCard: View {
    let gift: GameStore.DailyGift
    let onCollect: () -> Void

    private var words: String {
        var parts = ["+\(gift.coins) coins"]
        if gift.gems > 0 {
            parts.append(gift.gems == 1 ? "+1 gem" : "+\(gift.gems) gems")
        }
        if let booster = gift.booster {
            parts.append("Free " + BoosterBar.name(booster))
        }
        return parts.joined(separator: "  ·  ")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}

            VStack(spacing: 12) {
                Text("Daily Chest")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing))
                Text("Day \(gift.day) of 7")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.label)

                // The chest's film: it rattles, bursts open and spills its coins, then
                // stays open. A still chest stands in when the film is not in the app.
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xFFB02E, opacity: 0.3))
                        .frame(width: 150, height: 150)
                        .blur(radius: 28)
                    if ObstacleArt.has("prop-chest-f00") {
                        // Wider than the card, so the coins spill past its edges.
                        ChestFilm(width: 320)
                    } else if ObstacleArt.has("prop-chest") {
                        Image("prop-chest")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                    } else {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE26A), Color(hex: 0xFF9F2E)], startPoint: .top, endPoint: .bottom))
                    }
                }
                .frame(height: 220)

                // Seven days: the ones behind you are lit, today glows.
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        Capsule()
                            .fill(day < gift.day ? Theme.fusion[0] : (day == gift.day ? Theme.counter : Color.white.opacity(0.18)))
                            .frame(width: day == 7 ? 30 : 22, height: 8)
                    }
                }

                Text(words)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.counter)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(gift.day == 7 ? "The big one. Come back tomorrow to start again." : "Come back tomorrow for a bigger chest.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.label)
                    .multilineTextAlignment(.center)

                Button(action: onCollect) {
                    Text("Collect")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 44)
                        .frame(height: 52)
                        .background(Capsule().fill(LinearGradient(colors: Theme.flip.reversed(), startPoint: .top, endPoint: .bottom)))
                        .shadow(color: Theme.flip[1].opacity(0.7), radius: 10)
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(hex: 0x070A26, opacity: 0.97)))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5))
            .padding(.horizontal, 24)
        }
    }
}

/// The treasure chest's film, played once from the first frame: the chest rattles,
/// bursts open and spills its coins, and the last frame stays on screen.
struct ChestFilm: View {
    let width: CGFloat
    /// How many frames the film has, and how many are shown each second.
    static let frames = 46
    static let speed = 12.0

    @State private var start = Date()

    var body: some View {
        let began = start
        TimelineView(.animation(minimumInterval: 1 / ChestFilm.speed)) { timeline in
            let passed = timeline.date.timeIntervalSince(began)
            let frame = min(ChestFilm.frames - 1, max(0, Int(passed * ChestFilm.speed)))
            Image("prop-chest-f" + (frame < 10 ? "0" : "") + String(frame))
                .resizable()
                .scaledToFit()
                .frame(width: width)
        }
        .onAppear {
            start = Date()
        }
        .accessibilityHidden(true)
    }
}

/// The trail of the stage map as one line through the stops.
struct TrailShape: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

/// The adventure map: a painted trail through the worlds, eight stages to a world.
/// Cleared stages show their stars, chests wait on every fifth stop, and a marker
/// stands on the stage to play. After a cleared stage the marker walks on to the
/// next stop and the trail lights up behind it.
struct StageMapView: View {
    /// The stage to play next.
    let stage: Int
    /// Stars won on each cleared stage, stage 1 first.
    let stars: [Int]
    /// The stop the marker starts on before it walks to `stage`, or nil to stand still.
    var hopFrom: Int?
    /// The words on the button at the foot of the map.
    var playLabel = "Keep Playing"
    /// What the button does after the map closes, if anything.
    var onPlay: (() -> Void)?
    /// Called as the marker arrives, for a sound.
    var onArrive: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    /// How far the marker has walked from `hopFrom` to `stage`, 0 to 1.
    @State private var walked: CGFloat = 0
    @State private var isBobbing = false
    @State private var starsIn = false

    private static let rowHeight: CGFloat = 90
    private static let bannerHeight: CGFloat = 70
    /// Eight stages to a world: a world's painting then fits a phone with little cut off.
    private static let perWorld = 8

    /// The worlds in the order they are met; after the last they come round again.
    private static let worlds: [(id: String, name: String)] = [
        ("neon", "Neon City"), ("sunset", "Sunset Shores"), ("ocean", "Ocean Deep"),
        ("bubblegum", "Candy Hills"), ("rainforest", "Rainforest"), ("lava", "Lava Peaks"),
        ("jurassic", "Lost Valley"), ("frost", "Frost Lands"), ("gold", "Gold Canyon"),
        ("galaxy", "The Galaxy"),
    ]

    private static func world(ofStage number: Int) -> Int {
        (max(1, number) - 1) / perWorld
    }

    private static func name(ofWorld world: Int) -> String {
        worlds[world % worlds.count].name
    }

    private static func art(ofWorld world: Int) -> String {
        "map-" + worlds[world % worlds.count].id
    }

    /// The colours of a world's ground when its painting is not in the app.
    private static func ground(ofWorld world: Int) -> [Color] {
        let tones: [[Color]] = [
            [Color(hex: 0x2A1B6B), Color(hex: 0x120A3A)], [Color(hex: 0xF29A6B), Color(hex: 0x7A3F7F)],
            [Color(hex: 0x1F8FB5), Color(hex: 0x0B3B6B)], [Color(hex: 0xF7A8D0), Color(hex: 0x9C6ADE)],
            [Color(hex: 0x2E8B4E), Color(hex: 0x0F3D2A)], [Color(hex: 0x8A2B12), Color(hex: 0x2A0F0B)],
            [Color(hex: 0x8C9A3D), Color(hex: 0x3F4A1D)], [Color(hex: 0xBFE6F7), Color(hex: 0x5D8FC2)],
            [Color(hex: 0xD9973F), Color(hex: 0x7A3F1B)], [Color(hex: 0x3A1D7A), Color(hex: 0x0A0626)],
        ]
        return tones[world % tones.count]
    }

    /// How far a stop sits to one side of the middle, as a share of the width.
    private static func sway(_ number: Int) -> CGFloat {
        CGFloat(sin(Double(number) * 0.9)) * 0.24
    }

    private static func symbol(_ twist: GameStore.Twist) -> String {
        switch twist {
        case .plain: return "circle"
        case .breather: return "leaf.fill"
        case .rocky: return "mountain.2.fill"
        case .quickTurn: return "arrow.triangle.2.circlepath"
        case .sprint: return "hare.fill"
        }
    }

    /// The world the player is in, the highest one drawn (a look ahead at the next)
    /// and the lowest (two worlds back).
    private var nowWorld: Int { Self.world(ofStage: stage) }
    private var topWorld: Int { nowWorld + 1 }
    private var bottomWorld: Int { max(0, nowWorld - 2) }
    private var firstStage: Int { bottomWorld * Self.perWorld + 1 }
    private var lastStage: Int { (topWorld + 1) * Self.perWorld }
    private var sectionHeight: CGFloat { CGFloat(Self.perWorld) * Self.rowHeight + Self.bannerHeight }

    /// Where a stop is on the map, measured from the map's top-left corner.
    private func spot(_ number: Int, width: CGFloat) -> CGPoint {
        let world = Self.world(ofStage: number)
        let index = (number - 1) % Self.perWorld
        let section = CGFloat(topWorld - world)
        return CGPoint(
            x: width / 2 + Self.sway(number) * width,
            y: section * sectionHeight + CGFloat(Self.perWorld - 1 - index) * Self.rowHeight + Self.rowHeight * 0.5
        )
    }

    var body: some View {
        let from = hopFrom.map { min(max($0, firstStage), stage) } ?? stage
        let total = stars.reduce(0, +)

        GeometryReader { geo in
            let width = min(geo.size.width, 520)
            ZStack {
                Color(hex: 0x070A26)
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        map(width: width, from: from)
                            .frame(width: width)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 96)
                            .padding(.bottom, 150)
                    }
                    .onAppear {
                        proxy.scrollTo(from, anchor: .center)
                        isBobbing = true
                        guard from != stage else {
                            walked = 1
                            starsIn = true
                            return
                        }
                        // The stars of the stage just cleared land, then the marker walks on.
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.35)) {
                            starsIn = true
                        }
                        withAnimation(.easeInOut(duration: 1.1).delay(0.95)) {
                            walked = 1
                        }
                        withAnimation(.easeInOut(duration: 1.1).delay(0.95)) {
                            proxy.scrollTo(stage, anchor: .center)
                        }
                    }
                    .task {
                        guard from != stage else { return }
                        try? await Task.sleep(for: .milliseconds(2000))
                        onArrive?()
                    }
                }
            }
            .overlay(alignment: .top) {
                topBar(total: total)
            }
            .overlay(alignment: .bottom) {
                bottomBar
            }
        }
    }

    // MARK: The parts of the screen

    private func topBar(total: Int) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("WORLD \(nowWorld + 1)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.counter)
                Text(Self.name(ofWorld: nowWorld))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: 0xFFD54A))
                Text("\(total)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(total) stars"))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityLabel(Text("Close the map"))
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 26)
        .background(
            LinearGradient(colors: [Color(hex: 0x070A26, opacity: 0.95), Color(hex: 0x070A26, opacity: 0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("Stage \(stage): " + GameStore.goalWords(GameStore.goal(forStage: stage)))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                if let words = GameStore.twistWords(GameStore.twist(forStage: stage)) {
                    Text(words)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.counter)
                }
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)

            Button {
                dismiss()
                onPlay?()
            } label: {
                Text(playLabel)
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: 280)
                    .frame(height: 56)
                    .background(Capsule().fill(LinearGradient(colors: Theme.flip.reversed(), startPoint: .top, endPoint: .bottom)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 2))
                    .shadow(color: Theme.flip[1].opacity(0.8), radius: 12)
            }
            .buttonStyle(BounceButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0x070A26, opacity: 0), Color(hex: 0x070A26, opacity: 0.96)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.45))
                .ignoresSafeArea()
        )
    }

    /// The whole map: the painted worlds, the trail over them, the stops and the marker.
    private func map(width: CGFloat, from: Int) -> some View {
        let all = (firstStage...lastStage).map { spot($0, width: width) }
        let done = (firstStage...max(firstStage, stage)).map { spot($0, width: width) }
        // How much of the lit trail is there before the marker sets off.
        let lengthBefore = Self.length(Array(done.prefix(max(1, from - firstStage + 1))))
        let lengthAll = Self.length(done)
        let start = lengthAll > 0 ? lengthBefore / lengthAll : 1
        let lit = start + (1 - start) * walked
        let a = spot(from, width: width)
        let b = spot(stage, width: width)
        let marker = CGPoint(x: a.x + (b.x - a.x) * walked, y: a.y + (b.y - a.y) * walked)
        let worldsDown = Array((bottomWorld...topWorld).reversed())

        return ZStack(alignment: .topLeading) {
            // The painted ground of each world, the highest at the top.
            VStack(spacing: 0) {
                ForEach(worldsDown, id: \.self) { world in
                    ground(world, width: width)
                }
            }

            // The trail: a pale road with a dark edge, lit as far as the player has come.
            TrailShape(points: all)
                .stroke(Color.black.opacity(0.35), style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
                .offset(y: 4)
            TrailShape(points: all)
                .stroke(Color(hex: 0xFFF1D0, opacity: 0.92), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
            TrailShape(points: all)
                .stroke(Color(hex: 0x9C7B4A, opacity: 0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [2, 12]))
            TrailShape(points: done)
                .trim(from: 0, to: lit)
                .stroke(
                    LinearGradient(colors: [Color(hex: 0xFFD54A), Color(hex: 0xFF7AD9)], startPoint: .bottom, endPoint: .top),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color(hex: 0xFFB02E, opacity: 0.9), radius: 6)

            // The stops, one row each so the map can scroll to any of them.
            VStack(spacing: 0) {
                ForEach(worldsDown, id: \.self) { world in
                    ForEach(0..<Self.perWorld, id: \.self) { index in
                        let number = (world + 1) * Self.perWorld - index
                        stop(number, from: from)
                            .offset(x: Self.sway(number) * width)
                            .frame(width: width, height: Self.rowHeight)
                            .id(number)
                    }
                    banner(world)
                        .frame(width: width, height: Self.bannerHeight)
                }
            }

            // The marker: a pin that stands over the stop to play.
            pin
                .offset(y: isBobbing ? -6 : 0)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isBobbing)
                .position(x: marker.x, y: marker.y - 62)
        }
        .frame(width: width, height: CGFloat(worldsDown.count) * sectionHeight)
    }

    private static func length(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var sum: CGFloat = 0
        for index in 1..<points.count {
            sum += hypot(points[index].x - points[index - 1].x, points[index].y - points[index - 1].y)
        }
        return sum
    }

    private func ground(_ world: Int, width: CGFloat) -> some View {
        let isAhead = world > nowWorld
        return ZStack {
            if ObstacleArt.has(Self.art(ofWorld: world)) {
                Image(Self.art(ofWorld: world))
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: sectionHeight)
                    .clipped()
            } else {
                LinearGradient(colors: Self.ground(ofWorld: world), startPoint: .top, endPoint: .bottom)
            }
            // A soft shade down the middle keeps the trail and the stops easy to read.
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.28), Color.black.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            // The world ahead is in shadow until it is reached.
            if isAhead {
                Color(hex: 0x070A26, opacity: 0.62)
            }
        }
        .frame(width: width, height: sectionHeight)
        .clipped()
        .accessibilityHidden(true)
    }

    /// The ribbon at the foot of a world, where the trail enters it.
    private func banner(_ world: Int) -> some View {
        let isAhead = world > nowWorld
        let first = world * Self.perWorld + 1
        return HStack(spacing: 8) {
            Image(systemName: isAhead ? "lock.fill" : "flag.fill")
                .font(.system(size: 13, weight: .heavy))
            Text(isAhead ? "WORLD \(world + 1)  ·  REACH STAGE \(first)" : "WORLD \(world + 1)  ·  " + Self.name(ofWorld: world).uppercased())
                .font(.system(size: 14, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 18)
        .frame(height: 38)
        .background(
            Capsule().fill(LinearGradient(colors: isAhead ? [Color(hex: 0x39406B), Color(hex: 0x1B2046)] : [Color(hex: 0xFF8A3D), Color(hex: 0xD9345B)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(Capsule().strokeBorder(Color(hex: 0xFFE9A8, opacity: isAhead ? 0.4 : 0.95), lineWidth: 2))
        .shadow(color: Color.black.opacity(0.5), radius: 6, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("World \(world + 1), " + Self.name(ofWorld: world)))
    }

    private var pin: some View {
        ZStack {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color(hex: 0xFF4D8D))
                .offset(y: 19)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xFF8ACB), Color(hex: 0xFF3D7F)], startPoint: .top, endPoint: .bottom))
                .frame(width: 34, height: 34)
            Circle()
                .strokeBorder(Color.white, lineWidth: 3)
                .frame(width: 34, height: 34)
            Image(systemName: "play.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.white)
                .offset(x: 1)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 5, y: 4)
        .accessibilityHidden(true)
    }

    /// One stop on the trail.
    private func stop(_ number: Int, from: Int) -> some View {
        let isDone = number < stage
        let isNow = number == stage
        let won = isDone && number <= stars.count ? stars[number - 1] : 0
        let twist = GameStore.twist(forStage: number)
        let isChest = number % 5 == 0
        let opens = GameStore.opens(atStage: number + 1) != nil
        let side: CGFloat = isNow ? 66 : 54
        // Gold once cleared, bright for the one to play, slate for the ones ahead.
        let rim: [Color] = isDone ? [Color(hex: 0xFFE98A), Color(hex: 0xC98A12)] : (isNow ? [Color.white, Color(hex: 0xBFD4FF)] : [Color(hex: 0x9AA6C7), Color(hex: 0x4A5478)])
        let face: [Color] = isDone ? [Color(hex: 0xFFB93D), Color(hex: 0xF0721F)] : (isNow ? Theme.flip : [Color(hex: 0x56608C), Color(hex: 0x2A315A)])
        // The stars of the stage just cleared pop in; the rest are simply there.
        let showsStars = number == from && from != stage ? starsIn : true

        return ZStack {
            // A chest waits beside every fifth stop until it is won.
            if isChest, !isDone, ObstacleArt.has("prop-chest") {
                Image("prop-chest")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62, height: 62)
                    .shadow(color: Color(hex: 0xFFB02E, opacity: 0.8), radius: 8)
                    .offset(x: Self.sway(number) > 0 ? -66 : 66, y: -4)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 3) {
                ZStack {
                    // The button's foot, its rim, its face and a shine across the top.
                    Ellipse()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: side * 0.92, height: side * 0.3)
                        .offset(y: side * 0.5)
                        .blur(radius: 3)
                    Circle()
                        .fill(LinearGradient(colors: rim, startPoint: .top, endPoint: .bottom))
                    Circle()
                        .fill(LinearGradient(colors: face, startPoint: .top, endPoint: .bottom))
                        .padding(side * 0.09)
                    Ellipse()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .frame(width: side * 0.58, height: side * 0.3)
                        .offset(y: -side * 0.2)
                    Text("\(number)")
                        .font(.system(size: isNow ? 26 : 21, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white.opacity(isDone || isNow ? 1 : 0.7))
                        .shadow(color: Color.black.opacity(0.45), radius: 1, y: 2)
                }
                .frame(width: side, height: side)
                .shadow(color: isNow ? Theme.flip[1].opacity(0.95) : Color.clear, radius: 14)
                .overlay(alignment: .topTrailing) {
                    if opens || (twist != .plain && !isDone) {
                        Image(systemName: opens ? "lock.open.fill" : Self.symbol(twist))
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Color.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(opens ? Color(hex: 0x2FAE6B) : Color(hex: 0x5B4BD6)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5))
                            .offset(x: 7, y: -5)
                    }
                }
                .overlay(alignment: .top) {
                    if isDone {
                        HStack(spacing: 1) {
                            ForEach(0..<3, id: \.self) { index in
                                Image(systemName: "star.fill")
                                    .font(.system(size: index == 1 ? 17 : 14, weight: .black))
                                    .foregroundStyle(index < won ? Color(hex: 0xFFD54A) : Color(hex: 0x2A315A, opacity: 0.85))
                                    .shadow(color: Color.black.opacity(0.6), radius: 1, y: 1)
                                    .offset(y: index == 1 ? -4 : 0)
                            }
                        }
                        .scaleEffect(showsStars ? 1 : 0.1)
                        .opacity(showsStars ? 1 : 0)
                        .offset(y: -17)
                    }
                }

                if !isDone {
                    Text(GameStore.goalShort(GameStore.goal(forStage: number)))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(isNow ? Theme.counter : Color.white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .frame(height: 17)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isDone ? "Stage \(number), cleared with \(won) stars" : (isNow ? "Stage \(number), play next" : "Stage \(number), locked")))
    }
}
