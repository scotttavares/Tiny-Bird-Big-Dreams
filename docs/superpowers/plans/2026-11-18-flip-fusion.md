# Flip Fusion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A SwiftUI iPhone game, Flip Fusion, whose play screen matches the owner's mockup and whose board rotates with gravity every two moves, delivered to TestFlight by Codemagic.

**Architecture:** A pure-Swift, UI-free engine (`Board`, `GameEngine`) holds the rules and is unit tested. An `@Observable` `GameStore` wraps the engine, sequences animation phases (swipe, spawn, rotate, settle) and persists state. SwiftUI views draw the mockup from the store.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, Swift Testing, XcodeGen, Codemagic. iOS 26.0 minimum.

**Spec:** `docs/superpowers/specs/2026-11-18-flip-fusion-design.md`

## Global Constraints

- Folder `FlipFusion/` at the repo root; bundle id `com.tinybirdbigdreams.flipfusion`; display name `Flip Fusion`.
- Portrait only, iPhone (`TARGETED_DEVICE_FAMILY: "1"`), dark appearance forced.
- No third-party dependencies. No network. Only UserDefaults for storage.
- No Mac here: nothing can be compiled or run locally. Keep code conservative (no new or uncertain APIs); the Codemagic build is the compile check, and it runs the unit tests before archiving.
- Copy is exact: `Flip` `Fusion`, `SCORE`, `Best`, `ROTATES IN`, `MOVE` / `MOVES`, `Swipe. Merge. Rotate.`

## Review Focus

- Swipe that changes nothing: must not spawn, count as a move, or tick the rotation counter.
- Rotation on a full board: must never lose or duplicate a tile; total of tile values is preserved.
- Cascade on rotation: `[2,2,4]` stacked in a column must end as one `8` (two passes), not `4,4`.
- Restored saved game from an older or corrupt blob: must fall back to a new game, not crash.
- Very fast repeated swipes during an animation: inputs are ignored until the phase sequence ends; the state never desynchronises.

---

### Task 1: Engine

**Files:**
- Create: `FlipFusion/FlipFusion/Game/Board.swift`, `FlipFusion/FlipFusion/Game/GameEngine.swift`
- Test: `FlipFusion/FlipFusionTests/GameEngineTests.swift`

**Interfaces (produced):**

```swift
enum Direction: Sendable, CaseIterable { case up, down, left, right }
struct Tile: Identifiable, Equatable, Codable, Sendable { let id: Int; var value: Int; var row: Int; var col: Int }  // row 0 = top
struct StepResult: Equatable, Sendable { var tiles: [Tile]; var mergedIDs: Set<Int>; var removedIDs: Set<Int>; var gained: Int; var changed: Bool }
struct GameState: Equatable, Codable, Sendable { var tiles: [Tile]; var score: Int; var movesUntilRotation: Int; var nextID: Int }
enum GameEngine {
  static let size = 4
  static let movesPerRotation = 2
  static func slide(_ tiles: [Tile], _ dir: Direction) -> StepResult          // one merge per tile per swipe
  static func rotateClockwise(_ tiles: [Tile]) -> [Tile]                      // (r,c) -> (c, size-1-r)
  static func settle(_ tiles: [Tile]) -> [StepResult]                         // gravity passes until stable; pass n scores gained * n
  static func emptyCells(_ tiles: [Tile]) -> [(row: Int, col: Int)]
  static func spawn(in state: inout GameState, using rng: inout some RandomNumberGenerator) -> Tile?   // 2 at 90%, 4 at 10%
  static func hasMove(_ tiles: [Tile]) -> Bool
  static func newGame(using rng: inout some RandomNumberGenerator) -> GameState   // two tiles, counter 2
}
```

A merge keeps the id of the tile nearer the wall being moved toward, doubles its value, and lists the other id in `removedIDs` (the removed tile's final position equals the survivor's, so the view can animate it sliding in). A gravity pass in `settle` is `slide(.down)` semantics where a tile may merge only once per pass; passes repeat while a pass merges anything.

