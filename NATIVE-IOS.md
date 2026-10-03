# Shipping Lull to the iOS App Store (Codemagic, no Mac)

The web app in `lull-web/` is wrapped as a native iOS app with **Capacitor** and
built + signed in the cloud on **Codemagic**. The repo already contains
everything code-side:

- `lull-web/capacitor.config.json` — app id `com.tinybirdbigdreams.lull`, name **Lull**
- `lull-web/build-ios.mjs` — assembles `www/` from the built web app (`npm run build:ios`)
- `lull-web/assets/icon.png` (1024²) + `lull-web/assets/splash.png` (2732²) — app icon & launch screen
- `codemagic.yaml` — the CI recipe (runs in `lull-web/`)

The `ios/` native project and `www/` are **regenerated every build** (gitignored).

---

## What only you can do (web UIs + one local command)

### 1. Apple Developer Program
- Enroll ($99/yr) at developer.apple.com.
- Certificates, Identifiers & Profiles → **Identifiers** → register an App ID with
  bundle ID **`com.tinybirdbigdreams.lull`** (must match `BUNDLE_ID` in `codemagic.yaml`).

### 2. App Store Connect app record
- appstoreconnect.apple.com → **My Apps → ＋ → New App** (platform iOS, the bundle ID above).
- Open the app → **App Information** → note the numeric **Apple ID** (e.g. `6xxxxxxxxx`).
- Put that number in `codemagic.yaml` → `environment.vars.APP_APPLE_ID`.

### 3. Codemagic project
- codemagic.io → add this GitHub repo as an app.
- **App Store Connect API key integration:** ASC → Users and Access → **Integrations**
  → App Store Connect API → create a key with **App Manager** role → add it in
  Codemagic. **Copy the integration name exactly** and put it in `codemagic.yaml`
  → `integrations.app_store_connect` (it is not auto-named; read the real name).

### 4. The signing key (do this BEFORE the first build)
Generate a **persistent** RSA private key locally:

```bash
# macOS / Linux:
ssh-keygen -t rsa -b 2048 -m PEM -f cert_key -q -N ""
# Windows PowerShell (the --% stops it parsing the args):
ssh-keygen --% -t rsa -b 2048 -m PEM -f cert_key -q -N ""
```

In Codemagic → the app → **Environment variables**, add:
- **Name:** `CERTIFICATE_PRIVATE_KEY`
- **Value:** the entire contents of `cert_key` (the whole PEM, `-----BEGIN RSA PRIVATE KEY-----` … end)
- **Group:** `appstore`  ·  **Secret:** ✅

> Without this key the build dies with
> `Cannot save Signing Certificates without certificate private key`.
> A persistent key means every build reuses the same distribution cert (no churn).

### 5. Run the build
Trigger the **Lull iOS release** workflow in Codemagic. A green run ends with
`Archive Succeeded → Export Succeeded → UPLOAD SUCCEEDED`, and the build shows up
in TestFlight after ~5–15 min of processing.

---

## App Store submission checklist (in App Store Connect)
- **Build:** version → Build section → ＋ → pick the processed build.
- **Screenshots:** iPhone 6.7″ (1290×2796) + iPad 13″ (2048×2732). *(Ask Claude to
  generate these from the app — headless capture at exact sizes.)*
- **Privacy Policy URL:** `https://lull.tinybirdbigdreams.com/privacy` (already live).
- **Support URL:** `https://www.tinybirdbigdreams.com`.
- **App Privacy:** **Data Not Collected** — Lull is fully offline, no account; all
  history/mood data stays on the device (and is exportable/erasable in-app).
- **Category:** Health & Fitness.
- **Age Rating:** 4+.  ·  **Content Rights:** does not use third-party content.
- **Pricing:** Free (in-app purchases for orb/sound packs come later, once wired to StoreKit).

Then **Add for Review → Submit**. Review is typically ~24–48h.

---

## What this unlocks (buildable once native)
Reliable daily reminders, Apple Health "Mindful Minutes", a Home/Lock-Screen
widget, Apple Watch, and real App Store purchases — none of which the web/PWA can
do. Ask Claude to add each once the app is live.
