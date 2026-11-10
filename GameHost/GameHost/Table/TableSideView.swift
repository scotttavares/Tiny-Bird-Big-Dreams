import SwiftUI

/// The side the players see: round, turn timer, player tiles, dice and the Pass Turn button.
struct TableSideView: View {
    let store: GameStore

    @State private var isEditingPlayers = false

    var body: some View {
        VStack(spacing: 12) {
            header
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(store.state.players) { player in
                        PlayerTile(
                            player: player,
                            isActive: player.id == store.state.activePlayer?.id,
                            onAdd: { store.state.addScore($0, to: player.id) }
                        )
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            DiceTray(store: store)
            Button {
                store.state.passTurn(now: .now)
            } label: {
                Text("Pass Turn")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .foregroundStyle(Theme.onAccent)
            .disabled(store.state.players.isEmpty)
            .sensoryFeedback(.selection, trigger: store.state.activeIndex)
        }
        .padding(16)
        .sheet(isPresented: $isEditingPlayers) {
            PlayersSheet(store: store)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Round \(store.state.round)")
                .font(.headline)
            Spacer()
            TurnTimer(store: store)
            Button("Players", systemImage: "person.2") { isEditingPlayers = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .tint(Theme.inkSecondary)
        }
    }
}

/// Counts up through the current turn. Tap to pause or carry on.
struct TurnTimer: View {
    let store: GameStore

    var body: some View {
        Button {
            store.state.toggleTimer(now: .now)
        } label: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Label(
                    Self.format(store.state.turnElapsed(at: context.date)),
                    systemImage: store.state.isTimerRunning ? "hourglass" : "pause.fill"
                )
                .font(.headline.monospacedDigit())
            }
        }
        .buttonStyle(.bordered)
        .tint(store.state.isTimerRunning ? Theme.ink : Theme.accent)
        .accessibilityLabel("Turn timer")
        .accessibilityHint(store.state.isTimerRunning ? "Pauses the timer" : "Starts the timer")
    }

    nonisolated static func format(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

/// One player's score. Tap for +1, swipe right for +5 (a long swipe is +10), swipe left for −1,
/// press and hold to type any number.
struct PlayerTile: View {
    static let swipe: CGFloat = 40
    static let longSwipe: CGFloat = 140

    let player: Player
    let isActive: Bool
    let onAdd: (Int) -> Void

    @State private var dragX: CGFloat = 0
    @State private var isTyping = false
    @State private var bump = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.headline)
                    .lineLimit(1)
                if isActive {
                    Text("Their turn")
                        .font(.caption.weight(.medium))
                }
            }
            Spacer(minLength: 4)
            Text("\(player.score)")
                .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(value: Double(player.score)))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .foregroundStyle(Theme.text(player.color))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 84)
        .background(Theme.fill(player.color), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isActive ? Theme.accent : .clear, lineWidth: 3)
        }
        .overlay(alignment: dragX > 0 ? .leading : .trailing) { swipeHint }
        .offset(x: dragX * 0.3)
        .contentShape(.rect(cornerRadius: 16))
        .onTapGesture { add(1) }
        .onLongPressGesture(minimumDuration: 0.5) { isTyping = true }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Mostly-vertical drags belong to the scroll view.
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragX = value.translation.width
                }
                .onEnded { value in
                    let x = value.translation.width
                    if abs(x) <= abs(value.translation.height) {
                        // Scrolling, not swiping.
                    } else if x >= Self.longSwipe { add(10) } else if x >= Self.swipe { add(5) } else if x <= -Self.swipe { add(-1) }
                    withAnimation(.snappy) { dragX = 0 }
                }
        )
        .sensoryFeedback(.increase, trigger: bump)
        .animation(.snappy, value: player.score)
        .sheet(isPresented: $isTyping) {
            ScoreEntrySheet(player: player, onAdd: onAdd)
                .presentationDetents([.height(260)])
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(player.name), \(player.score) points\(isActive ? ", their turn" : "")")
        .accessibilityAdjustableAction { direction in
            add(direction == .increment ? 1 : -1)
        }
        .accessibilityAction(named: "Add 5") { add(5) }
        .accessibilityAction(named: "Add 10") { add(10) }
        .accessibilityAction(named: "Type a score") { isTyping = true }
    }

    @ViewBuilder
    private var swipeHint: some View {
        let label: String? = switch dragX {
        case Self.longSwipe...: "+10"
        case Self.swipe...: "+5"
        case ...(-Self.swipe): "−1"
        default: nil
        }
        if let label {
            Text(label)
                .font(.title3.bold())
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 10)
                .offset(x: dragX > 0 ? -44 : 44)
        }
    }

    private func add(_ delta: Int) {
        onAdd(delta)
        bump += 1
    }
}

/// Type any amount, plus or minus, for one player.
struct ScoreEntrySheet: View {
    let player: Player
    let onAdd: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isNegative = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Picker("Add or take away", selection: $isNegative) {
                        Text("Add").tag(false)
                        Text("Take away").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                    TextField("12", text: $text)
                        .keyboardType(.numberPad)
                        .font(.title.monospacedDigit())
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                }
                Text("\(player.name) has \(player.score).")
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding()
            .navigationTitle(player.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let amount = Int(text), amount != 0 {
                            onAdd(isNegative ? -amount : amount)
                        }
                        dismiss()
                    }
                    .disabled(Int(text) == nil)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
