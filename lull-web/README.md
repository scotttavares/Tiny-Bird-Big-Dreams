# Lull — site + installable web app

Landing page **and** the real Lull app, served from one Cloudflare Worker with
static assets. Deploys to **https://lull.tinybirdbigdreams.com/**.

## Routes
- `/`         → marketing landing page (sells the app, links to the app)
- `/app`      → the **real Lull web app** (installable PWA, works offline)
- `/privacy`  → privacy policy
- `/manifest.webmanifest`, `/sw.js`, icons → PWA assets

## What's inside
```
public/                 # everything served statically
  index.html            # landing page
  app.html              # web-app shell (loads /assets/lull.js)
  privacy.html          # privacy policy
  assets/lull.js        # PREBUILT bundle of the real React app (self-contained)
  manifest.webmanifest  # PWA manifest (start_url = /app)
  sw.js                 # service worker (offline)
  icon-192/512, apple-touch-icon, favicon-32
src/
  Lull.jsx              # app source (single-file React component)
  entry.jsx             # mounts <Lull/> into #root
build.mjs               # esbuild bundle -> public/assets/lull.js
worker.js               # tiny router: serves assets + security headers + SPA fallback
wrangler.toml           # name=lull-site, assets binding, custom domain
```

## Deploy
The app bundle is **already built** (`public/assets/lull.js`), so the fast path is:

```bash
npx wrangler deploy
```

Full reproducible path (rebuilds the app from source first):

```bash
npm install
npm run deploy        # = npm run build && wrangler deploy
```

Local preview: `npm run dev` (then open the printed localhost URL).

## Notes
- **Custom domain** `lull.tinybirdbigdreams.com` is already attached to the
  `lull-site` Worker. If wrangler says the custom domain already exists, that's
  expected — leave it.
- Requires **Wrangler v3.90+** (v4 recommended) for static-assets + `run_worker_first`.
- This **replaces** the previous `lull-site` Worker (same name) — the privacy
  page and domain carry over.
- **To update the app:** edit `src/Lull.jsx`, run `npm run build`, redeploy.
  (Keep `src/Lull.jsx` in sync with your Capacitor app's source.)
- Fully private: no analytics, no third-party requests, no cookies.
