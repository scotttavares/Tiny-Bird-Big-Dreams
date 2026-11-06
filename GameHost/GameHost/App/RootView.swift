import SwiftUI

/// Lays out the two sides for the way the device is held, with the ad banner along the bottom.
///
/// - closed (one screen): the sides are pages you swipe between
/// - book: table side left of the hinge, rules right
/// - laptop: table side above the hinge, rules below
/// - tent: the far half shows the table side upside down from here, which is upright for the
///   players across the table; the near half keeps the rules for the host
struct RootView: View {
    let store: GameStore
    let postureProvider: any PostureProvider

    private enum Page: Hashable { case table, rules }

    @State private var page: Page = ProcessInfo.processInfo.arguments.contains("-GHShowRules") ? .rules : .table
    @State private var tentSwapped = false

    var body: some View {
        VStack(spacing: 0) {
            sides
                .readsPosture(into: postureProvider)
            AdBannerSlot()
        }
        .background(Theme.paper.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .overlay(alignment: .top) { toast }
        .animation(.snappy, value: store.toast)
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            store.shake()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: store.toast) { _, new in new != nil }
    }

    @ViewBuilder
    private var sides: some View {
        let hinge = postureProvider.hingeRect
        GeometryReader { proxy in
            switch postureProvider.posture {
            case .closed:
                TabView(selection: $page) {
                    // Room at the bottom so the page dots don't sit on Pass Turn or the rules.
                    TableSideView(store: store).padding(.bottom, 24).tag(Page.table)
                    RulesSideView(store: store).padding(.bottom, 24).tag(Page.rules)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            case .book:
                HStack(spacing: 0) {
                    TableSideView(store: store)
                        .frame(width: max(0, hinge.isNull ? proxy.size.width / 2 : hinge.minX))
                    Color.clear.frame(width: hinge.isNull ? 0 : hinge.width)
                    RulesSideView(store: store)
                }
            case .laptop:
                VStack(spacing: 0) {
                    TableSideView(store: store)
                        .frame(height: max(0, hinge.isNull ? proxy.size.height / 2 : hinge.minY))
                    Color.clear.frame(height: hinge.isNull ? 0 : hinge.height)
                    RulesSideView(store: store)
                }
            case .tent:
                VStack(spacing: 0) {
                    Group {
                        if tentSwapped { RulesSideView(store: store) } else { TableSideView(store: store) }
                    }
                    .frame(height: proxy.size.height / 2)
                    .rotationEffect(.degrees(180))
                    Divider().overlay(Theme.hairline)
                    Group {
                        if tentSwapped { TableSideView(store: store) } else { RulesSideView(store: store) }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Button("Swap Sides", systemImage: "arrow.up.arrow.down") { tentSwapped.toggle() }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                            .padding(12)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let message = store.toast {
            Label(message, systemImage: "arrow.uturn.backward")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.card, in: .capsule)
                .overlay(Capsule().stroke(Theme.hairline))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

/// Space for the small ad banner along the bottom of every screen. The ad SDK isn't wired
/// in yet, so this keeps the room the banner will use and shows a quiet placeholder.
struct AdBannerSlot: View {
    static let height: CGFloat = 50

    var body: some View {
        Text("Ad")
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.inkSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .background(Theme.card)
            .overlay(alignment: .top) { Theme.hairline.frame(height: 0.5) }
            .accessibilityHidden(true)
    }
}
