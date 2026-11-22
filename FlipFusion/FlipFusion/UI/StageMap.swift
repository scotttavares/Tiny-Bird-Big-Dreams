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

/// The path of stages: the ones cleared with their stars, the one to play, and what
/// is coming, with the chests and twists marked.
struct StageMapView: View {
    /// The stage to play next.
    let stage: Int
    /// Stars won on each cleared stage, stage 1 first.
    let stars: [Int]

    @Environment(\.dismiss) private var dismiss

    private static let rowHeight: CGFloat = 96

    /// How far a stage's spot sits to one side of the middle, as a share of the width.
    nonisolated private static func sway(_ number: Int) -> CGFloat {
        CGFloat(sin(Double(number) * 0.9)) * 0.27
    }

    nonisolated private static func symbol(_ twist: GameStore.Twist) -> String {
        switch twist {
        case .plain: return "circle"
        case .breather: return "leaf.fill"
        case .rocky: return "mountain.2.fill"
        case .quickTurn: return "arrow.triangle.2.circlepath"
        case .sprint: return "hare.fill"
        }
    }

    var body: some View {
        let last = max(12, stage + 7)
        let goal = GameStore.goalWords(GameStore.goal(forStage: stage))
        let reached = stage
        let rowHeight = Self.rowHeight

        VStack(spacing: 0) {
            HStack {
                Text("Stage Map")
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

            VStack(spacing: 3) {
                Text("Stage \(stage): " + goal)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.counter)
                if let words = GameStore.twistWords(GameStore.twist(forStage: stage)) {
                    Text(words)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.label)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            GeometryReader { geo in
                let width = geo.size.width
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // The highest stage is at the top: you climb the map.
                            ForEach(0..<last, id: \.self) { index in
                                let number = last - index
                                node(number)
                                    .offset(x: Self.sway(number) * width)
                                    .frame(width: width, height: Self.rowHeight)
                                    .id(number)
                            }
                        }
                        .background {
                            Canvas { context, size in
                                StageMapView.drawPath(in: &context, size: size, last: last, reached: reached, rowHeight: rowHeight)
                            }
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(stage, anchor: .center)
                    }
                }
            }
        }
        .background(Color(hex: 0x070A26).ignoresSafeArea())
    }

    private func node(_ number: Int) -> some View {
        let isDone = number < stage
        let isNow = number == stage
        let won = isDone && number <= stars.count ? stars[number - 1] : 0
        let twist = GameStore.twist(forStage: number)
        let isChest = number % 5 == 0
        let face: [Color] = isNow ? Theme.flip : (isDone ? Theme.fusion : [Color(hex: 0x1F2A6E), Color(hex: 0x10163F)])
        let side: CGFloat = isNow ? 66 : 54

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: face, startPoint: .top, endPoint: .bottom))
                Circle()
                    .strokeBorder(Color.white.opacity(isNow ? 0.95 : 0.35), lineWidth: isNow ? 3 : 1.5)
                Text("\(number)")
                    .font(.system(size: isNow ? 24 : 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(isDone || isNow ? 1 : 0.55))
            }
            .frame(width: side, height: side)
            .shadow(color: isNow ? Theme.flip[1].opacity(0.9) : Color.clear, radius: 12)
            .overlay(alignment: .topTrailing) {
                // Clearing this stage opens something new.
                let opens = GameStore.opens(atStage: number + 1) != nil
                if isChest || opens || twist != .plain {
                    Image(systemName: opens ? "lock.open.fill" : (isChest ? "gift.fill" : Self.symbol(twist)))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(opens ? Color(hex: 0x2FAE6B) : (isChest ? Color(hex: 0xE8961F) : Color(hex: 0x5B4BD6))))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                        .offset(x: 8, y: -6)
                }
            }

            if isDone {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(index < won ? Theme.counter : Color.white.opacity(0.22))
                    }
                }
            } else {
                Text(GameStore.goalShort(GameStore.goal(forStage: number)))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(isNow ? Theme.counter : Theme.label.opacity(0.7))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isDone ? "Stage \(number), cleared with \(won) stars" : (isNow ? "Stage \(number), play next" : "Stage \(number), locked")))
    }

    /// The trail joining the stages: bright as far as the player has come, faint beyond.
    nonisolated private static func drawPath(in context: inout GraphicsContext, size: CGSize, last: Int, reached: Int, rowHeight: CGFloat) {
        guard last > 1 else { return }
        func spot(_ number: Int) -> CGPoint {
            CGPoint(
                x: size.width / 2 + sway(number) * size.width,
                y: CGFloat(last - number) * rowHeight + rowHeight * 0.42
            )
        }
        var whole = Path()
        var walked = Path()
        whole.move(to: spot(1))
        walked.move(to: spot(1))
        for number in 2...last {
            whole.addLine(to: spot(number))
            if number <= reached {
                walked.addLine(to: spot(number))
            }
        }
        context.stroke(whole, with: .color(Color.white.opacity(0.16)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round, dash: [2, 12]))
        context.stroke(walked, with: .color(Color(hex: 0xFF7AD9, opacity: 0.85)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
    }
}
