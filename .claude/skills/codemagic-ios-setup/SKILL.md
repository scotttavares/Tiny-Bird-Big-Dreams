---
name: codemagic-ios-setup
description: >-
  Set up Codemagic CI/CD to build, sign, and ship ANY iOS app to TestFlight from
  the cloud — no Mac or Xcode needed. Covers Expo/React Native AND Capacitor
  (Vite/web) apps. Use when starting a new app's mobile pipeline, writing a
  codemagic.yaml from scratch, generating the persistent signing key
  (CERTIFICATE_PRIVATE_KEY), reusing an App Store Connect API key across apps, or
  debugging a failed Codemagic iOS build. For an app that already has its own
  per-app deploy skill/runbook, prefer that; use this to bootstrap a new one.
---

# Set up Codemagic → TestFlight for an iOS app (no Mac)

This is the studio playbook for standing up Codemagic CI on a **new** iOS app.
It builds → signs → uploads to TestFlight on Codemagic's macOS cloud. Two app
shapes are covered; detect which one you have, then use its template.

- **Expo / React Native** — has `app.json`/`app.config.*` and `expo` in
  `package.json`. Native project is generated at build time (`expo prebuild`).
- **Capacitor** (web app → native) — has `capacitor.config.*` and an `ios/`
  folder. You build the web bundle, then `npx cap sync ios`.

## Universal one-time setup (Codemagic web UI) — same for both stacks

1. **Add the repo** to Codemagic (Applications → GitHub → the repo → project
   type iOS/Other; the `codemagic.yaml` drives everything regardless of type).
   If the repo isn't listed, add it to the Codemagic GitHub App's allowed repos.
2. **App Store Connect API key** — Teams → Integrations → Apple Developer Portal:
   upload the `.p8` (Issuer ID + Key ID). **One ASC API key works for the whole
   account — reuse it across all your apps.** Name the integration and match it
   in `codemagic.yaml` (`integrations.app_store_connect: <NAME>`).
