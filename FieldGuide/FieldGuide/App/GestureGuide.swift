import SwiftUI

/// Every gesture in the app, opened from the info button in the top bar.
struct GestureGuide: View {
    private struct Gesture: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { title }
    }

    private struct Group: Identifiable {
        let title: String
        let gestures: [Gesture]
        var id: String { title }
    }

    private static let groups = [
        Group(title: "Drawing", gestures: [
            Gesture(symbol: "arrow.uturn.backward", title: "Two-finger tap", detail: "Undo."),
            Gesture(symbol: "arrow.uturn.forward", title: "Three-finger tap", detail: "Redo."),
            Gesture(symbol: "hand.pinch", title: "Pinch", detail: "Zoom in and out of the page."),
            Gesture(symbol: "arrow.up.left.and.down.right.magnifyingglass", title: "Two-finger double-tap", detail: "Show the whole page again."),
            Gesture(symbol: "slider.horizontal.3", title: "Hold a tool", detail: "Change its color and size."),
        ]),
        Group(title: "Stickers and Photos", gestures: [
            Gesture(symbol: "hand.tap", title: "Touch and hold an item", detail: "Select it, and keep dragging to move it."),
            Gesture(symbol: "hand.draw", title: "Drag", detail: "Move the selected item."),
            Gesture(symbol: "hand.pinch", title: "Pinch", detail: "Resize the selected item."),
            Gesture(symbol: "rotate.right", title: "Twist with two fingers", detail: "Turn the selected item."),
        ]),
        Group(title: "Pages", gestures: [
            Gesture(symbol: "book", title: "Drag the page edge", detail: "Turn the page. Where you hold it changes how it curls."),
            Gesture(symbol: "hand.tap", title: "Tap the page edge", detail: "Turn the page."),
            Gesture(symbol: "arrow.left.arrow.right", title: "Three-finger swipe", detail: "Turn the page from anywhere, even zoomed in."),
            Gesture(symbol: "chevron.down", title: "Swipe down on the top bar", detail: "Close the notebook and go back to its cover."),
        ]),
        Group(title: "Unfolded", gestures: [
            Gesture(symbol: "photo", title: "Hold and drag the left-page photo", detail: "Drop it on the right page to stick down a copy."),
            Gesture(symbol: "arrow.up.left.and.arrow.down.right", title: "Tap or double-tap the left-page photo", detail: "Open it full screen. Double-tap resets it when it's zoomed in."),
            Gesture(symbol: "triangle", title: "Swipe while presenting", detail: "Half-fold the phone or choose Present, then swipe through your pages."),
        ]),
    ]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Self.groups) { group in
                    Section(group.title) {
                        ForEach(group.gestures) { gesture in
                            HStack(spacing: 14) {
                                Image(systemName: gesture.symbol)
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 32)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(gesture.title)
                                        .font(.body.weight(.semibold))
                                    Text(gesture.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .navigationTitle("Gestures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
