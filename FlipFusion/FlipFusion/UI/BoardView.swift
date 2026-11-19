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

    /// Everything of the board except its holes.
    private func boardMask(_ holes: [Block]) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .frame(width: side, height: side)
            ForEach(holes, id: \.self) { hole in
                let point = origin(row: hole.row, col: hole.col)
                RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                    .frame(width: cell, height: cell)
                    .offset(x: point.x, y: point.y)
                    .blendMode(.destinationOut)
            }
        }
        .frame(width: side, height: side, alignment: .topLeading)
        .compositingGroup()
    }

    var body: some View {
        let boardShape = RoundedRectangle(cornerRadius: side * 0.07, style: .continuous)
        let holes = store.state.blocks.filter { $0.kind == .hole }
        let holeCells = Set(holes.map(\.cell))

        ZStack(alignment: .topLeading) {
          // The board and its cells change colour with every level.
          ZStack(alignment: .topLeading) {
            boardShape
                .fill(Theme.boardFill)
                // The board glows pink while points count double.
                .overlay(boardShape.strokeBorder(store.isFever ? Theme.fusion[0] : Theme.boardStroke, lineWidth: store.isFever ? 3 : 1.5))
                // A hole is cut right through the board: the backdrop shows through.
                .mask {
                    boardMask(holes)
                }
                .shadow(
                    color: (store.isFever ? Theme.fusion[0] : Theme.boardGlow).opacity(store.isFever ? 0.9 : 0.55),
                    radius: side * (store.isFever ? 0.09 : 0.06),
                    x: 0,
                    y: 0
                )
                .animation(.easeInOut(duration: 0.3), value: store.isFever)

            ForEach(0..<(GameEngine.size * GameEngine.size), id: \.self) { index in
                let point = origin(row: index / GameEngine.size, col: index % GameEngine.size)
                let cellShape = RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                if holeCells.contains(Cell(row: index / GameEngine.size, col: index % GameEngine.size)) {
                    // The rim of a hole.
                    cellShape
                        .strokeBorder(Theme.boardStroke, lineWidth: 2.5)
                        .frame(width: cell, height: cell)
                        .offset(x: point.x, y: point.y)
                } else {
                    cellShape
                        .fill(Theme.cellFill)
                        .overlay(cellShape.strokeBorder(Theme.cellStroke, lineWidth: 1))
                        .frame(width: cell, height: cell)
                        .offset(x: point.x, y: point.y)
                }
            }
          }
          .frame(width: side, height: side, alignment: .topLeading)
          .hueRotation(.degrees(Double((store.level - 1) % 9) * 40))
          .animation(.easeInOut(duration: 0.6), value: store.level)

            // Walls and crates stand on the board and keep their own colours.
            ForEach(store.state.blocks.filter { $0.kind != .hole }, id: \.self) { block in
                let point = origin(row: block.row, col: block.col)
                ObstacleView(kind: block.kind, size: cell)
                    .rotationEffect(.degrees(-store.boardAngle))
                    .offset(x: point.x, y: point.y)
                    .zIndex(1)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }

            ForEach(store.displayTiles) { tile in
                let point = origin(row: tile.row, col: tile.col)
                TileView(value: tile.value, kind: tile.kind, size: cell)
                    .rotationEffect(.degrees(-store.boardAngle))
                    .scaleEffect(store.poppedIDs.contains(tile.id) ? (Skin.current.isPremium ? 1.36 : 1.24) : 1)
                    .offset(x: point.x, y: point.y)
                    .zIndex(store.isGhost(tile) ? 1 : 2)
            }

            ForEach(store.bursts) { burst in
                let point = origin(row: burst.row, col: burst.col)
                MergeBurst(color: Theme.tile(burst.value).top, size: cell, isBlast: burst.isBlast, isSuper: burst.isSuper, points: burst.points, heat: burst.heat)
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
