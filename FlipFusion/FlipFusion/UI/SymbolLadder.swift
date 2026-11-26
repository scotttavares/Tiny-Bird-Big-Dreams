import SwiftUI

/// The legend for tiles that show pictures: the eleven pictures in the order they
/// merge, smallest first. The ones the board has reached are bright; the rest are
/// dim, so it also shows how far up the ladder the game has climbed.
struct SymbolLadder: View {
    /// The world whose pictures to show; nil shows the Fruit Salad game's fruit.
    let theme: String?
    /// The biggest tile on the board.
    let reached: Int
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 1 * scale) {
            ForEach(0..<11, id: \.self) { place in
                let value = 2 << place
                Text(Fruit.face(for: value, theme: theme))
                    .font(.system(size: 17 * scale))
                    .opacity(value <= reached ? 1 : 0.5)
                    .scaleEffect(value == reached ? 1.2 : 1)
                if place < 10 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 6 * scale, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 9 * scale)
        .frame(height: 30 * scale)
        .background(Capsule().fill(Color.black.opacity(0.5)))
        .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
        .animation(.easeOut(duration: 0.2), value: reached)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("The pictures in the order they merge. The biggest on the board is number \(max(1, reached.trailingZeroBitCount)) of 11."))
    }
}
