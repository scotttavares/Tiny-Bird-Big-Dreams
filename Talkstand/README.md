# Talkstand

A teleprompter and selfie stand for the iPhone Duo. Half-fold the phone on a table: your
script scrolls on the upright top half, just under the front camera, while the flat bottom
half shows the preview and the record button. A vlog or video message takes one take.

On any other iPhone (or the Duo lying flat) the script and the preview stack on one screen.

## Build

Needs a Mac with Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd Talkstand
xcodegen generate
open Talkstand.xcodeproj
```

`scripts/ci.sh` builds with a zero-warnings check and runs the tests; GitHub Actions runs it
on every `claude/**` push that touches `Talkstand/`. The iPhone Duo fold code compiles only
with the iOS 27.1 SDK (`TALKSTAND_DUO_SDK`).

## Layout

| Folder | What's in it |
|---|---|
| `Scripts/` | The `Script` model and `ScriptStore` (one JSON file on the device) |
| `Prompter/` | `PrompterEngine` (reading position, pace, back-one-line, stumble marks) and the scrolling view |
| `Stand/` | `StandLayout`: split at the fold in stand mode, stacked otherwise |
| `Camera/` | Capture session, front/back switch, movie recording, preview |
| `Screens/` | Script list, editor, record (stand mode) and take review |

## Status and next steps

1.0 decisions (2026-11-02): script on the top half; free plus a one-time Pro; front and back
camera; Duo first with a stacked fallback on every iPhone.

Built so far: scripts, steady auto-scroll with speed and text size, 3-second countdown,
back-one-line with stumble marks, front/back camera, recording, review and share.

Still to do:
- **Back camera on the Duo.** The Duo's back camera faces away from the inner screen, so
  filming yourself with it means turning the phone round and reading the outer display.
  Untested on a device; the stacked layout is used there for now.
- **Pro (StoreKit, one-time):** scroll that follows your voice (on-device speech), automatic
  stumble removal using the marks `PrompterEngine` already records, unlimited scripts,
  mirror mode.
- App icon, App Store Connect record, bundle id, Codemagic TestFlight workflow, iPhone Duo
  screenshots.
