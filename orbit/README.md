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
runners, driven by [`codemagic.yaml`](../codemagic.yaml) **at the repository root**
(Codemagic only reads the config from the repo root; it points back into this
folder via `working_directory: orbit`). You only need an Apple Developer account
and an App Store Connect API key.

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
3. **Add a persistent signing key.** This is the one piece people miss, and it's
   why CI signing "works once then breaks": without it, Codemagic mints a brand-new
   throwaway distribution certificate on every build, quickly hits Apple's cert
   limit, and leaves the keychain with no usable signing identity. Pin one key so
   the *same* certificate is reused forever:
   - Generate a private key (any machine, no Mac needed — Git Bash on Windows has
     `openssl`): `openssl genrsa 2048`
   - Copy the **entire** output, including the `-----BEGIN…-----` / `-----END…-----`
     lines.
   - Codemagic → your app → **Environment variables** → add
     `CERTIFICATE_PRIVATE_KEY` = *(paste)*, tick **Secure**, and save.
4. `codemagic.yaml` (repo root) is already set with `APP_STORE_APPLE_ID` and the
   bundle id — only change them if you use different ones.
5. Start the **`ios-testflight`** workflow. Codemagic will: install deps →
   `expo prebuild` → `pod install` → derive the distribution cert from your
   persistent key + create/fetch the App Store profile → build the IPA → upload to
   TestFlight.

That's it — no local macOS, and no clicking around in the Apple portal creating
certificates or profiles by hand.

> **If a build ever fails with "could not create certificate" / cert-limit
> reached:** you have leftover keyless distribution certificates from earlier
> attempts. Go to the Apple Developer portal → **Certificates**, revoke the old
> **Distribution** cert(s) that *aren't* tied to a key you still have, then re-run.
> The persistent-key setup above means this is a one-time cleanup, not a recurring
> chore.

> **Subfolder note:** Orbit lives in `orbit/` but `codemagic.yaml` sits at the
> **repo root** (Codemagic requires that) and reaches in via
> `working_directory: orbit`. If you later move Orbit to its own repo, that
> `codemagic.yaml` is already at the right place — you can drop `working_directory`.

---

## Project structure

```
codemagic.yaml         iOS CI/CD → TestFlight (at repo ROOT; working_directory: orbit)
orbit/
  App.tsx              App shell: theme, state-driven screen router, tab bar, overlays
  index.ts             Expo entry point
  app.json             Expo config (bundle id, name, etc.)
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
