import SwiftUI

/// One glossy neon tile.
struct TileView: View {
    let value: Int
    var kind: TileKind = .normal
    let size: CGFloat

    @State private var appeared = false

    /// The corner badge and rim colour of a special tile.
    private var badge: (symbol: String, tint: Color, name: String)? {
        switch kind {
        case .normal: return nil
        case .time: return ("clock.fill", Color(hex: 0x8FF0FF), "clock tile")
        case .bomb: return ("flame.fill", Color(hex: 0xFFD23F), "bomb tile")
        }
    }

    private var fontSize: CGFloat {
        switch String(value).count {
        case 1, 2: return size * 0.52
        case 3: return size * 0.40
        case 4: return size * 0.31
        default: return size * 0.25
        }
    }

    var body: some View {
        let style = Theme.tile(value)
        let radius = size * 0.2
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        ZStack {
            shape.fill(
                LinearGradient(colors: [style.top, style.bottom], startPoint: .top, endPoint: .bottom)
            )

            // Soft shine across the top half.
            RoundedRectangle(cornerRadius: radius * 0.75, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.42), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: size * 0.46)
                .padding(.horizontal, size * 0.07)
                .padding(.top, size * 0.06)
                .frame(maxHeight: .infinity, alignment: .top)

            // Bright rim on top, fading down the sides.
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.75), Color.white.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: max(1, size * 0.03)
            )

            Text(String(value))
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.28), radius: 1, x: 0, y: 1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, size * 0.06)

            if let badge {
                shape.strokeBorder(badge.tint, lineWidth: max(2, size * 0.055))
                Image(systemName: badge.symbol)
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(badge.tint)
                    .frame(width: size * 0.36, height: size * 0.36)
                    .background(Circle().fill(Color(hex: 0x0B1342)))
                    .overlay(Circle().strokeBorder(badge.tint, lineWidth: 1.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: size * 0.08, y: -size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: style.bottom.opacity(0.75), radius: size * 0.16, x: 0, y: 0)
        .scaleEffect(appeared ? 1 : 0.2)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                appeared = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(badge.map { "\(value), \($0.name)" } ?? String(value)))
    }
}
