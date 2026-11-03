# Paper Wars

A two-player pencil war on notebook paper, for the iPhone Duo. Stand the phone up as a tent
between two players: each one sees only their own half of the page.

The app is a thin SwiftUI shell around the game page, `PaperWars/Resources/game.html`, which
is the same game that runs on the website at `/play/paperwars/`. Its source is the prototype
(`paper-war/paper-war-prototype.html`, outside this repo); `paper-war/publish-web.py` copies it
here with the fonts embedded, so the app works fully offline.

The shell does three things:

- **Fold**: reads the Duo's hinge (`Shared/Posture*.swift`, shared with Field Guide) and tells
  the page its posture through `window.paperWarsNative.setPosture(...)`.
- **iCloud saves**: every `localStorage` key starting with `paperWars` (settings, inks, stats,
  medals) is mirrored to the player's own iCloud key-value store and to UserDefaults
  (`Shared/CloudSaves.swift`, `App/GameBridge.swift`). On launch the saved values are put
  back before the page starts. Nothing is sent to any server.
- **Full screen**: no status bar, no bounce, no zoom.

## Setup

Requirements: macOS with Xcode 26 or newer (27.1+ for the iPhone Duo APIs) and XcodeGen.

```sh
cd PaperWars
xcodegen generate
open PaperWars.xcodeproj
```

Launch argument `-PWPostureOverride tent` forces tent mode on any simulator.

## Build and verify

`scripts/ci.sh` generates the project, builds with a zero-warnings check and runs the unit
tests (`PaperWarsTests/`). `.github/workflows/paperwars-ios.yml` runs it on every push that
touches `PaperWars/`.
