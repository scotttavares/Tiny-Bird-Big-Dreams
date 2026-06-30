---
name: codemagic-ios-deploy
description: Ship the Orbit iOS app (Expo + React Native, in orbit/) to TestFlight via Codemagic's cloud macOS runners — no Mac or Xcode needed. Use when the user wants to build, sign, deploy, or release the iOS app, set up Codemagic, generate the signing key (CERTIFICATE_PRIVATE_KEY), debug a failed Codemagic build, or get a build green and onto TestFlight.
---

# Ship Orbit to TestFlight with Codemagic (no Mac)

Orbit is an Expo + React Native app in the `orbit/` subfolder. The whole iOS
build → sign → upload runs on Codemagic's macOS cloud. This is the runbook so
it's a seamless, repeatable process.

## Fixed facts for this app

| Thing | Value |
|---|---|
| Codemagic config | `codemagic.yaml` at the **repo root** (Codemagic only reads root) |
| `working_directory` | `orbit` |
| Workflow name | `ios-testflight` |
| Bundle id | `com.tinybirdbigdreams.orbit` |
| App Store numeric Apple ID | `6785966852` |
| Apple Team ID | `23D9BZ3692` |
| ASC API key integration name | `Orbit ASC API key` |
| Signing key env var | `CERTIFICATE_PRIVATE_KEY` (Secure) in group `orbit_signing` |

## One-time setup (Codemagic web UI)

1. **Add the repo** to Codemagic as an application.
2. **App Store Connect API key** — Teams → Integrations → Apple Developer
   Portal → upload the `.p8` (Issuer ID + Key ID). Name the integration exactly
   `Orbit ASC API key` so it matches `integrations.app_store_connect` in
   `codemagic.yaml`.
3. **App record** — in App Store Connect create the app with bundle id
   `com.tinybirdbigdreams.orbit`; its numeric Apple ID is already wired into
   `codemagic.yaml` (`APP_STORE_APPLE_ID`).
4. **`CERTIFICATE_PRIVATE_KEY`** — the one step everyone misses, and the reason
   CI signing "works once then breaks." See the next section.

## Generate `CERTIFICATE_PRIVATE_KEY` (Windows PowerShell)

Why it matters: with no fixed key, Codemagic mints a *throwaway* distribution
certificate every build, hits Apple's cert limit, and the runner ends up with
no usable signing identity → `error: "Orbit" requires a provisioning profile`.
Pinning one private key means the distribution cert is **derived from that key
and identical on every build** — repeatable forever.

`openssl` is **not** on Windows by default, and Windows PowerShell 5.1 can't
export a PEM key either. Use the built-in OpenSSH `ssh-keygen` instead:

```powershell
cd ~
ssh-keygen -t rsa -b 2048 -m PEM -f cert_key
#   Enter passphrase      -> just press Enter
#   Enter same passphrase -> press Enter again (leave it empty)
Get-Content cert_key -Raw | Set-Clipboard
```

- `-m PEM` is required — it writes the classic `-----BEGIN RSA PRIVATE KEY-----`
  PEM that Codemagic understands (not the OpenSSH key format).
- Your clipboard now holds the whole key block. Ignore the `cert_key.pub` file.
- If `Set-Clipboard` is fussy: `notepad cert_key` and copy everything.
- If `ssh-keygen` is "not recognized" (OpenSSH client removed): in an admin
  PowerShell run `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0`,
  then retry.

Then in Codemagic → your app → **Environment variables**:

- Name: `CERTIFICATE_PRIVATE_KEY`
- Value: paste the key
- ✅ **Secure**
- **Group:** `orbit_signing` (the YAML imports this group under
  `environment.groups`; a YAML workflow only sees UI vars whose group is
  imported)

## Before every push — catch failures locally (cheap)

CI's failing step usually reproduces on a laptop with plain Node, so run these
from `orbit/` and only push when they pass:

```bash
cd orbit
npm install              # or: npm ci
npx tsc --noEmit         # types
npx expo export --platform ios   # <-- runs the SAME Metro bundle the
                                  #     Xcode "Bundle React Native code and
                                  #     images" phase runs. Catches missing
                                  #     deps / bad imports that tsc misses.
```

`expo export` is the high-value one: `tsc` and `expo config` never exercise
Metro, so a missing runtime dependency passes type-check yet kills the CI
archive at the bundle phase. If `expo export` prints
`iOS Bundled … index.ts (NNN modules)`, the bundle step will pass on CI.

> Note: `npx expo install …` and `npx expo-doctor` hit Expo's servers, which
> are blocked by the sandbox proxy here (`Host not in allowlist`). Install/pin
> Expo packages with plain `npm install <pkg>@<sdk-version>` instead — read the
> version `expo` itself declares: `node -e "console.log(require('./node_modules/expo/package.json').dependencies)"`.

## Trigger a build

Codemagic → **Start new build** → **Select branch:** the active dev branch
(e.g. `claude/practical-bell-28orha`) → **workflow:** `ios-testflight` → start.

- The workflow dropdown must show `ios-testflight`. If it says
  **"codemagic.yaml not found"**, you picked a branch that doesn't contain the
  root `codemagic.yaml` (e.g. the PR's *base* branch) — switch to the branch
  that has the commits.
- iOS builds take ~15–25 min: install → `expo prebuild` → `pod install` →
  signing → archive → upload to TestFlight.

## Troubleshooting (failures we've actually hit)

| Symptom in the log | Cause | Fix |
|---|---|---|
| `"Orbit" requires a provisioning profile` (exit 65 at archive) | No usable signing identity — `CERTIFICATE_PRIVATE_KEY` missing, or an orphaned keyless cert was reused | Ensure `CERTIFICATE_PRIVATE_KEY` is set (Secure, group `orbit_signing`); re-run |
| `❌ CERTIFICATE_PRIVATE_KEY is not set` | Build started before the env var was saved | Save the var, start a fresh build |
| `could not create certificate` / cert limit reached | Leftover keyless distribution certs fill Apple's limit | Apple Developer → Certificates → revoke old **Distribution** certs you don't hold the key for (safe; doesn't unpublish shipped apps), re-run |
| `Bundle React Native code and images … exited with status code 65` + `The required package 'X' cannot be found` | A runtime dep is missing from `package.json`/lockfile (e.g. `expo-asset`, `expo-constants`, `expo-file-system`, `expo-keep-awake`) | `cd orbit && npm install X@<sdk-version>`, verify with `npx expo export --platform ios`, commit `package.json` + `package-lock.json` |
| `codemagic.yaml not found` in the build dialog | Wrong branch selected | Pick the branch holding the root `codemagic.yaml` |
| `integration 'Orbit ASC API key' does not exist` | API key integration missing/misnamed | Add it in Teams → Integrations with that exact name |

## After the first green build

Deployment is handled autonomously per `CLAUDE.md`: un-draft the PR, squash
merge it; the Cloudflare web deploy is separate (GitHub Actions on `main`) and
unrelated to this iOS pipeline. The signing setup here is already repeatable —
no need to switch to a "stored certificate"; the persistent
`CERTIFICATE_PRIVATE_KEY` *is* the stored identity.
