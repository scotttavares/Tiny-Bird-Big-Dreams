import SwiftUI

/// One glossy tile, in the shape and colours of a theme.
struct TileView: View {
    let value: Int
    var kind: TileKind = .normal
    let size: CGFloat
    /// The theme to draw the tile in. The menu draws tiles of themes not in use.
    var skin: Skin = Skin.current
    /// The Fruit Salad game: show a fruit in place of the number.
    var isFruit = false

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
            if isStone, isFruit {
                // In the Fruit Salad game the block that will not merge is a coconut.
                Text("\u{1F965}")
                    .font(.system(size: size * 0.74))
                    .shadow(color: Color.black.opacity(0.45), radius: size * 0.05, x: 0, y: size * 0.05)
            } else if isStone {
                // A stone block is a boulder, not a tile, in every theme.
                StoneView(size: size, look: skin.stone)
            } else if kind == .bomb {
                // A bomb tile is a bomb, whatever the theme.
                BombTile(value: value, size: size, fontSize: fontSize, label: isFruit ? Fruit.face(for: value) : nil)
                    .scaleEffect(throb ? 1.07 : 1)
            } else if kind == .time {
                ClockTile(value: value, size: size, fontSize: fontSize, label: isFruit ? Fruit.face(for: value) : nil)
                    .scaleEffect(throb ? 1.05 : 1)
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

                Text(isFruit ? Fruit.face(for: value) : String(value))
                    .font(.system(size: isFruit ? size * 0.56 : fontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .shadow(color: isNeon ? top : Color.black.opacity(0.28), radius: isNeon ? size * 0.09 : 1, x: 0, y: isNeon ? 0 : 1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, size * 0.06)
            }

        }
        .frame(width: size, height: size)
        // A tile glows in its own colour; a rock just casts a shadow.
        .shadow(
            color: isStone ? Color.black.opacity(0.55) : (kind == .bomb ? Color(hex: 0xFF7A2E, opacity: 0.8) : (kind == .time ? Color(hex: 0x3FC8FF, opacity: 0.8) : bottom.opacity(0.75))),
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

/// A bomb tile: a round black bomb with its number on it and a fuse whose tip sparks.
struct BombTile: View {
    let value: Int
    let size: CGFloat
    let fontSize: CGFloat
    /// What to show in place of the number (a fruit), if anything.
    var label: String?

    @State private var isLit = false

    var body: some View {
        ZStack {
            // The fuse, curling up out of the cap.
            Outline(
                points: [CGPoint(x: 0.62, y: 0.2), CGPoint(x: 0.7, y: 0.08), CGPoint(x: 0.82, y: 0.06), CGPoint(x: 0.9, y: 0.14)],
                isClosed: false
            )
            .stroke(Color(hex: 0xD4AE74), style: StrokeStyle(lineWidth: max(2, size * 0.05), lineCap: .round, lineJoin: .round))

            RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                .fill(Color(hex: 0x4A505E))
                .frame(width: size * 0.24, height: size * 0.15)
                .rotationEffect(.degrees(28))
                .position(x: size * 0.6, y: size * 0.22)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x6A7184), Color(hex: 0x181A21), Color.black],
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: max(1, size * 0.02)))
                .frame(width: size * 0.8, height: size * 0.8)
                .position(x: size * 0.46, y: size * 0.57)

            Ellipse()
                .fill(Color.white.opacity(0.4))
                .frame(width: size * 0.2, height: size * 0.1)
                .rotationEffect(.degrees(-38))
                .position(x: size * 0.27, y: size * 0.38)

            Text(label ?? String(value))
                .font(.system(size: label == nil ? fontSize * 0.86 : size * 0.4, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: size * 0.66)
                .position(x: size * 0.46, y: size * 0.58)

            // The spark at the tip of the fuse.
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.3, weight: .black))
                .foregroundStyle(Color(hex: 0xFFE26A))
                .shadow(color: Color(hex: 0xFF7A2E), radius: size * 0.06)
                .scaleEffect(isLit ? 1.25 : 0.55)
                .rotationEffect(.degrees(isLit ? 45 : 0))
                .position(x: size * 0.9, y: size * 0.13)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true)) {
                isLit = true
            }
        }
    }
}

/// A clock tile: an alarm clock with its number on the face and a hand that goes
/// round and round.
struct ClockTile: View {
    let value: Int
    let size: CGFloat
    let fontSize: CGFloat
    /// What to show in place of the number (a fruit), if anything.
    var label: String?

    @State private var turn = 0.0

    var body: some View {
        let middle = CGPoint(x: size * 0.5, y: size * 0.55)
        let metal = LinearGradient(colors: [Color(hex: 0xBFF6FF), Color(hex: 0x2B8FD0)], startPoint: .top, endPoint: .bottom)

        ZStack {
            // Two bells and the button between them.
            Circle().fill(metal).frame(width: size * 0.24, height: size * 0.24).position(x: size * 0.24, y: size * 0.17)
            Circle().fill(metal).frame(width: size * 0.24, height: size * 0.24).position(x: size * 0.76, y: size * 0.17)
            Capsule().fill(metal).frame(width: size * 0.1, height: size * 0.14).position(x: size * 0.5, y: size * 0.1)

            Circle().fill(metal).frame(width: size * 0.86, height: size * 0.86).position(middle)
            Circle().fill(Color(hex: 0xF7FBFF)).frame(width: size * 0.7, height: size * 0.7).position(middle)

            // The marks round the face, longer at twelve, three, six and nine.
            ForEach(0..<12, id: \.self) { mark in
                Rectangle()
                    .fill(Color(hex: 0x1D2F8F, opacity: 0.55))
                    .frame(width: max(1, size * 0.022), height: size * (mark % 3 == 0 ? 0.085 : 0.05))
                    .offset(y: -size * 0.295)
                    .rotationEffect(.degrees(Double(mark) * 30))
                    .position(middle)
            }

            // The hand.
            Capsule()
                .fill(Color(hex: 0xE0321E))
                .frame(width: max(1.5, size * 0.035), height: size * 0.3)
                .offset(y: -size * 0.14)
                .rotationEffect(.degrees(turn))
                .position(middle)
            Circle().fill(Color(hex: 0xE0321E)).frame(width: size * 0.08, height: size * 0.08).position(middle)

            Text(label ?? String(value))
                .font(.system(size: label == nil ? fontSize * 0.8 : size * 0.36, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: 0x12206A))
                .shadow(color: Color.white, radius: size * 0.03)
                .shadow(color: Color.white, radius: size * 0.03)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: size * 0.6)
                .position(middle)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                turn = 360
            }
        }
    }
}
