import SwiftUI

/// The 4×4 glass board and its tiles. The whole board turns during a rotation
/// while each tile turns the other way, so the numbers stay upright.
struct BoardView: View {
    let store: GameStore
    let side: CGFloat

    private var inset: CGFloat { side * 0.04 }
    private var gap: CGFloat { side * 0.028 }
    private var cell: CGFloat { (side - 2 * inset - 3 * gap) / 4 }

    private func origin(row: Int, col: Int) -> CGPoint {
        CGPoint(
            x: inset + CGFloat(col) * (cell + gap),
            y: inset + CGFloat(row) * (cell + gap)
        )
    }

    /// The first pair of equal tiles sitting side by side, for the first-game hint.
    private var hintPair: (left: Tile, right: Tile)? {
        guard !store.hasMergedOnce, store.boardAngle == 0 else { return nil }
        let sorted = store.state.tiles.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
        for tile in sorted {
            if let neighbour = sorted.first(where: { $0.row == tile.row && $0.col == tile.col + 1 && $0.value == tile.value }) {
                return (tile, neighbour)
            }
        }
        return nil
    }

    var body: some View {
        let boardShape = RoundedRectangle(cornerRadius: side * 0.07, style: .continuous)

        ZStack(alignment: .topLeading) {
            boardShape
                .fill(Theme.boardFill)
                .overlay(boardShape.strokeBorder(Theme.boardStroke, lineWidth: 1.5))
                .shadow(color: Theme.boardGlow.opacity(0.55), radius: side * 0.06, x: 0, y: 0)

            ForEach(0..<(GameEngine.size * GameEngine.size), id: \.self) { index in
                let point = origin(row: index / GameEngine.size, col: index % GameEngine.size)
                let cellShape = RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                cellShape
                    .fill(Theme.cellFill)
                    .overlay(cellShape.strokeBorder(Theme.cellStroke, lineWidth: 1))
                    .frame(width: cell, height: cell)
                    .offset(x: point.x, y: point.y)
            }

            ForEach(store.displayTiles) { tile in
                let point = origin(row: tile.row, col: tile.col)
                TileView(value: tile.value, size: cell)
                    .rotationEffect(.degrees(-store.boardAngle))
                    .scaleEffect(store.poppedIDs.contains(tile.id) ? 1.14 : 1)
                    .offset(x: point.x, y: point.y)
                    .zIndex(store.isGhost(tile) ? 1 : 2)
            }

            ForEach(store.bursts) { burst in
                let point = origin(row: burst.row, col: burst.col)
                MergeBurst(color: Theme.tile(burst.value).top, size: cell)
                    .offset(x: point.x, y: point.y)
                    .zIndex(4)
            }

            if let pair = hintPair {
                let from = origin(row: pair.left.row, col: pair.left.col)
                Image(systemName: "arrow.right")
                    .font(.system(size: cell * 0.3, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .frame(width: gap + cell * 0.5, height: cell)
                    .offset(x: from.x + cell * 0.75, y: from.y)
                    .zIndex(3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: side, height: side, alignment: .topLeading)
        .rotationEffect(.degrees(store.boardAngle))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Game board"))
    }
}
