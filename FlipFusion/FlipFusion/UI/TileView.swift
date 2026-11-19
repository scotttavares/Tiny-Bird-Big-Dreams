import SwiftUI

/// One glossy tile, in the shape and colours of a theme.
struct TileView: View {
    let value: Int
    var kind: TileKind = .normal
    let size: CGFloat
    /// The theme to draw the tile in. The menu draws tiles of themes not in use.
    var skin: Skin = Skin.current

    @State private var appeared = false
    /// Special tiles throb so they catch the eye.
    @State private var throb = false

    /// The corner badge and rim colour of a special tile.
    private var badge: (symbol: String, tint: Color, name: String)? {
        switch kind {
        case .normal, .stone: return nil
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

    private var spokenLabel: String {
        if kind == .stone {
            return "stone block"
        }
        if let badge {
            return "\(value), \(badge.name)"
        }
        return String(value)
    }

    var body: some View {
        let style = Theme.tile(value, skin: skin)
        let outline = TileOutline(shape: skin.shape)
        let isStone = kind == .stone
        let isNeon = skin.shape == .neon
        let top = style.top
        let bottom = style.bottom

        ZStack {
            if isStone {
                // A stone block is a boulder, not a tile, in every theme.
                StoneView(size: size, look: skin.stone)
            } else {
                if isNeon {
                    // Dark glass; the colour is all in the glowing edge.
                    outline.fill(Color(hex: 0x0B0624, opacity: 0.92))
                } else {
                    outline.fill(
                        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
                    )
                }

                gloss(outline)

                if isNeon {
                    // The neon tube, with a thin white core inside it.
                    outline.strokeBorder(
                        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom),
                        lineWidth: size * 0.075
                    )
                    outline.inset(by: size * 0.03)
                        .stroke(Color.white.opacity(0.75), lineWidth: max(1, size * 0.015))
                } else {
                    // Bright rim on top, fading down the sides.
                    outline.strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.75), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1, size * 0.03)
                    )
                }

                Text(String(value))
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .shadow(color: isNeon ? top : Color.black.opacity(0.28), radius: isNeon ? size * 0.09 : 1, x: 0, y: isNeon ? 0 : 1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, size * 0.06)
            }

            if let badge {
                outline.strokeBorder(badge.tint, lineWidth: max(2, size * 0.055))
                Image(systemName: badge.symbol)
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(badge.tint)
                    .frame(width: size * 0.36, height: size * 0.36)
                    .background(Circle().fill(Color(hex: 0x0B1342)))
                    .overlay(Circle().strokeBorder(badge.tint, lineWidth: 1.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: size * 0.08, y: -size * 0.08)
                    .scaleEffect(throb ? 1.22 : 1)
            }
        }
        .frame(width: size, height: size)
        // A tile glows in its own colour; a rock just casts a shadow.
        .shadow(
            color: isStone ? Color.black.opacity(0.55) : bottom.opacity(0.75),
            radius: size * (isStone ? 0.07 : 0.16),
            x: 0,
            y: isStone ? size * 0.05 : 0
        )
        .scaleEffect(appeared ? 1 : 0.2)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                appeared = true
            }
        }
        .onChange(of: kind, initial: true) { _, newKind in
            if newKind == .time || newKind == .bomb {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    throb = true
                }
            } else {
                throb = false
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(spokenLabel))
    }

    /// The shine on the tile, which is different for each tile shape.
    @ViewBuilder
    private func gloss(_ outline: TileOutline) -> some View {
        switch skin.shape {
        case .rounded, .hex, .jelly:
            ZStack {
                // Soft shine across the top half.
                RoundedRectangle(cornerRadius: size * 0.15, style: .continuous)
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
                if skin.shape == .jelly {
                    // A stripe of gloss from corner to corner.
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: size * 0.15, height: size * 1.5)
                        .rotationEffect(.degrees(35))
                        .offset(x: -size * 0.2)
                }
            }
            .frame(width: size, height: size)
            .clipShape(outline)
        case .neon:
            // A faint wash of the tile's colour over the dark glass.
            outline
                .fill(Theme.tile(value, skin: skin).top.opacity(0.2))
                .frame(width: size, height: size)
        case .bubble, .orb:
            ZStack {
                if skin.shape == .orb {
                    // The dark side of the planet.
                    Circle()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: size, height: size)
                        .offset(x: size * 0.2, y: size * 0.16)
                }
                Ellipse()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: size * 0.3, height: size * 0.17)
                    .rotationEffect(.degrees(-35))
                    .offset(x: -size * 0.2, y: -size * 0.25)
                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: size * 0.07, height: size * 0.07)
                    .offset(x: -size * 0.32, y: -size * 0.08)
            }
            .frame(width: size, height: size)
            .clipShape(outline)
        case .gem, .crystal:
            ZStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.42), Color.white.opacity(0.0)],
                    startPoint: .topLeading,
                    endPoint: .center
                )
                // The flat top face of a cut stone.
                outline.inset(by: size * 0.12)
                    .stroke(Color.white.opacity(0.42), lineWidth: max(1, size * 0.02))
            }
            .frame(width: size, height: size)
            .clipShape(outline)
        }
    }
}
