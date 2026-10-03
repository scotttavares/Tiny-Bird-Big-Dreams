---
name: ship-ios-app-codemagic
description: >
  Package a web or Capacitor app and ship it to the Apple App Store using
  Codemagic CI — no Mac required. Use when the user wants to build, sign, and
  submit an iOS app: wrapping a web app in Capacitor, writing codemagic.yaml,
  App Store Connect code signing (distribution certificate + provisioning
  profile from a PERSISTENT private key), generating app icons/splash, going
  universal (iPad), producing exact-size App Store screenshots with a headless
  browser, and the App Store Connect submission checklist. Also covers the
  common Codemagic/Xcode signing errors and their fixes.
---

# Ship an iOS app to the App Store with Codemagic (no Mac)

A field-tested playbook for taking a **web app** (React/Vite/static, or anything
that builds to HTML/JS/CSS) all the way to a **signed, universal iOS app on the
App Store**, building entirely in the cloud on Codemagic. No Mac, no Xcode
locally.

This was distilled from a real ship (the "Lull" breathing app). The ordering and
the gotchas below matter — most of them cost a failed build to discover.

## When to use
- User has a web app (or Capacitor app) and wants it on the iOS App Store.
- User doesn't have a Mac / doesn't want to deal with Xcode + signing locally.
- User hit a Codemagic signing error and needs the known-good configuration.

## The shape of the work
1. Wrap the web app in **Capacitor** (one-time project setup).
2. Add **codemagic.yaml** (the CI recipe).
3. Wire up **App Store Connect signing** (the part everyone gets stuck on).
4. **Icons + splash** from a single 1024px source.
5. Go **universal** (iPhone + iPad) + lock orientation.
6. Make the layout **fit real devices** (verify in a headless browser).
7. Generate **App Store screenshots** at exact sizes.
8. **Submit** in App Store Connect.

You (Claude) usually can't push to the app's repo directly or click the Apple/
Codemagic web UIs — so most steps are: produce the file/value, hand the user a
copy-paste command or precise UI instructions, and verify their pasted output.

---

## 0. Prerequisites (the user does these in web UIs)
- **Apple Developer Program** membership ($99/yr), and the **bundle ID / App ID**
  registered at developer.apple.com → Certificates, Identifiers & Profiles →
  Identifiers (e.g. `com.yourorg.app`).
- An **app record** in App Store Connect (note its numeric **Apple ID**, e.g.
  `6783862542`, shown in App Information).
- A **Codemagic** account with the GitHub repo added as an app.
- A Codemagic **App Store Connect API key** integration:
  ASC → Users and Access → **Integrations** tab → **App Store Connect API** →
  request access if needed → create a key with **App Manager** role → add it in
  Codemagic (Developer Portal / Integrations). **Remember the integration name** —
  it must match `app_store_connect:` in the YAML. (It is NOT auto-named; on
  personal accounts you may not be able to rename it, so read the actual name.)

---

## 1. Wrap the web app in Capacitor

Add these to the repo root. The iOS app loads a static `www/` directory, so the
build just has to assemble `www/` from the web build output.

**`capacitor.config.json`**
```json
{
  "appId": "com.yourorg.app",
  "appName": "YourApp",
  "webDir": "www",
  "backgroundColor": "#0a0613",
  "ios": { "contentInset": "never", "backgroundColor": "#0a0613" }
}
```

**`package.json`** — add Capacitor deps and make `build` also assemble `www/`:
```jsonc
{
  "scripts": { "build": "node build.mjs && node build-ios.mjs" },
  "dependencies": {
    "@capacitor/cli": "^6.0.0",
    "@capacitor/core": "^6.0.0",
    "@capacitor/ios": "^6.0.0"
  }
}
```

**`build-ios.mjs`** — assemble `www/` from your web output (adapt paths). Strip
any service-worker registration: a WKWebView doesn't need it and a stale SW
cache will hide your updates.
```js
import { mkdirSync, rmSync, cpSync, readFileSync, writeFileSync, existsSync } from "node:fs";
const pub = "public", out = "www";
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
let html = readFileSync(`${pub}/app.html`, "utf8");
html = html.replace(/\s*<script>\s*if \('serviceWorker' in navigator\)[\s\S]*?<\/script>/, "");
writeFileSync(`${out}/index.html`, html);
cpSync(`${pub}/assets`, `${out}/assets`, { recursive: true });
for (const f of ["manifest.webmanifest", "icon-512.png"]) if (existsSync(`${pub}/${f}`)) cpSync(`${pub}/${f}`, `${out}/${f}`);
console.log("assembled -> www/");
```