3. **App record** — in App Store Connect create the app with your bundle id, then
   copy its numeric **Apple ID** (App Information → General → "Apple ID", also the
   number in the app's URL `…/apps/<APPLE_ID>/…`) into `APP_STORE_APPLE_ID`.
4. **Persistent signing key** (the step everyone misses — see next section).

## The persistent signing key (CERTIFICATE_PRIVATE_KEY)

Without a fixed key, Codemagic mints a throwaway distribution cert every build,
hits Apple's cert limit, and signing breaks. Pin ONE private key → the
distribution cert is derived from it and is identical on every build.

```bash
openssl genrsa 2048            # macOS/Linux
# Windows PowerShell (no openssl):  ssh-keygen -t rsa -b 2048 -m PEM -f cert_key
```
`-m PEM` on ssh-keygen is required (classic `-----BEGIN RSA PRIVATE KEY-----`).
**The same key can be reused across every app on the same Apple Team** — they'll
share one distribution cert. Paste the whole block into a Codemagic env var:
- Name: `CERTIFICATE_PRIVATE_KEY` · ✅ **Secure** · **Group:** `<app>_signing`
  (a workflow only sees UI vars whose group it imports under `environment.groups`).

## Template — Expo / React Native

```yaml
workflows:
  ios-testflight:
    name: <App> iOS → TestFlight
    max_build_duration: 90
    instance_type: mac_mini_m2
    working_directory: <subdir-or-.>        # e.g. the app subfolder
    integrations:
      app_store_connect: <ASC INTEGRATION NAME>
    environment:
      groups: [<app>_signing]
      vars:
        BUNDLE_ID: "<com.you.app>"
        XCODE_WORKSPACE: "ios/<App>.xcworkspace"
        XCODE_SCHEME: "<App>"
        APP_STORE_APPLE_ID: <numeric-apple-id>
      node: 20
      xcode: latest                          # must match Apple's required SDK
      cocoapods: default
    scripts:
      - name: Install JS dependencies
        script: npm ci
      - name: Generate native iOS project (Expo prebuild)
        script: npx expo prebuild --platform ios --clean --no-install
      - name: Install CocoaPods dependencies
        script: cd ios && pod install
      - name: Increment build number
        script: |
          cd ios
          LATEST=$(app-store-connect get-latest-testflight-build-number "$APP_STORE_APPLE_ID" 2>/dev/null || echo "0")
          agvtool new-version -all $(($LATEST + 1))
      - name: Set up code signing
        script: |
          set -e
          [ -n "$CERTIFICATE_PRIVATE_KEY" ] || { echo "❌ CERTIFICATE_PRIVATE_KEY not set"; exit 1; }
          keychain initialize
          # sign the app (and any extension bundle id, e.g. a widget)
          for id in "$BUNDLE_ID"; do
            app-store-connect fetch-signing-files "$id" --type IOS_APP_STORE \
              --certificate-key @env:CERTIFICATE_PRIVATE_KEY --create
          done
          keychain add-certificates
          xcode-project use-profiles
      - name: Build IPA
        script: xcode-project build-ipa --workspace "$XCODE_WORKSPACE" --scheme "$XCODE_SCHEME"
    artifacts: [build/ios/ipa/*.ipa, /tmp/xcodebuild_logs/*.log, build/ios/**/*.dSYM]
    publishing:
      app_store_connect: { auth: integration }   # upload-only; lands as "Ready to Submit"
```
Expo notes: a home-screen widget/extension is a second bundle id `<BUNDLE_ID>.widget`
— add it to the signing loop and enable its App Group on both App IDs. If you use
`expo-notifications` but only send local notifications, strip `aps-environment`
with a config plugin so signing doesn't demand a push profile.

## Template — Capacitor (Vite / web app)

```yaml
workflows:
  ios-testflight:
    name: <App> iOS → TestFlight
    max_build_duration: 90
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: <ASC INTEGRATION NAME>
    environment:
      groups: [<app>_signing]
      vars:
        BUNDLE_ID: "<com.you.app>"
        XCODE_PROJECT: "ios/App/App.xcodeproj"   # Capacitor: project, not workspace
        XCODE_SCHEME: "App"
        APP_STORE_APPLE_ID: <numeric-apple-id>
      node: 22                                   # Capacitor's CLI needs Node >= 22
      xcode: latest
    scripts:
      - name: Install JS dependencies
        script: npm ci
      - name: Build the web app
        script: npm run build                    # → webDir (e.g. dist/)
      - name: Sync the web build into iOS
        script: npx cap sync ios                 # SPM projects need no pod install
      - name: Set the build number
        script: |
          LATEST=$(app-store-connect get-latest-testflight-build-number "$APP_STORE_APPLE_ID" 2>/dev/null || echo "0")
          # Capacitor Info.plist uses $(CURRENT_PROJECT_VERSION); no agvtool set up, so sed it:
          sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9][0-9]*/CURRENT_PROJECT_VERSION = $(($LATEST + 1))/g" "$XCODE_PROJECT/project.pbxproj"
      - name: Set up code signing
        script: |
          set -e
          [ -n "$CERTIFICATE_PRIVATE_KEY" ] || { echo "❌ CERTIFICATE_PRIVATE_KEY not set"; exit 1; }
          keychain initialize
          app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE \
            --certificate-key @env:CERTIFICATE_PRIVATE_KEY --create
          keychain add-certificates
          xcode-project use-profiles
      - name: Build IPA
        script: xcode-project build-ipa --project "$XCODE_PROJECT" --scheme "$XCODE_SCHEME"
    artifacts: [build/ios/ipa/*.ipa, /tmp/xcodebuild_logs/*.log, build/ios/**/*.dSYM]
    publishing:
      app_store_connect: { auth: integration }
```
Capacitor gotchas that WILL bite:
- **Shared scheme required.** Capacitor doesn't commit one, and CI only sees
  shared schemes. Commit `ios/App/App.xcodeproj/xcshareddata/xcschemes/App.xcscheme`
  (pointed at the `App` target's `BlueprintIdentifier` from `project.pbxproj`).
  You can't add it Mac-free from Xcode — author the XML directly.
- **SPM vs CocoaPods.** If there's a `CapApp-SPM` folder and no `Podfile`, it's
  Swift Package Manager — omit `pod install` and `cocoapods:`.

## Export compliance (both stacks)

If the app only makes standard HTTPS calls, add `ITSAppUsesNonExemptEncryption`
= `false` — Expo: in `app.json` `ios.infoPlist`; Capacitor: in
`ios/App/App/Info.plist`. Stops TestFlight from prompting for encryption docs on
every upload.

## Before every push (cheap local checks)

- Expo: `npm ci && npx tsc --noEmit && npx expo export --platform ios` (the last
  one runs the same Metro bundle the CI archive runs — catches missing deps).
- Capacitor: `npm ci && npm run build && npx cap sync ios` (needs Node ≥ 22).

## Trigger a build & auto-trigger

Codemagic → Start new build → **the branch that contains the root
`codemagic.yaml`** → workflow → **uncheck SSH/VNC** → Start (~10–25 min). If the
dropdown says "codemagic.yaml not found," you picked a branch without it. To
auto-build on push, add `triggering: { events: [push], branch_patterns: [...] }`.

## Troubleshooting (real failures)

| Symptom | Cause → Fix |
|---|---|
| `requires a provisioning profile` (exit 65) | No signing identity → `CERTIFICATE_PRIVATE_KEY` set, Secure, in the imported group; re-run |
| `could not create certificate` / cert limit | Orphan keyless certs → revoke old Distribution certs you don't hold the key for; reuse ONE persistent key |
| `Bundle React Native code and images … status 65` + `package 'X' cannot be found` | Missing runtime dep → `npm install X@<sdk-version>`, verify `npx expo export`, commit lockfile |
| `The Capacitor CLI requires NodeJS >=22` | Node too old → `node: 22` |
| `Scheme <X> not found` (Capacitor) | No shared scheme committed → add the `.xcscheme` |
| Build succeeds but `Validation failed (409) … built with iOS NN SDK` at upload | Xcode too old → `xcode: latest`; if that breaks compile, bump the framework SDK |
| Publishing ❌ (upload succeeded) with export-compliance error | Missing `ITSAppUsesNonExemptEncryption` → set it false |
| `integration '<name>' does not exist` | ASC key integration missing/misnamed → add in Teams → Integrations |

## After a green build

Lands in App Store Connect → TestFlight as "Ready to Submit." For the App Store,
fill the listing (iPhone **6.5" screenshots = 1284 × 2778**, or 6.7" = 1290 × 2796),
App Privacy, age rating, pricing, then submit. Consider a second `ios-release`
workflow with `publishing.app_store_connect.submit_to_app_store: true` +
`release_type: AFTER_APPROVAL` for one-click store submission on future updates.
