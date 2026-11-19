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

## Arcade feel: boosters, coins, speed streak, music (2026-11-18)

The owner showed two App Store listings (a colour-block puzzle and a one-minute match-3) and said "make it fun like this". Nothing of theirs is copied; what was taken is the general shape of the genre:

- **Boosters** under the board, tapped to use: **Flip** (turn the board now, no move used), **Sweep** (clear every 2 and 4), **Double** (double points for 10 seconds). Three free uses of each, then 150 / 250 / 200 coins.
- **Coins**, shown top-left: one for every 20 points, shared by both modes. No purchases.
- **Speed streak:** a swipe that merges within 4 seconds of the last one multiplies points, x2 up to x5, shown as a yellow chip beside the rotation pill. It stacks with double points.
- **Juice:** points float up out of each merge on the board; the board shakes on bombs, chains and sweeps.
- **Music:** a 30-second arcade loop composed in `FlipFusion/scripts/make-music.py`, with a Music switch in the menu.
- To make room for the booster bar the tagline and dots sit closer to the board than in the mockup.

## Super combos, more bombs, animations, gems and themes (2026-11-18)

After playing build 19 the owner asked for more excitement (shakes, bombs), more music, an explanation of the three dots, merges of more than two tiles, animations in the spirit of a well-known match-3 game, and themes bought with gems or won in play. Nothing of that game's is copied (no art, names, characters or words); what was taken is the general idea of a lively, rewarding puzzle screen.

- **Super combos.** Equal tiles that meet in one slide all merge: two 2s make a 4, three make an 8, four make a 16 ("mega combo"). The tile they make does not merge again in that slide. This applies to swipes and to gravity after a rotation.
- **Bombs.** 12 in 100 new tiles are bombs (was 7). A bomb caught in a blast goes off too. A fourth booster, **Bombs** (200 coins after three free uses), turns up to three ordinary tiles into bombs.
- **Shakes and flashes.** Three strengths of shake: a nudge for a merge that makes 64 or more, a jolt for super combos, chains and sweeps, a blast for bombs. Bombs and super combos flash the board white. Special tiles throb.
- **Animations.** Big words bounce in over the board ("Boom!", "Chain x2!", "Super combo!", "MEGA COMBO!", "Nice!", "Unstoppable!", "10 seconds!"); confetti on super combos, chains and a new best score; buttons squash when pressed; the game-over card springs in.
- **Music.** Three tunes from `scripts/make-music.py`: the timed game (45 seconds), the endless game (slower), and a fast one that takes over during double points and the last 20 seconds of a timed game.
- **Mode buttons.** The three dots are gone (the third did nothing and none were labelled). Two labelled buttons, "2 Minutes" and "Endless", sit under the tagline. The arrow's trail now stops at the board's bottom-right corner so it no longer runs through the boosters.
- **Gems**, shown beside the coins: 1 for a super combo, 3 for a mega combo, 1 for a chain, and at the end of a game 1 per 500 points plus 2 for a new best.
- **Themes** in the menu (`Game/Skin.swift`, colours worked out in `UI/Theme.swift`): Neon (free), Sunset (15 gems), Ocean (30), Bubblegum (50), Gold Rush (won by scoring 2,000 in one game), Galaxy (won by a mega combo).
- **Not built:** buying gems with real money. That needs in-app purchase products in App Store Connect, a signed Paid Apps agreement with bank and tax details, prices chosen by the owner, and StoreKit code.

## Buying gems (2026-11-18)

The owner asked for gems to be on sale. `Game/GemShop.swift` (StoreKit 2) sells three consumable packs, with prices set in App Store Connect and chosen by the owner: 25 gems $0.99 (`…flipfusion.gems.small`), 60 gems $1.99 (`.gems.medium`), 150 gems $3.99 (`.gems.large`). The shop is the "Get more gems" section of the menu. Gems are handed over only for a purchase Apple has verified, and each purchase counts once (`GameStore.addPurchasedGems`). Gems live on the device only: there is no account, so they do not follow the player to a new phone. The paid themes cost 95 gems in all, so more things to spend gems on are needed before the larger packs make sense.