**`.gitignore`**: `node_modules/`, `www/`, `ios/`, `dist/`, `.DS_Store`
(the `ios/` native project is regenerated each CI build with `cap add ios`).

---

## 2. The signing key (do this BEFORE the first build)

> **The single biggest gotcha.** `app-store-connect fetch-signing-files --create`
> creates a distribution certificate, and a certificate is useless without its
> **private key**. If you don't supply one, the build dies with:
> `Cannot save Signing Certificates without certificate private key`.
> Generating a *persistent* key (instead of a throwaway) also means every future
> build reuses the same cert — no churn, no hitting Apple's cert limit.

User runs locally (PowerShell `--%` stops it parsing the args):
```powershell
ssh-keygen --% -t rsa -b 2048 -m PEM -f cert_key -q -N ""
```
(macOS/Linux: `ssh-keygen -t rsa -b 2048 -m PEM -f cert_key -q -N ""`)

Then in Codemagic → the app → **Environment variables**:
- Variable: `CERTIFICATE_PRIVATE_KEY`
- Value: the **entire contents of `cert_key`** (the PEM, `-----BEGIN RSA PRIVATE KEY-----` … include all lines)
- Group: `appstore`  ·  **Secret: checked**

(Personal Codemagic accounts have no "Teams"; use **app-level** env vars. Global/
shared vars are deprecated and read-only.)

---

## 3. codemagic.yaml (known-good template)

Replace `INTEGRATION_NAME`, `APP_APPLE_ID`, `BUNDLE_ID`. This is the version that
shipped — every line earned its place.

```yaml
workflows:
  ios-release:
    name: App iOS release
    instance_type: mac_mini_m2
    max_build_duration: 60

    integrations:
      app_store_connect: "INTEGRATION_NAME"   # MUST match the Codemagic integration name exactly

    environment:
      groups:
        - appstore                            # holds CERTIFICATE_PRIVATE_KEY (secret)
      node: 20
      xcode: latest
      cocoapods: default
      vars:
        APP_APPLE_ID: "0000000000"            # numeric Apple ID from App Store Connect
        BUNDLE_ID: "com.yourorg.app"

    scripts:
      - name: Install npm dependencies
        script: npm install

      - name: Build the web app
        script: npm run build               # must also assemble www/ (build-ios.mjs)

      - name: Add iOS platform and sync
        script: |
          [ -d "ios/App" ] || npx cap add ios
          npx cap sync ios

      - name: Generate app icon + splash from assets/
        script: |
          # USE THE SCOPED PACKAGE. Bare `npx capacitor-assets` resolves to a
          # DEPRECATED package that reads resources/ and has no `generate` cmd —
          # it silently no-ops and you ship the default placeholder icon.
          if [ -f assets/icon.png ]; then
            npx --yes @capacitor/assets@3 generate --ios
          else
            echo "no assets/icon.png — skipping"
          fi

      - name: Configure Info.plist (encryption, portrait, full-screen)
        script: |
          PLIST="ios/App/App/Info.plist"
          # no non-exempt encryption -> skips the App Store export-compliance prompt
          /usr/libexec/PlistBuddy -c "Set :ITSAppUsesNonExemptEncryption NO" "$PLIST" \
            || /usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool NO" "$PLIST"
          # lock to portrait (iPhone + iPad) — drop this block to allow rotation
          for KEY in UISupportedInterfaceOrientations "UISupportedInterfaceOrientations~ipad"; do
            /usr/libexec/PlistBuddy -c "Delete :$KEY" "$PLIST" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c "Add :$KEY array" "$PLIST"
            /usr/libexec/PlistBuddy -c "Add :$KEY:0 string UIInterfaceOrientationPortrait" "$PLIST"
          done
          # full-screen on iPad (no Split View / Slide Over) — required if portrait-locked + universal
          /usr/libexec/PlistBuddy -c "Set :UIRequiresFullScreen YES" "$PLIST" 2>/dev/null \
            || /usr/libexec/PlistBuddy -c "Add :UIRequiresFullScreen bool YES" "$PLIST"

      - name: Set build number (auto-increment from App Store Connect)
        script: |
          LATEST=$(app-store-connect get-latest-build-number "$APP_APPLE_ID" 2>/dev/null || echo "0")
          [ -z "$LATEST" ] && LATEST=0
          cd ios/App
          agvtool new-version -all "$((LATEST + 1))"

      - name: Sign and build the signed IPA
        script: |
          set -e
          # Pin the target's bundle id to match the App ID + profile
          sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" \
            ios/App/App.xcodeproj/project.pbxproj || true
          keychain initialize
          # create (or reuse) the dist cert FROM OUR PERSISTENT KEY, plus the profile
          app-store-connect fetch-signing-files "$BUNDLE_ID" \
            --type IOS_APP_STORE \
            --certificate-key @env:CERTIFICATE_PRIVATE_KEY \
            --create
          keychain add-certificates
          # use-profiles AND build-ipa MUST be in the SAME step (fresh signing state).
          # TARGETED_DEVICE_FAMILY=1 -> iPhone only; 1,2 -> universal (iPhone + iPad).
          xcode-project use-profiles
          xcode-project build-ipa \
            --workspace "ios/App/App.xcworkspace" \
            --scheme "App" \
            --archive-flags "TARGETED_DEVICE_FAMILY=1,2"

    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
      - $HOME/Library/Developer/Xcode/DerivedData/**/Build/**/*.app.dSYM

    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: false   # true to auto-push to TestFlight
        submit_to_app_store: false    # we attach + submit manually in ASC
```

