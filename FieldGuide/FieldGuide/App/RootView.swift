import SwiftData
import SwiftUI

struct RootView: View {
    let postureProvider: any PostureProvider

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 12) {
                Image(systemName: postureProvider.posture.symbol)
                    .font(.largeTitle)
                Text(postureProvider.posture.title)
                    .font(.title2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .readsPosture(into: postureProvider)
    }
}