## Levels, a prize reel, themes with their own look, a better shop (2026-11-18)

After playing build 23 the owner said the themes were "just a different colour background", asked whether the gem prices were appealing, and said the game was "kind of boring": it should get harder as it goes and be exciting. They showed an advert for a well-known match-3 game (big effects, a star-rated victory screen, a new board each level) and pointed to slot machines. Nothing of that game's is copied; the ideas taken are general ones.

- **Levels** (`GameEngine.level(forScore:)`). A game starts on level 1; levels begin at 200, 500, 900, 1,400, 2,000, 2,700 points and so on. A bar under the score cards shows the way to the next one. Each new level: a call-out, confetti, a new board colour, a spin of the prize reel, and 10 more seconds in the timed game.
- **It gets harder.** From level 3 some new tiles are **stone blocks** (4 in 100, rising to 14; never more than 3 on the board): they slide and fall but never merge, and only a bomb's blast or Sweep clears them. From level 4 a move sometimes drops a second new tile (10 in 100, rising to 40), never onto a board with two or fewer empty cells.
- **Danger.** With two or fewer empty cells the board's rim beats red, the phone buzzes once and the fast tune plays.
- **Prize reel.** A reel flicks through prizes and stops on the one won: 50 coins (40 in 100), 100 coins (25), a free booster (15), 1 gem (14), 2 gems (5), the 5-gem jackpot (1). It is always free and always pays something. **Spins are never sold**, for gems or money: the game is meant for all ages, and paid games of chance would also need published odds under Apple's rules.
- **Stars.** The end-of-game card shows one star for level 2, two for level 4, three for level 6.
- **Keep going.** Once per game, 5 gems carry on a game that has ended: 30 more seconds when time ran out, or the six smallest tiles cleared (stone blocks first) when no move is left. Without the gems the button opens the menu, where the gem shop is.
- **Themes are now more than colours** (`Game/Skin.swift`, `UI/Scenery.swift`). Each has a moving backdrop, a tile shape and its own sparks: Neon (free; rolling grid), Sunset (15 gems; striped sun), Ocean (30; bubble tiles, rising bubbles), Bubblegum (50; jelly tiles, hearts), Lava (80; six-sided tiles, embers), Frost (120; crystal tiles, snow), Gold Rush (score 2,000; cut-gem tiles, falling gold), Party Lights (reach level 7; sweeping lights), Galaxy (mega combo; planet tiles, shooting stars). The paid themes now cost 295 gems in all. Backdrops stand still when Reduce Motion is on.
- **Menu.** Themes are cards in two columns, each showing three of its tiles in front of its backdrop. Gem packs are cards with "POPULAR" and "BEST VALUE" labels and how many more gems per dollar the bigger packs give, worked out from the App Store's own prices.
- **Not built:** boards of different shapes (walls or holes). Only the board's colour changes with the level.

## Board shapes and the Shape Shift game (2026-11-18)

The owner asked for boards of different shapes with walls and holes, then for "a bunch of board shapes with all kinds of obstacles that change" and a new game mode where the board changes at random while playing.

- **Blocks** (`Block` in `Game/Board.swift`, kept in `GameState.blocks`). A blocked cell lets no tile in: tiles stop beside it, do not merge across it, rest on it under gravity, and new tiles never land on it. Blocks turn with the board. Three kinds: a **wall** (a solid block), a **hole** (cut through the board, the backdrop shows through) and a **crate**, which a merge in the cell directly beside it or a bomb's blast smashes for 20 points.
- **Fourteen shapes** plus the open board (`GameEngine.layouts`), each with one to three blocks.
- **Timed and Endless:** level 1 is the open board; each level from 2 is played on the next shape, starting over after the fourteenth. The shape changes at the end of the move that reached the level.
- **Shape Shift**, a third game mode with its own saved game and best score: no clock, and every 4 moves the board changes to a different shape picked at random and turned a random number of quarter turns. The line under the boosters counts down the moves. It ends when no move is left.
- **When the shape changes**, a tile standing where a block now is jumps to a random empty cell, biggest tiles first. If the board has no empty cell, that tile is removed (rare: it needs a full board).
- Games saved before this have no blocks and open as before.
- Walls and holes follow the same rule on purpose; a hole that swallowed tiles would drain whole columns after every rotation on a board this small.