A green run ends with `Archive Succeeded` → `Export Succeeded` →
`UPLOAD SUCCEEDED with no errors`, and the build appears in TestFlight after
~5–15 min of "Processing".

---

## 4. App icon + splash
`@capacitor/assets` needs a **1024×1024** opaque PNG (no alpha — App Store
rejects transparency) at `assets/icon.png`, and optionally a **2732×2732**
`assets/splash.png` for the launch screen. It downscales everything else.

Generate/derive them with Pillow if you only have a smaller source:
```python
from PIL import Image, ImageFilter
im = Image.open("public/icon-512.png").convert("RGB").resize((1024,1024), Image.LANCZOS)
im = im.filter(ImageFilter.UnsharpMask(radius=2.2, percent=70, threshold=2))
im.save("assets/icon.png", "PNG", optimize=True)
```
Single universal 1024 icon is generated (modern asset-catalog format) — that's
correct and App Store-accepted; you do NOT need a dozen separate sizes.

---

## 5. Make the layout fit real devices (verify, don't guess)
Web layouts that lock `body { overflow: hidden }` + `100vh` will **clip controls
below the fold** on short viewports (small iPhones, and the iPad iPhone-compat
window ≈ 375×667) with no way to scroll. Symptoms: "the button is cut off / I
can't scroll to begin."

Fix pattern:
- Let the page scroll when content exceeds the viewport: drop `overflow:hidden`,
  use `overflow-x:hidden; overscroll-behavior:none;` and natural document flow.
- Cap the frame height so large screens center a balanced block instead of
  stretching: `min-height: min(100vh, 820px)`.

**Verify before burning a CI build** — render the built web app in the
pre-installed headless Chromium at the worst-case size and assert the primary
CTA is reachable:
```js
// node, with `playwright` installed; browser at /opt/pw-browsers (see env notes)
import { chromium } from "playwright";
const b = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome" });
const p = await b.newPage({ viewport: { width: 390, height: 667 }, deviceScaleFactor: 2 });
await p.goto("http://localhost:8099/app.html", { waitUntil: "networkidle" });
console.log(await p.evaluate(() => {
  window.scrollTo(0, 99999);
  const btn = [...document.querySelectorAll("button")].find(x => /begin|start/i.test(x.textContent));
  const r = btn.getBoundingClientRect();
  return { scrolled: window.scrollY > 0, reachable: r.bottom <= innerHeight + 1 };
}));
await b.close();
```
(Serve the build dir with `python3 -m http.server 8099`. Install the driver with
`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm i --no-save playwright` and point
`executablePath` at the pre-installed Chromium — do NOT run `playwright install`.)

---

## 6. App Store screenshots (exact pixel sizes)
Apple requires, at minimum: **iPhone 6.7"/6.9"** and **iPad 13"**. Render the app
in headless Chromium with the right viewport × deviceScaleFactor so the PNG comes
out at the exact required pixels:

| Device | viewport (logical) | scale | output pixels | also accepted |
|---|---|---|---|---|
| iPhone 6.7" | 430 × 932 | 3 | **1290 × 2796** | |
| iPad 13" | 1024 × 1366 | 2 | **2048 × 2732** | 2064 × 2752 |

