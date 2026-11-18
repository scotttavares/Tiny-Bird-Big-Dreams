import SwiftUI

/// The glowing "Flip Fusion" title with its two floating squares.
struct LogoView: View {
    let scale: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3 * scale) {
            Text("Flip")
                .foregroundStyle(
                    LinearGradient(colors: Theme.flip, startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Theme.flip[1].opacity(0.8), radius: 10 * scale, x: 0, y: 0)
            Text("Fusion")
                .foregroundStyle(
                    LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: Theme.fusion[0].opacity(0.7), radius: 10 * scale, x: 0, y: 0)
        }
        .font(.system(size: 54 * scale, weight: .black, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 22 * scale)
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2 * scale, style: .continuous)
                .fill(Theme.flip[1])
                .frame(width: 9 * scale, height: 9 * scale)
                .rotationEffect(.degrees(45))
                .shadow(color: Theme.flip[1], radius: 4 * scale)
                .offset(x: 2 * scale, y: 18 * scale)
        }
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 3 * scale, style: .continuous)
                .fill(Color(hex: 0x3F7BFF))
                .frame(width: 14 * scale, height: 14 * scale)
                .rotationEffect(.degrees(20))
                .shadow(color: Color(hex: 0x3F7BFF), radius: 4 * scale)
                .offset(x: -14 * scale, y: -4 * scale)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Flip Fusion"))
        .accessibilityAddTraits(.isHeader)
    }
}

/// The SCORE card (left) and the Best card with its crown (right).
struct ScoreCards: View {
    let score: Int
    let best: Int
    /// True while points count double.
    var isFever = false
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            card {
                VStack(spacing: 0) {
                    Text(isFever ? "SCORE x2" : "SCORE")
                        .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(isFever ? Theme.counter : Theme.label)
                    Text(String(score))
                        .font(.system(size: 27 * scale, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: score)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Score \(score)"))

            Spacer(minLength: 8 * scale)

            card {
                HStack(spacing: 8 * scale) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 21 * scale, weight: .bold))
                        .foregroundStyle(Theme.crown)
                        .shadow(color: Theme.crown.opacity(0.6), radius: 4 * scale)
                    VStack(spacing: 0) {
                        Text("Best")
                            .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.label)
                        Text(best.formatted(.number.grouping(.automatic)))
                            .font(.system(size: 20 * scale, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.2), value: best)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Best \(best)"))
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
        return content()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 10 * scale)
            .frame(width: 122 * scale, height: 60 * scale)
            .background(shape.fill(Theme.glassFill))
            .overlay(shape.strokeBorder(Theme.glassStroke, lineWidth: 1))
    }
}

/// The "ROTATES IN 1 MOVE" pill.
struct RotatePill: View {
    let moves: Int
    let scale: CGFloat

    private var spokenLabel: String {
        if moves <= 0 { return "Rotating" }
        return moves == 1 ? "Rotates in 1 move" : "Rotates in \(moves) moves"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6 * scale) {
            if moves > 0 {
                Text("ROTATES IN")
                Text(String(moves))
                    .font(.system(size: 22 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.counter)
                    .contentTransition(.numericText())
                Text(moves == 1 ? "MOVE" : "MOVES")
            } else {
                Text("ROTATING")
                    .foregroundStyle(Theme.counter)
            }
        }
        .font(.system(size: 15 * scale, weight: .heavy, design: .rounded))
        .foregroundStyle(Color.white)
        .lineLimit(1)
        .padding(.horizontal, 20 * scale)
        .frame(height: 38 * scale)
        .frame(minWidth: 216 * scale)
        .background(
            Capsule().fill(
                LinearGradient(colors: [Theme.pillTop, Theme.pillBottom], startPoint: .top, endPoint: .bottom)
            )
        )
        .overlay(Capsule().strokeBorder(Theme.pillStroke, lineWidth: 1.5))
        .shadow(color: Theme.pillStroke.opacity(0.5), radius: 8 * scale, x: 0, y: 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenLabel))
    }
}