## Themes bring boards, effects and a game; the intro keeps its look (2026-11-18)

The owner asked that themes "unlock new board games and boards and better animations but cost more gems", and that the opening animation never change with the theme.

- **Prices:** Sunset 40 gems, Ocean 80, Bubblegum 120, Lava 180, Frost 250 (670 in all; they were 15 to 120). Gold Rush, Party Lights and Galaxy are still won in play.
- **Two boards per theme.** Each theme but Neon has two shapes of its own (`Skin.boards`, places 15 to 30 in `GameEngine.layouts`). With the theme on, levels 2 and 3 are played on them before the standard shapes, and the Shape Shift game deals them as well.
- **Bigger effects** with any theme but Neon: merges throw six more sparks and a second ring, merged tiles pop larger, and confetti is made of the theme's own sparks.
- **Shape Shift unlocks with the player's first theme beyond Neon**, bought or won (`GameStore.isUnlocked`). Until then its button shows a padlock and says how to open it. Gold Rush (score 2,000) opens it without spending anything.
- **The intro** always plays in the original Neon look: its own backdrop, Neon tiles, plain round sparks.
- The largest gem pack is 150 gems, so the dearest themes now take more than one pack. A bigger pack would need a new product in App Store Connect.

## Full scenes, theme moments, theme music, and a clearer board (2026-11-18)

After playing build 25 the owner asked for much richer themes (fish and a shark for Ocean, a volcano with real-looking lava for Lava, piling snow and a snowman for Frost, an 80s look with neon tiles for Neon), music for each theme, stone blocks that look like 3D stone with versions for themes, messages that never cover the tiles, the game modes moved into the menu, the tagline moved, and themed graffiti on the game-over card.

- **Scenes** (`UI/ThemeScenes.swift`). Ocean: shafts of light, swaying weed, three kinds of fish, jellyfish. Lava: a volcano with lava streams, a heaving pool with bubbles that pop, a small spurt every five seconds. Frost: snowy pines, a blanket of snow, a waving snowman, and snow that settles along the top of the board until a turn shakes it off. Neon: stars, a wire-frame mountain range, turning neon triangles over the rolling grid.
- **Moments.** A new level, a four-tile merge, or five merges before a turn plays the theme's moment over the whole screen for 1.8 seconds: a shark bursting up with open jaws (Ocean), an eruption whose lava lands and drips on the board (Lava), a blizzard (Frost), laser bars (Neon). They never block touches and are skipped with Reduce Motion. The shark is a generic shark, not any film's.
- **Neon tiles** are dark glass with a glowing tube round the edge. The original glossy look lives on as `Skin.classic`, which only the intro uses.
- **Music.** `scripts/make-theme-music.py` composes one looping tune per theme (`music-<theme>.wav`) from a chord progression and a motif, in a style of its own. The theme's tune plays in every mode; the fast tune still takes over for double points, the last seconds and danger.
- **Stone blocks** are boulders with thickness, faces, cracks and speckles, made of something different in each theme: rock, sandstone, coral, rock candy, cooling magma with glowing cracks, ice, a gold nugget, mirror stone, moon rock with craters.
- **Nothing covers the board any more.** Messages appear over the title. The prize reel sits in a strip under the boosters. Call-out words sit at the board's top edge and last about half a second.
- **Layout.** "Swipe. Merge. Rotate." is under the logo. The mode buttons are gone from the game screen: the strip under the boosters names the game in play (or counts down to the next shape) and opens the menu, whose first section lists the three games as cards.
- **Game-over graffiti.** The card shows the theme's word at a slant ("Wipeout!", "Burned!", "Frozen!", "Game over, dude!" and so on) and its sparks scattered like stickers.

