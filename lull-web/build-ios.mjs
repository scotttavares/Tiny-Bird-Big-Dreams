// Assemble www/ for the Capacitor iOS shell from the built web app in public/.
// A WKWebView needs no service worker (and a stale SW cache would hide app updates),
// so the SW registration is stripped; everything else the app loads is copied as-is.
// Run after build.mjs (which produces public/assets/lull.js).
import { mkdirSync, rmSync, cpSync, readFileSync, writeFileSync, existsSync } from "node:fs";

const pub = "public";
const out = "www";
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

// app.html is the installable app shell; drop the service-worker registration for native.
let html = readFileSync(`${pub}/app.html`, "utf8");
html = html.replace(/\s*<script>\s*if \('serviceWorker' in navigator\)[\s\S]*?<\/script>/, "");
writeFileSync(`${out}/index.html`, html);

// The app bundle + orb/sound image assets.
cpSync(`${pub}/assets`, `${out}/assets`, { recursive: true });

// Icons + manifest referenced by the shell (harmless in a WKWebView, avoids 404s).
for (const f of ["manifest.webmanifest", "icon-192.png", "icon-512.png", "apple-touch-icon.png", "favicon-32.png"]) {
  if (existsSync(`${pub}/${f}`)) cpSync(`${pub}/${f}`, `${out}/${f}`);
}

console.log("assembled -> www/ (index.html + assets + icons)");
