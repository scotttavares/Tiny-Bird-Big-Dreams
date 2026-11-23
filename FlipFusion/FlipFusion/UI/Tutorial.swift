import SwiftUI

/// The first game's lessons, in order. Each one waits for the player to do the
/// thing it teaches; the last waits for a tap.
enum Tutorial {
    static let key = "ff.tutorialDone"
    static let steps = 4

    static func title(_ step: Int) -> String {
        switch step {
        case 0: return "Swipe to slide"
        case 1: return "Match to merge"
        case 2: return "The board turns"
        default: return "Beat the stage"
        }
    }

    static func words(_ step: Int) -> String {
        switch step {
        case 0: return "Swipe anywhere, in any direction. Every tile slides that way."
        case 1: return "Swipe so two tiles with the same number meet. They merge into one bigger tile."
        case 2: return "Every 2 moves the board turns and the tiles fall. Keep swiping and watch."
        default: return "Fill the stage bar before the clock runs out. Stuck? The boosters under the board help."
        }
    }
}

/// The card that explains the lesson, with a way out of the tutorial.
struct TutorialCard: View {
    let step: Int
    let onSkip: () -> Void
    let onDone: () -> Void

    var body: some View {
        let isLast = step >= Tutorial.steps - 1
        let card = RoundedRectangle(cornerRadius: 22, style: .continuous)

        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<Tutorial.steps, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Theme.counter : Color.white.opacity(0.22))
                        .frame(width: index == step ? 22 : 10, height: 6)
                }
                Spacer(minLength: 8)
                if !isLast {
                    Button("Dismiss", action: onSkip)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .accessibilityLabel(Text("Dismiss the tutorial"))
                }
            }

            Text(Tutorial.title(step))
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: Theme.fusion, startPoint: .leading, endPoint: .trailing))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Tutorial.words(step))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if isLast {
                Button(action: onDone) {
                    Text("Got it")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 40)
                        .frame(height: 44)
                        .background(Capsule().fill(LinearGradient(colors: Theme.flip.reversed(), startPoint: .top, endPoint: .bottom)))
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: 340)
        .background(card.fill(Color(hex: 0x070A26, opacity: 0.96)))
        .overlay(card.strokeBorder(Theme.counter.opacity(0.9), lineWidth: 2))
        .shadow(color: Color.black.opacity(0.5), radius: 12, y: 4)
        .id(step)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}

/// The moving arrow over the board: a hand that swipes for the first two lessons,
/// an arrow up at the "rotates in" pill for the third, and one down at the
/// boosters for the last.
struct TutorialPointer: View {
    let step: Int
    let side: CGFloat

    @State private var isMoving = false

    var body: some View {
        Group {
            if step <= 1 {
                // A swipe, drawn: a trail with an arrowhead and a hand riding along it.
                ZStack {
                    Capsule()
                        .fill(LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: side * 0.5, height: 8)
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(Color.white)
                        .offset(x: side * 0.27)
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Color.white)
                        .shadow(color: Color.black.opacity(0.6), radius: 4, y: 3)
                        .offset(x: isMoving ? side * 0.24 : -side * 0.24, y: 30)
                        .opacity(isMoving ? 0.25 : 1)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: isMoving)
                }
                .shadow(color: Theme.flip[1].opacity(0.9), radius: 10)
            } else {
                Image(systemName: step == 2 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 46, weight: .black))
                    .foregroundStyle(Theme.counter)
                    .shadow(color: Color.black.opacity(0.7), radius: 4, y: 2)
                    .offset(y: (step == 2 ? -side * 0.4 : side * 0.4) + (isMoving ? (step == 2 ? -12 : 12) : 0))
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isMoving)
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            isMoving = true
        }
    }
}