- [ ] Write tests (Swift Testing): slide left `[2,2,4,_]` → `[4,4,_,_]` gained 4; `[2,2,2,2]` → `[4,4,_,_]`; no-op slide has `changed == false`; `rotateClockwise` moves (0,0)→(0,3), (0,3)→(3,3), (3,0)→(0,0); settle of column top-to-bottom `2,2,4,_` yields single `8` at row 3 with two passes and gained `4*1 + 8*2 = 20`; rotation + settle of a full board of distinct values preserves the sum and count; `hasMove` false on a full checkerboard of 2/4, true if any equal neighbours; `spawn` returns nil on a full board; `newGame` has 2 tiles, score 0, counter 2.
- [ ] Implement.
- [ ] Commit.

### Task 2: Store and persistence

**Files:**
- Create: `FlipFusion/FlipFusion/Game/GameStore.swift`
- Test: `FlipFusion/FlipFusionTests/GameStoreTests.swift`

**Interfaces (produced):**

```swift
@MainActor @Observable final class GameStore {
  private(set) var state: GameState
  private(set) var best: Int
  private(set) var isGameOver: Bool
  private(set) var boardAngle: Double        // degrees, animated during rotation, 0 at rest
  private(set) var poppedIDs: Set<Int>       // tiles to pulse this phase
  private(set) var lastCombo: Int            // cascade passes in the last rotation (0 if none)
  private(set) var isAnimating: Bool
  var hasMergedOnce: Bool                    // persisted; hides the tutorial hint
  init(defaults: UserDefaults = .standard, animated: Bool = true)
  func swipe(_ dir: Direction)               // ignored while animating or game over
  func newGame()
}
```

`swipe` sequence: slide (0.14 s) → spawn → decrement counter → if 0: animate `boardAngle` 0→90 (0.45 s), then swap tiles to rotated coordinates with `boardAngle = 0` without animation, then each settle pass (0.16 s each), reset counter to 2 → game-over check → save. With `animated: false` the whole sequence runs synchronously (for tests). Keys: `ff.state` (JSON `GameState`), `ff.best`, `ff.merged`. A blob that fails to decode, or has tiles out of range or overlapping, starts a new game.

- [ ] Tests (with `animated: false` and a per-test `UserDefaults(suiteName:)`): no-op swipe leaves state identical; two valid swipes return counter to 2; best follows score and survives a new store on the same defaults; state restores across stores; corrupt `ff.state` data gives a fresh 2-tile game.
- [ ] Implement.
- [ ] Commit.

### Task 3: Play screen

**Files:**
- Create: `FlipFusion/FlipFusion/App/FlipFusionApp.swift`, `FlipFusion/FlipFusion/UI/Theme.swift`, `UI/GameScreen.swift`, `UI/LogoView.swift`, `UI/ScoreCards.swift`, `UI/RotatePill.swift`, `UI/BoardView.swift`, `UI/TileView.swift`, `UI/RotationArrow.swift`, `UI/GameOverOverlay.swift`

Layout top to bottom, matching the mockup proportions on a 393 pt wide screen (scale by `width / 393`):
logo (height ~70) · score row (two cards ~120×58, gap 90 between, 14 pt radius) · pill (capsule ~220×36) · board (square, width − 2×28, 22 pt radius, 4 cells with 10 pt gaps, 14 pt cell radius) · tagline (20 pt semibold rounded, `#C9D2F5`) · 3 dots (8 pt; active `#39C6F4`, others `#3A4480`).