## Scenes and moments for the other five themes (2026-11-19)

The owner asked for the remaining themes to get full scenes and moments too (`UI/ThemeScenesMore.swift`). Every theme now has both.

- **Sunset:** a glittering sea under the striped sun, two swaying palms, thin clouds, a few birds. Moment: the sun flares and a great flock sweeps across.
- **Bubblegum:** pastel hills, rising balloons, falling sprinkles, gum bubbles that swell and pop. Moment: one enormous bubble swells over the screen and bursts.
- **Gold Rush:** rocky ground with glinting veins of gold, a rail track, a mine cart heaped with gold rolling across. Moment: gold coins pour down, spinning.
- **Party Lights:** a mirror ball throwing beams, a dance floor whose squares light in turn. Moment: fireworks.
- **Galaxy:** drifting clouds of colour, a ringed planet with a moon, a flying saucer now and then. Moment: the stars stretch into streaks and a rocket flies across.

## Real outlines, 3D obstacles, bomb and clock tiles, speed lightning (2026-11-19)

More requests from the owner after playing build 27.

- **Shape Shift changes the board's outline.** The owner found that the board "doesn't change to a new shape, it just rotates". Shape Shift now deals only **outlines**: eight layouts made entirely of holes (places 31 to 38 in `GameEngine.layouts`) that cut the board into a Triangle (10 cells), Circle, Ring, Corner, Tee (10 cells), Cup, Beam or Zigzag (12 cells unless noted), never the same one twice running, turned a random way. The call-out names the shape. In these layouts a hole takes out its cell and the gap round it, out to the board's edge, so the holes join up and the board's silhouette changes. A board has at most six blocks. A shape with fewer cells than there are tiles drops the tiles that have nowhere to go.
- **Obstacles look like what they are.** A wall is a brick block with a lit top. A crate is a wooden crate with a lid, crossed braces and nails. A hole (outside Shape Shift) is a dark pit with a lit rim, rings that sink into it and specks that spiral down it. The rules have not changed: tiles still stop at the edge of a hole and do not fall in, because a hole that swallowed tiles would empty whole columns after every rotation.
- **Bomb tile:** a round black bomb with its number on it and a fuse whose tip sparks. **Clock tile:** an alarm clock with its number on the face and a hand going round. Both look the same in every theme.
- **Speed bonus:** each time it goes up, lightning strikes down the left edge of the board and speed lines streak across its top edge, with a sound.
- **Chain reward:** the power-up tile lands with a big burst and a flash, the call-out says "Chain x2! Double points!", and the theme's big moment plays.

## Twist, a livelier arrow, obstacles that move (2026-11-19)

- **Twist**, a fourth game mode: no clock, an extra tile after every turn, and after any turn the board may (one time in two) start turning the other way. The arrow is mirrored to show which way the next turn goes, the strip under the boosters says it in words, and "Reversed!" is called out when it changes. It unlocks once the player has two themes beyond Neon (`GameStore.themesNeeded`); Shape Shift still needs one.
- **The arrow** now moves all the time: its head nods along the path, light runs down the trail in waves, and beads of light travel from the pill to the trail's end. All of it speeds up when the turn is one move away. It stands still with Reduce Motion.
- **Walls and crates move a little:** a crate rocks gently and a gleam of light slides across a wall.

## The shark stirs the board (2026-11-19)

At the owner's request the Ocean theme's shark now changes the game: as it covers the board (0.8 seconds into its moment) every tile is thrown to a random cell and up to two are knocked off, stone blocks first and then the smallest tiles, never leaving fewer than two (`GameStore.stirBoard`). If a move is still playing it tries once more 0.6 seconds later. This makes Ocean play differently from the other themes, on purpose.

## Painted backdrops (2026-11-19)

The owner asked for premium art from an image connector and chose theme backdrops first. A theme may now have a painted backdrop: an image named `backdrop-<theme id>` in the asset catalogue (`PaintedBackdrop` in `UI/Scenery.swift`). When one exists it replaces the plain gradient behind the game and on the theme's card, and the animated scene draws only what moves. A theme without one looks as before.

