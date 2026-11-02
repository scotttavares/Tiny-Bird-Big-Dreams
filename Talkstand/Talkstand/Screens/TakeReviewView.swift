import AVKit
import SwiftUI

/// Watch the take back, then send it or try again.
struct TakeReviewView: View {
    let take: Take
    let flubs: [ClosedRange<TimeInterval>]
    let onRetake: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VideoPlayer(player: player)
                    .clipShape(.rect(cornerRadius: 20))
                    .aspectRatio(9 / 16, contentMode: .fit)

                if !flubs.isEmpty {
                    Label(flubs.count == 1 ? "You went back once." : "You went back \(flubs.count) times.",
                          systemImage: "arrow.uturn.backward")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button {
                        onRetake()
                        dismiss()
                    } label: {
                        Label("Try again", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: take.url) {
                        Label("Send", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Your take")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            let player = AVPlayer(url: take.url)
            self.player = player
            player.play()
        }
        .onDisappear { player?.pause() }
    }
}
