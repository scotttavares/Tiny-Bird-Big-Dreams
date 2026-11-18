# Flip Fusion

A number-merging puzzle for iPhone. Swipe to slide and merge matching tiles. After every
second move the board turns a quarter turn clockwise and gravity pulls the tiles down,
which can set off a chain of merges.

- `FlipFusion/Game/` holds the rules (`GameEngine`), with no UI code, and `GameStore`,
  which runs each move as a short animated sequence and saves the game.
- `FlipFusion/UI/` draws the one screen. Colours live in `Theme.swift`.
- `FlipFusionTests/` covers the rules and saving.

## Building

There is no Xcode project in git. It is generated from `project.yml` with XcodeGen:

    brew install xcodegen
    xcodegen generate

Codemagic does this in the `flipfusion-testflight` workflow (see `codemagic.yaml` at the
repo root), runs the unit tests, and uploads the build to TestFlight.

The app icon is drawn by `scripts/make-icon.py` (needs Pillow).