Only **Neon** has one so far (generated with the owner's OpenArt account, GPT Image 2.5 Sunburst, 9:16 at 2K, 10 credits). The account had 19 credits and the Higgsfield account none, so the other eight wait on more credits (about 80 at the same settings). A small preview is kept at `docs/flipfusion/backdrop-neon-preview.jpg`.

## A swirling arrow, Fruit Salad and Fusion (2026-11-19)

- **The arrow** is drawn in two layers. A faint arrow stays put so the direction of the next turn can always be read. Over it a glowing comet with an arrowhead swirls along the same path: it sweeps down the side of the board four times, then flies one whole lap round it, and laps without stopping when the turn is one move away. It has a blurred glow, a tube-like tail with a bright core, and sparks. Mirrored when the Twist game is turning left.
- **Fruit Salad**, a fifth game mode, open to everyone: no clock, and every tile shows a fruit in place of its number (`Game/Fruit.swift`): cherries, strawberry, orange, lemon, apple, grapes, watermelon, pineapple, coconut, peach, then a star. The rules are unchanged; only the faces differ. The fruit are the system's own emoji.
- **Fusion**, a sixth game mode, unlocked with three themes: no clock, and after every move one ordinary tile picked at random changes by itself. Six times in ten it doubles; otherwise it halves (a 2 stays a 2).
- Every game without a clock except Shape Shift adds an extra tile after each turn, so each of them ends.

## Opening crates (2026-11-19)

The owner asked for crates that can be opened at the cost of a turn and may hold something valuable or something deadly. A tap on a crate opens it (`GameStore.openCrate`). Opening is a move: it counts toward the next turn of the board (and toward the next shape in Shape Shift), though no new tile is added. What is inside, out of 100: 100 coins (22), a gem (12), a free booster (12), double points (8), ten seconds on the clock or 100 coins where there is no clock (8); then a monkey that jumps out and mixes the tiles up (16), a shark that mixes them up and eats two (12), and two stone blocks (10). So 62 in 100 are prizes. The monkey is shown springing out over the board for about a second; the shark plays the Ocean theme's shark in whatever theme is on. Smashing a crate with a merge or a bomb still gives 20 points and nothing else.

Premium generated art for the crates, rocks and holes was asked for too, but the OpenArt account had 9 credits left (an image costs 10) and the Higgsfield account none, so they are still drawn in code.

## Painted art for every theme and for the obstacles (2026-11-19)

The owner topped up the OpenArt account and asked for premium art, with backgrounds that are "live".

- **Backdrops.** All nine themes now have a painted backdrop (`backdrop-<theme id>` in the asset catalogue; GPT Image 2.5 Sunburst, 9:16 at 2K). Each keeps its sky dark and plain behind the interface and puts its scenery low: a sunset over the sea with palms, a coral reef, pastel hills, a volcano above a lava pool, a snowy forest under an aurora, a gold mine cavern, a dance club floor, a ringed planet.
- **Live.** A backdrop is never a still picture. The painting drifts and breathes very slowly, and the theme's moving layer plays over it: fish and jellyfish, lava spurts and bubbles and embers, falling snow and the snowman, birds and glints on the sea, balloons and gum bubbles, the mine cart, the mirror ball and its beams, twinkling stars and a flying saucer. With a painting behind it the scene code skips whatever the painting already shows (`painted` in `SceneArt.draw`). The volcano's crater and the sea's horizon were moved to where the paintings have them.
- **Obstacles.** The crate, the brick wall, the hole and the stone block are painted 3D objects (`obstacle-crate`, `obstacle-wall`, `obstacle-hole`, `obstacle-rock`; Seedream 5.5, transparent background). The stone block is one grey boulder tinted for each theme. The crate still rocks, the wall still gleams, and specks still spiral into the hole. Each falls back to its drawn version if its image is missing.
- Previews are kept in `docs/flipfusion/`. The twelve images cost about 130 credits.
