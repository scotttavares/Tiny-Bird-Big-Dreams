# Mood Magnets

A physics puzzle game for iPhone (and iPhone Duo) built with **SwiftUI + SpriteKit**.
Every jelly has a mood, and moods act like magnets. Pick a mood, tap a jelly, and watch
the cast pull, push, hug and hop their way into their nests.

| Mood | Field | Reacts |
| --- | --- | --- |
| **Happy** (sunny yellow) | Pulls Happy and Nervous jellies close | Normal |
| **Grumpy** (berry red) | Pushes everyone away | Heavy, barely budges |
| **Nervous** (mint) | None | Light; reacts 1.5× to every field |

Touch rules: a Happy hug (≈0.45 s of contact) cheers a Nervous jelly up into a Happy one;
a Nervous jelly that bumps anything Grumpy jumps away in fright. Mood Stones are fixed
magnets, and stones with a dotted ring can be re-moodied too. Fall off the bottom and the
level fails. Fewer mood changes earn more stars (par = 3 stars).

## Layout

```
MoodMagnets/
  project.yml                 XcodeGen spec (the .xcodeproj is generated, not committed)
  MoodMagnets/
    Core/                     Deterministic 120 Hz physics + mood rules (no UIKit)
    Game/                     SpriteKit: scene, jelly/stone nodes, procedural art, haptics
    UI/                       SwiftUI screens, posture-adaptive game layouts
    Duo/                      iPhone Duo posture detection (shared design with Field Guide)
    Resources/levels.json     The 10 levels — single source of truth for game, tests and tools
  MoodMagnetsTests/           XCTest: every level's stored solution wins, idling never does
  tools/                      Python mirror of the engine for designing/solving levels
  scripts/ci.sh               Build + test on a simulator (used by GitHub Actions)
  scripts/screenshots.sh      Posture screenshots via -MMAutoSolve
```

## iPhone Duo / adaptive layouts

| Posture | Layout |
| --- | --- |
| Closed (any iPhone, or Duo folded) | Board + bottom mood tray |
| Book (Duo unfolded, iPad, iPhone landscape) | Board on the left page; level story, big mood picker and live cast on the right |
| Laptop (Duo half-folded, horizontal hinge) | Board on the top half; a big mood controller on the bottom |
| Tent | Board only, as a little stage for showing off a solve |

Hinge APIs (`onHingeChange`, `reservedRegions`) are compiled only with the iOS 27.1+ SDK
(`MOODMAGNETS_DUO_SDK`); without them the layout follows window size. The in-game
**Layout** menu forces any posture on any device, so testers without a Duo can try them.

## Building

```sh
brew install xcodegen
cd MoodMagnets && xcodegen generate && open MoodMagnets.xcodeproj
scripts/ci.sh   # build + unit tests on a simulator
```

Launch arguments: `-MMStartLevel N`, `-MMUnlockAll`, `-MMResetProgress`, `-MMAutoSolve`
(plays the stored solution), `-MMPostureOverride closed|book|laptop|tent`.

## Designing levels

Levels live in `tools/levels_src.py`, which writes `MoodMagnets/Resources/levels.json`.
`tools/sim.py` mirrors `Core/Simulation.swift` step for step, so you can tune in Python:

```sh
cd tools
python3 levels_src.py                                   # regenerate levels.json
python3 solve.py ../MoodMagnets/Resources/levels.json   # idle check, stored solution, exhaustive min-moves search
```

## CI / TestFlight

- **GitHub Actions** (`.github/workflows/moodmagnets-ios.yml`): on every push touching
  `MoodMagnets/**` — build, unit tests, screenshots on a macOS runner.
- **Codemagic** (`moodmagnets-testflight` in the repo-root `codemagic.yaml`): XcodeGen →
  signing with the shared persistent `CERTIFICATE_PRIVATE_KEY` → IPA → upload to
  TestFlight. Needs the App Store Connect app record for `com.tinybirdbigdreams.moodmagnets`.
