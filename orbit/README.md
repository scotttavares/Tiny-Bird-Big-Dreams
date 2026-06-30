# Orbit

A calm relationship-keeper. Your people orbit you; they drift outward the longer
it's been since you connected, and small gestures pull them back. No guilt, no red
dots — just gentle gravity.

Built with **Expo + React Native + TypeScript**, and set up to ship to the App
Store via **Codemagic** — no Mac or Xcode required.

---

## Run it locally (optional, needs a phone)

```bash
cd orbit
npm install
npx expo start          # scan the QR code with the Expo Go app, or press i / a
```

`npm run typecheck` runs `tsc --noEmit`.

> The native `ios/` and `android/` folders are **not** committed — they're
> generated on demand by `npx expo prebuild`. Codemagic does this in CI.

---

## Ship to TestFlight with Codemagic (no Mac needed)

The whole iOS build, signing, and upload happens on Codemagic's macOS cloud
runners, driven by [`codemagic.yaml`](./codemagic.yaml). You only need an Apple
Developer account and an App Store Connect API key.

### 1. App Store Connect API key (this is what replaces Xcode signing)
1. [App Store Connect](https://appstoreconnect.apple.com) → **Users and Access →
   Integrations → App Store Connect API** → generate a key with **App Manager**
   access.
2. Download the `.p8` file and note the **Issuer ID** and **Key ID**.

### 2. Create the app record
- App Store Connect → **Apps → +** → New App.
- Bundle ID: **`com.tinybirdbigdreams.orbit`** (must match `app.json` →
  `ios.bundleIdentifier`). Register it under **Certificates, IDs & Profiles** if
  it isn't there yet.
- Open the new app → **App Information** → copy the numeric **Apple ID**.

### 3. Codemagic setup
1. [codemagic.io](https://codemagic.io) → add this repository as an application.
2. **Teams → Integrations → Apple Developer Portal** → add the App Store Connect
   API key (Issuer ID + Key ID + `.p8`). **Name it `Orbit ASC API key`** so it
   matches the `app_store_connect:` line in `codemagic.yaml` (or rename both).
3. Edit `codemagic.yaml`:
   - set `APP_STORE_APPLE_ID` to the numeric Apple ID from step 2.
   - change the bundle id everywhere if you used a different one.
4. Start the **`ios-testflight`** workflow. Codemagic will: install deps →
   `expo prebuild` → `pod install` → fetch signing files from your API key →
   build the IPA → upload to TestFlight.

That's it — no local macOS, no manual certificates/profiles.

> **Subfolder note:** Orbit lives in `orbit/` inside this repo, so the workflow
> sets `working_directory: orbit`. If you later move Orbit to its own repo, drop
> `working_directory` and put `codemagic.yaml` at that repo's root.

---

## Project structure

```
orbit/
  App.tsx              App shell: theme, state-driven screen router, tab bar, overlays
  index.ts             Expo entry point
  app.json             Expo config (bundle id, name, etc.)
  codemagic.yaml       iOS CI/CD → TestFlight
  src/
    theme.ts           Dark/light palettes (ported from the prototype's CSS vars)
    types.ts           Contact, Group, Screen types
    orbit.ts           radius()/ringDur() math, orbit names, group colors
    data.ts            Seed contacts
    store.ts           Zustand store: contacts, theme, navigation, all actions
    ui/
      Avatar.tsx       Photo avatar with initials fallback + drift/fav indicators
      TabBar.tsx       Bottom tab bar
      Sheet.tsx        Reusable bottom-sheet modal
      Toast.tsx        Transient toast
      OrbitLogo.tsx    The "O" wordmark logo (revolving planet)
    screens/
      OrbitScreen.tsx  The orbital map (revolving contacts, pinch/pan zoom)
      OrbitMap.tsx     The gravity field component
      TodayScreen.tsx  Daily ritual: one gentle nudge + at-a-glance + prompts
      PeopleScreen.tsx Searchable, grouped list
      ContactScreen.tsx Profile + quiet check-ins + recent gravity
      SettingsScreen.tsx Gravity mechanics, notifications, appearance, data
      Onboarding.tsx   First-run intro
      AddSheet.tsx     Add someone to your orbit
      ActionSheet.tsx  Per-contact options (favorite, anchor, move, drift speed…)
```

## Status / roadmap

Ported from the HTML prototype:
- ✅ Orbit map: revolving contacts on dynamic rings, pinch / pan / zoom, tap to open
- ✅ Today (daily nudge + glance), People (search + groups), Contact, Settings
- ✅ Onboarding, Add-to-orbit, per-contact options, live drift, theming

Next (native-only, intentionally deferred):
- ⏳ **Home-screen widget** — a real WidgetKit extension (Swift) wired via an Expo
  config plugin. The in-app widget *preview* from the prototype can come along too.
- ⏳ Push notifications for the weekly "gravity report"
- ⏳ Contacts import, Claude-powered openers / "catch me up", iCloud sync
