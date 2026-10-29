import SwiftUI

/// The notebook's cover, shown on the outer screen while the phone is folded shut. Tap it or swipe
/// it to the left and it swings open on its spine to the page underneath.
struct CoverScreen: View {
    let model: AppModel
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swing: Double = 0
    @State private var isShowingLibrary = false

    var body: some View {
        let notebook = model.currentNotebook
        ZStack(alignment: .bottom) {
            NotebookCoverArt(
                title: notebook?.title ?? "Field Notes",
                theme: notebook?.theme ?? .pines,
                seed: notebook?.id.uuidString ?? "cover",
                number: model.notebookNumber
            )
            .clipShape(.rect(cornerRadius: 18))
            .overlay(alignment: .topTrailing) {
                Text("Tap to open")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.3), in: .capsule)
                    .padding(.top, notebook?.theme.isSpiralBound == true ? 56 : 14)
                    .padding(.trailing, 14)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 10) {
                Button {
                    model.newPage()
                    open()
                } label: {
                    Label("New page", systemImage: "plus")
                }
                Button {
                    isShowingLibrary = true
                } label: {
                    Label("Notebooks", systemImage: "books.vertical")
                }
            }
            .buttonStyle(CoverButtonStyle())
            .padding(.bottom, 22)
        }
        .rotation3DEffect(.degrees(swing), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.6)
        .opacity(1 - abs(swing) / 140)
        .contentShape(.rect)
        .onTapGesture { open() }
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    guard !reduceMotion else { return }
                    swing = max(-100, min(0, value.translation.width / 3))
                }
                .onEnded { value in
                    if value.translation.width < -60 || value.predictedEndTranslation.width < -160 {
                        open()
                    } else {
                        withAnimation(.smooth(duration: 0.25)) { swing = 0 }
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open notebook") { open() }
        .sheet(isPresented: $isShowingLibrary) {
            LibraryView(model: model)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: swing == -100)
    }

    private func open() {
        if reduceMotion {
            onOpen()
            return
        }
        withAnimation(.easeIn(duration: 0.45)) {
            swing = -100
        } completion: {
            onOpen()
            swing = 0
        }
    }
}

private struct CoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(configuration.isPressed ? 0.6 : 0.42), in: .capsule)
            .background(.ultraThinMaterial, in: .capsule)
    }
}
