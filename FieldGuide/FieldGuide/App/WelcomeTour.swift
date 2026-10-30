import SwiftUI

/// A short walk through the app, shown once, the first time a page is open.
struct WelcomeTour: View {
    private struct Stop: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { title }
    }

    private static let stops = [
        Stop(symbol: "pencil.tip", title: "Sketch on Paper",
             detail: "Pick a tool at the bottom and draw. Tap with two fingers to undo, or three to redo."),
        Stop(symbol: "face.smiling", title: "Stick Things Down",
             detail: "Tap the smiley to add stickers, photos and short videos. Touch and hold one to move it, or to change its frame and color."),
        Stop(symbol: "book", title: "Turn the Page",
             detail: "Drag the page edge to turn it, or swipe with three fingers from anywhere."),
        Stop(symbol: "book.pages", title: "Unfold for Two Pages",
             detail: "The left page holds your reference photo, a live camera, the last page and field notes. Drag things across the fold to copy them."),
        Stop(symbol: "triangle", title: "Fold It Like a Tent",
             detail: "Half-fold the phone to show your sketch to someone across the table, or play the drawing game together."),
    ]

    let onDone: () -> Void

    @State private var index = 0

    /// Whether the tour should open now.
    static func isDue(hasSeen: Bool, coverShowing: Bool, isDemo: Bool) -> Bool {
        !hasSeen && !coverShowing && !isDemo
    }

    var body: some View {
        VStack(spacing: 20) {
            TabView(selection: $index) {
                ForEach(Array(Self.stops.enumerated()), id: \.offset) { offset, stop in
                    VStack(spacing: 18) {
                        Image(systemName: stop.symbol)
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(stop.title)
                            .font(.title.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(stop.detail)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                    .accessibilityElement(children: .combine)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(index == Self.stops.count - 1 ? "Start Sketching" : "Next") {
                if index == Self.stops.count - 1 {
                    onDone()
                } else {
                    withAnimation { index += 1 }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Find every gesture under the info button in the top bar.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 24)
        .background(Theme.chrome.ignoresSafeArea())
    }
}