Colours (`Theme.swift`):
- Background: vertical gradient `#0B1038` → `#070A26`, with a faint radial `#1B2A7A` glow behind the board.
- Card/board glass: fill `#101A52` at 0.75, stroke `#2B3C9A` 1 pt; board has an outer glow `#3D5BFF` 0.45, radius 18; empty cell `#0C1444` with stroke `#1E2A70`.
- Pill: fill gradient `#3A2BB5` → `#2A1E8C`, stroke `#7C6BFF`, text white 15 pt heavy rounded, number `#FFD23F`.
- Tiles (top → bottom gradient, glow colour): 2 `#FF8A7A`→`#E8504F`; 4 `#7FF0B4`→`#2FBF7F`; 8 `#5CB8FF`→`#2B6FF0`; 16 `#B98CFF`→`#7B3FF2`; 32 `#FF8AD8`→`#E0409F`; 64 `#FFB067`→`#F0701F`; 128 `#FFE26A`→`#F0B41F`; 256 `#6AF0E6`→`#1FB5B0`; 512 `#8C98FF`→`#4A4FE0`; 1024 `#F27CFF`→`#B62FE0`; 2048+ `#FFE9A0`→`#E0A020`. Each tile: white 0.45 top inner highlight (a gradient-stroked rounded rect and a soft white capsule over the top third), glow shadow of its bottom colour radius 10, numeral white heavy rounded with a dark 0.25 shadow; font size 34 for 1–2 digits, 26 for 3, 20 for 4.
- Logo: "Flip" gradient `#7FE9FF` → `#3FA9FF`; "Fusion" gradient `#FF7AD9` → `#A56BFF`; 52 pt black rounded, glow shadows of each colour; a small rotated cyan square top-left and blue square top-right.
- Score cards: `SCORE` label 12 pt bold `#AEB9F0` over value 26 pt heavy white; Best card has a gold crown (`crown.fill`, `#FFC93C`) left of `Best` label and the value.
- Arrow: a stroked arc (gradient `#B77CFF` → `#6C4BFF`, line width 7, round caps, glow) that starts at the pill's right end, sweeps clockwise down the board's right side and along its bottom to the bottom-left corner, with an arrowhead where it passes the upper-right of the board. Opacity pulses 0.6↔1.0 when `movesUntilRotation == 1`.

Behaviour: `DragGesture(minimumDistance: 16)` on the whole screen picks the dominant axis. Tiles are positioned by `offset` from row/col and keyed by id so moves animate; new tiles scale in from 0.2; `poppedIDs` tiles pulse to 1.15. The board container rotates by `store.boardAngle` while numerals counter-rotate to stay upright. Tutorial hint: when `!hasMergedOnce` and two equal tiles are horizontally adjacent, draw a small white arrow between the first such pair. Combo toast `Chain x{n}!` over the board for 0.9 s when `lastCombo >= 2`. Game-over overlay: dimmed board, `Game Over`, score, `Play Again` button. Long-press the logo → confirmation dialog `New game?`. Tapping dot 2 or 3 shows a brief `More themes coming soon` toast. Haptics: `.sensoryFeedback` impact on merge, heavier on rotation. Accessibility: board has a label listing the counter; each tile's label is its value.

- [ ] Implement the views.
- [ ] Commit.

### Task 4: Project and CI

**Files:**
- Create: `FlipFusion/project.yml` (copy of `PaperWars/project.yml` shape, no entitlements, iPhone only, portrait only, `UIUserInterfaceStyle: Dark`, launch screen colour `LaunchBackground`), `FlipFusion/FlipFusion/Resources/Assets.xcassets` (AccentColor, LaunchBackground `#0B1038`, AppIcon with one 1024 PNG), `Resources/PrivacyInfo.xcprivacy` (UserDefaults CA92.1), `FlipFusion/README.md`, `FlipFusion/.gitignore` for `*.xcodeproj` and `build/` if the other apps ignore them.
- Modify: `codemagic.yaml` — add `flipfusion-testflight` after `paperwars-testflight`: `working_directory: FlipFusion`, push trigger on `claude/*` with `changeset.includes: ['FlipFusion/**']`, `xcode: latest`, XcodeGen step, a unit-test step on a simulator, the same signing step, build number from `PROJECT_BUILD_NUMBER`, upload to TestFlight.
- App icon: generated 1024×1024 PNG (navy background, four neon tiles, purple arc), made with a local script kept in `FlipFusion/scripts/`.

- [ ] Write the files.
- [ ] Validate YAML parses (`python -c "import yaml; yaml.safe_load(open('codemagic.yaml'))"`, same for `project.yml`).
- [ ] Commit and push the branch.