Capture Home + an in-use screen for each. The 6.7"/13" sets satisfy the smaller
slots too (Apple reuses the largest). Drag each set into the matching slot in
ASC → version → Previews and Screenshots.

---

## 7. App Store Connect submission checklist
On the version's **Prepare for Submission** page, the red "Unable to Add for
Review" box lists what's missing. Typical required items:
- **App Information → Content Rights**: usually "does not use third-party content".
- **App Information → Category**: e.g. Health & Fitness (+ optional secondary).
- **Build**: scroll to the **Build** section → **＋** → pick the build (must have
  finished processing). For universal, pick the `1,2` build, not an old iPhone-only one.
- **Screenshots**: iPhone 6.7" + iPad 13" slots filled.
- **Description, Keywords (≤100 chars), Subtitle (≤30), Support URL.**
- **App Privacy**: declare data collection. A fully offline / no-account app =
  "Data Not Collected".
- **Privacy Policy URL** and **Support URL** must be **LIVE** — the reviewer
  visits them; a 404 is a common rejection. Confirm in a real browser.
- **Age Rating** questionnaire (→ usually 4+).
- **Pricing and Availability** (Free / paid, territories).

Then **Add for Review → Submit**. Status flow:
`Waiting for Review → In Review → Pending Developer Release / Ready for Sale`
(or **Rejected** with notes in Resolution Center). Review typically ~24–48h.

---

## Troubleshooting — errors seen and their real fixes

| Symptom in the build log / UI | Cause → Fix |
|---|---|
| `Cannot save Signing Certificates without certificate private key` | `--create` needs a key. Generate a persistent RSA PEM, store as secret `CERTIFICATE_PRIVATE_KEY` in a group, pass `--certificate-key @env:CERTIFICATE_PRIVATE_KEY`. (§2) |
| `No matching profiles found … app_store` | Profile/cert/App ID mismatch, or use-profiles ran in a different step than build. Merge `use-profiles` + `build-ipa` into ONE step; ensure the App ID exists and `BUNDLE_ID` matches. |
| `App requires a provisioning profile` (archive) | Same cause — `use-profiles` and `build-ipa` were split. Put them in one step; `sed` the `PRODUCT_BUNDLE_IDENTIFIER`. |
| `App Store Connect integration '…' does not exist` | `app_store_connect:` value doesn't match the real Codemagic integration name. Read the actual name in Codemagic and copy it verbatim. |
| Icon step prints success but the app ships the **default placeholder** | You used bare `npx capacitor-assets` (deprecated, reads `resources/`, no `generate`). Use `npx --yes @capacitor/assets@3 generate --ios` and an `assets/icon.png` ≥1024. |
| Export-compliance prompt blocks TestFlight/submission | Set `ITSAppUsesNonExemptEncryption NO` in Info.plist during the build (PlistBuddy). |
| App runs as a tiny window on iPad | Built iPhone-only. Set `TARGETED_DEVICE_FAMILY=1,2`; if portrait-locked also set `UIRequiresFullScreen YES`; provide iPad screenshots. |
| "Can't scroll to the Start button" on small screens / iPad compat | `body{overflow:hidden}`+`100vh` clipping. Allow document scroll; cap frame height `min(100vh,820px)`. Verify in headless Chromium. (§5) |
| `git push` "succeeded" but CI builds the old file | The push silently failed on a transient DNS/network error. Always re-check `git status -sb` for `[ahead]` and re-push; confirm `origin/main` == your commit. |
| ASC: "must upload a screenshot for 13-inch iPad" | Universal apps require the iPad 13" set. Upload 2048×2732 (or 2064×2752) to the iPad 13" slot. |

## Notes for multi-account / Windows users
- Pushing to a repo under a second GitHub account: put the username in the URL,
  e.g. `https://USER@github.com/USER/REPO.git`, so the right credential is used.
- When you (Claude) can only access a *different* repo via the GitHub tools,
  deliver repo changes as a **PowerShell script the user pastes locally**:
  rewrite whole files via single-quoted here-strings (`@'…'@`, no `$`
  interpolation) and write with `[IO.File]::WriteAllText(path, ($s -replace "`r`n","`n"))`
  for LF + no BOM. For surgical edits, use literal `String.Replace`, not regex
  `-replace`, and assert the change applied before committing.
