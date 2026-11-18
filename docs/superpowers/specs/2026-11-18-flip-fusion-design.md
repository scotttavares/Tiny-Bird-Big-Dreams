# Flip Fusion: design (v1)

## Intent
A native Swift iPhone puzzle game. Swipe to merge matching number tiles on a 4×4 board; after
every second move the board rotates and gravity re-settles the tiles, so a rotation can turn a
bad board into a chain reaction. The play screen must match the owner's Manus mockup.
Later money: puzzle packs and visual themes (not in v1).

## Goals
- Play screen matches the mockup: "Flip Fusion" gradient logo (cyan "Flip", pink-to-purple
  "Fusion", two small floating squares), SCORE card and Best card with a gold crown, the
  "ROTATES IN N MOVE(S)" pill with a yellow N, a 4×4 glass board with glossy neon tiles, a purple
  curved arrow sweeping clockwise around the board from the pill, the "Swipe. Merge. Rotate."
  tagline, three page dots, deep navy background.
- Tile colours from the mockup: 2 coral red, 4 mint green, 8 blue, 16 purple. Higher values
  continue the neon family (32 pink, 64 orange, 128 yellow, 256 teal, 512 indigo, 1024 magenta,
  2048+ gold).
- Rules below are deterministic and unit tested.

## Non-goals (v1)
In-app purchases, puzzle packs, extra themes, accounts, Game Center, sound, iPad-specific layout,
iPhone Duo features.

## Rules
- Board 4×4. Start with two tiles. Tiles spawn as 2 (90%) or 4 (10%).
- A swipe (up, down, left, right) slides every tile as far as it goes; two equal tiles that meet
  merge into their sum; a tile merges at most once per swipe. Score increases by each merged value.
- A swipe that changes nothing is not a move.
- After a valid swipe a new tile spawns in a random empty cell and the rotation counter drops by
  one (it starts at 2).
- When the counter reaches 0 the board rotates 90° clockwise, then gravity pulls tiles down.
  Falling tiles merge with an equal tile they land on, and merging repeats until nothing changes
  (a chain: 2,2,4 in a column becomes 8). Chain merges score too, with a combo multiplier
  (xN for the Nth cascade pass). No tile spawns from the rotation. Counter resets to 2.
- Game over: the board is full and no swipe changes it. (If the counter is at 1 the player still
  has no valid move, so rotation cannot be reached; that is game over.)
- Best score persists in UserDefaults. The game in progress is saved and restored.

## Screen behaviour (builder's calls, owner informed)
- The curved arrow and pill are always visible; the arrow pulses when N is 1.
- The "4→4" arrow in the mockup is a teaching hint: shown during the first game only, on a
  mergeable adjacent pair, until the first merge.
- The three dots are the theme pager: dot 1 is the Neon theme (active); dots 2 and 3 are locked
  slots that show "More themes coming soon".
- A small restart button sits in the game-over overlay, plus long-press on the logo for "New game".
- Haptics on merge, stronger on rotation.

## Approaches
1. SwiftUI views with a pure Swift game engine (picked): matches GameHost/PaperWars native setup,
   easy to unit test, glow and gloss are plain gradients and shadows.
2. SpriteKit: better for particle effects, but heavier and harder to match a static layout.
3. Web game in a WKWebView (as Paper Wars does): previewable on Windows, but the owner asked for
   a Swift app.

## Build and test
`FlipFusion/` folder in the tiny-bird repo, XcodeGen `project.yml`, bundle id
`com.tinybirdbigdreams.flipfusion`, iOS 26, portrait only. A `flipfusion-testflight` workflow in
`codemagic.yaml` copies the Paper Wars one. The owner tests on their iPhone through TestFlight.
There is no Mac here: the code cannot be compiled locally, so the engine is kept free of UI
imports and the first cloud build is the compile check.

## Added after the first TestFlight build (2026-11-18)

The first build felt endless: rotation and gravity keep clearing the board. The owner chose a timer.

- **Timed games.** Each game lasts 2 minutes. The clock starts on the first swipe, stops when the app leaves the screen and starts again on the next swipe. A countdown ring sits between the Score and Best cards; it turns red and ticks for the last 10 seconds. At zero the board shows "Time's Up" with the score. A full board with no move still ends the game early.
- **Sounds.** Swipe, merge (higher notes for bigger tiles), rotation, chain, last-seconds tick, game over, new game. Synthesised by `FlipFusion/scripts/make-sounds.py`; they follow the silent switch.
- **Effects.** A ring and sparks on every merge, and "+points" floating up from the Score card.

## Power-ups, starter set (2026-11-18)

Chosen by the owner from a short list. All are triggered by play; no new buttons.

- **Clock tile.** About 4 new tiles in 100 carry a clock badge. Merging one adds 10 seconds (the clock never goes above 2 minutes).
- **Bomb tile.** About 5 in 100 carry a flame badge. Merging one clears the eight cells around it; each cleared tile scores its own value.
- **Double points.** A chain of 2 or more after a rotation doubles every point for 10 seconds. The board glows pink and the Score card reads "SCORE x2". (The owner was told "3 or more"; 2 was used because a chain of 3 looked too rare to ever be seen. Change `GameStore.feverChain` to tune it.)
- A special tile is an ordinary number tile with a badge; the merged result is ordinary. Each kind is explained in a short banner the first time it appears.

## Two game modes and chain rewards (2026-11-18)

After playing build 15 the owner asked for a second mode and said no power-ups showed up after combos.

- **Timed** (first dot): the 2-minute game.
- **Endless** (second dot): no clock; the ring shows an infinity sign. The game ends when no move is left. One extra tile lands after every rotation so the board does fill, and there are no clock tiles.
- The dots under the tagline switch mode. Each mode keeps its own game in progress and its own best score, so switching loses nothing. The third dot says "More modes coming soon".
- **Chains drop a power-up.** A chain of 2 or more now also puts a power-up tile on the board (clock or bomb in Timed, bomb in Endless). Random power-up tiles are a little more common (5 clocks and 7 bombs per 100 new tiles).
- **More sounds:** a sparkle when a power-up tile lands, a riser when double points starts, a heavier bomb, a click on mode change.

## Intro and "How to play" (2026-11-18)

- **Intro.** Each launch opens with a two-second animation: tiles 2, 4, 8 and 16 drop in as a cluster, the cluster makes the quarter turn, the tiles fuse in a burst, and the logo and tagline appear. A tap skips it. It was designed from the usual shape of puzzle-game openings (logo reveal built from the game's own pieces), not from any one game.
- **How to play.** A "?" button in the top-right corner opens a sheet with the basics, the power-ups (shown with real tiles), the two modes, and a "Start a new game" button. It opens by itself the first time the game is seen. The clock stops while it is open.
- **Menu.** The owner asked whether there was a menu and a settings screen. The top-right button (three lines) now opens one sheet titled "Menu": game mode (Timed or Endless), "Start a new game", settings (sound effects, vibration, replay the intro), then "How to play".
