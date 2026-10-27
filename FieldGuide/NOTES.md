# Field Guide: research notes and assumptions

I built this in a Linux cloud container, where Xcode and simulators aren't available. Every
compile, test and screenshot runs on a GitHub Actions macOS runner
(`.github/workflows/fieldguide-ios.yml` → `scripts/ci.sh`, `scripts/screenshots.sh`).
See "Verification status" at the bottom for what has actually been checked.

## Step 0: what the iPhone Duo SDK offers (researched 2026-10-27)

I couldn't open Apple's documentation site from this environment, so these findings come from
third-party write-ups and open-source sample code built against Xcode 27.1 / iOS 27.1. The
code examples were the most useful source:
[artemnovichkov/iPhone-Duo-by-Examples](https://github.com/artemnovichkov/iPhone-Duo-by-Examples)
and [Codelaby/IphoneDuo](https://github.com/Codelaby/IphoneDuo).

| Need | API found | How Field Guide uses it |
| --- | --- | --- |
| Fold/posture | `View.onHingeChange { old, new in new.hinge }` → `DeviceHinge?` with `angle: Angle` (180° = flat) and `status: .closed / .partiallyOpen / .fullyOpen`. `hinge` is `nil` on devices without a hinge. | `HingeObserver` in `Shared/PostureProvider.swift` feeds `HingeStatus` + angle into `PostureInputs`. |
| Hinge geometry | `GeometryProxy.reservedRegions(kind: .division, options:)` → `[ReservedRegion]` with `frame`, `margins`, `isActive`. Only active while partially folded; `.includeInactive` returns it when flat too. | Active region decides book vs laptop; any region (inactive included) positions the gutter so nothing crosses the fold. |
| Dual-pane layout | `ArrangementView` with `.split` / `.overlay` styles, custom `ArrangementViewStyle`. | Not used. The workspace needs one canvas view whose identity survives every posture change (to keep strokes intact), so it uses its own frame-based layout around the hinge rect. |
| Cover display while unfolded | `sceneAccessory { CameraCaptureAccessory { … } }` | Not used (out of MVP scope). It would be a good fit for showing the sketch to a subject while capturing a reference photo. |
| Vertical toolbars | `toolbarVerticalBehavior`, `axisBehavior`, `visibilityPriority` | Not used. Tools live in the app's own strip, placed per posture. |
| "Tent" posture | **No API found.** Apple's guidance is to lay out by division region, not by angle. | Derived heuristically (below). |
| Closed-state widget | No Duo-specific widget API found. When the Duo is folded, the outer display is the regular iPhone Lock Screen. | Standard WidgetKit Lock Screen + Home Screen widget that deep-links to `fieldguide://new-page`. |

Apple's guidance, as the sources report it: use hinge updates for effects and interactions
and reserved regions for layout, and treat an unrecognised status as fully open.

## Posture mapping (`PostureMapper`, unit-tested)

Everything goes through the `PostureProvider` protocol (`Shared/PostureProvider.swift`). The
default `SystemPostureProvider` applies these rules in order:

1. **Active `.division` region.** If it's wider than tall (horizontal fold), the posture is
   **laptop**, or **tent** if the hinge angle is under 100°. If it's taller than wide, the
   posture is **book**.
2. **Hinge present, no active region.** `.closed` maps to **closed** (the cover display).
   Otherwise the window must be at least 600 pt wide. If it is, the posture is **book**, or
   **laptop** if the inactive fold is horizontal. If it isn't, the posture is **closed**.
3. **No hinge** (any other iPhone/iPad, or an SDK without the API): a window at least
   600 pt wide → **book**, narrower → **closed**.

An override (`-FGPostureOverride closed|book|laptop|tent`, or the in-app *Layout* menu) wins
over everything. The **Present** command forces tent manually. "Return to draw" exits tent
until the posture changes again.

## Assumptions about unavailable or unknown Duo APIs

1. **API availability is `iOS 27.1`.** The sources call these APIs "iOS 27.1". Every call
   is behind `if #available(iOS 27.1, *)`.
2. **SDK gating via a compilation condition.** The minimum deployment target is iOS 26, as
   the brief asked, and the hinge APIs don't exist in older SDKs. They're wrapped in
   `#if FIELDGUIDE_DUO_SDK`. `scripts/ci.sh` turns that on automatically when the simulator
   SDK is 27.1 or newer, so the same sources build with Xcode 26 and Xcode 27.1+.
3. **Exact signatures are from sample code, not Apple's headers.** The calls are
   `onHingeChange(_:)` with `(old, new)` contexts, `DeviceHinge.status/angle`,
   `reservedRegions(kind:options:)`, `.division`, `.includeInactive`, and
   `ReservedRegion.frame`. If Apple's final names differ, only `HingeObserver` and
   `PostureGeometry.init(proxy:)` need to change.
4. **Status comparisons, not a `switch`.** Some sources say the status has an
   "unknown"-style case that Apple suggests treating as fully open. `HingeReading` compares
   against `.closed` / `.partiallyOpen` and treats anything else as fully open, so an extra
   case can't break the build.
5. **Tent is a heuristic.** On an inward-folding device, the closest physical match to a
   tent is a steep, partially opened horizontal fold. I picked the 100° threshold myself;
   it's `PostureMapper.tentMaximumAngle`. The manual **Present** mode is the reliable route.
6. **Closed = cover display.** I assumed the system relaunches or resizes the scene onto the
   cover display when the device folds. SwiftUI sees that as a size change, which is the
   documented behaviour of "folding changes the size of the app's window".
7. **Hinge width.** When the division region is narrower than 24 pt (or missing, as on the
   iPad stand-in), the gutter is drawn 24 pt wide, centred on the fold.
8. **Widget.** No closed-state-specific widget surface was found, so I shipped standard
   Lock Screen (`accessoryCircular`, `accessoryRectangular`) and Home Screen
   (`systemSmall`) widgets. A Control Center control was skipped: it needs an App Intent
   that opens the app, and the API for that changed in iOS 26, so it would risk build
   warnings across SDKs.

## Other decisions made without asking

- **Location in the repo.** The app lives in `FieldGuide/` in this (website) repository,
  because that's the repo this session had. I added `FieldGuide` to `.assetsignore` so the
  Cloudflare static-asset deploy never publishes the Swift sources.
- **Project generation.** XcodeGen (`project.yml`). The `.xcodeproj` is generated and
  ignored by git.
- **Concurrency.** Swift 6 language mode with complete strict concurrency and explicit
  `@MainActor`. I didn't use the newer default-actor-isolation setting, to keep the code
  portable across Xcode 26/27.
- **Fixed page size.** Every canvas is a fixed 800 × 1100 pt page that zooms to fit its
  pane. Strokes therefore keep their coordinates across postures and screens, and zoom is
  stored relative to "fit".
- **Thumbnails** are small JPEGs in SwiftData with `.externalStorage`, so they stay out of
  the main store. Reference images are files under `Application Support/FieldGuide/References`
  with relative paths, as the brief specified.
- **Exports render on light paper** whatever the current appearance, so shared images look
  the same everywhere.
- **Simulator stand-ins** for screenshots when no Duo simulator exists: an iPhone for
  closed, an iPad for book/laptop/tent, with the posture forced by launch argument.
