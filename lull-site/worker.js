/**
 * Lull — landing + privacy policy
 * Serves:  /          → landing page
 *          /privacy   → privacy policy   (use this as the App Store Privacy Policy URL)
 * Tiny Bird, Big Dreams · deploy to lull.tinybirdbigdreams.com
 */
const EFFECTIVE = "June 24, 2026";
const CONTACT = "tavares.scott@gmail.com";

const SHELL = (title, body) => `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>${title}</title>
<meta name="color-scheme" content="dark"/>
<style>
:root{ --bg0:#1c1133; --bg1:#0a0613; --bg2:#070410; --ink:#f3efff; --mut:rgba(243,239,255,.62); --faint:rgba(243,239,255,.4); }
*{box-sizing:border-box}
html,body{margin:0;padding:0}
body{ min-height:100vh; background:radial-gradient(120% 90% at 50% 12%, var(--bg0), var(--bg1) 48%, var(--bg2) 100%); color:var(--ink); font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif; -webkit-font-smoothing:antialiased; }
.wrap{ max-width:680px; margin:0 auto; padding:64px 26px 96px; }
.brand{ text-align:center; margin-bottom:40px; }
.orb{ width:96px; height:96px; margin:0 auto 22px; border-radius:50%;
  background:radial-gradient(circle at 38% 32%, #efe6ff 0%, #b79bff 26%, #8a6cf0 52%, #5b3fb0 74%, #2a1c54 100%);
  box-shadow:0 0 60px 8px rgba(150,116,255,.45), inset -8px -10px 26px rgba(20,10,40,.7), inset 6px 6px 18px rgba(255,255,255,.25); }
.word{ font-size:15px; letter-spacing:.42em; text-indent:.42em; font-weight:600; opacity:.9; }
.tag{ color:var(--mut); margin-top:8px; font-size:15px; }
h1{ font-size:26px; font-weight:600; letter-spacing:-.01em; margin:0 0 6px; }
h2{ font-size:16px; font-weight:600; margin:30px 0 6px; color:var(--ink); }
p{ color:var(--mut); margin:0 0 14px; }
.lead{ color:var(--ink); }
a{ color:#bfa9ff; text-decoration:none; } a:hover{ text-decoration:underline; }
.card{ background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.08); border-radius:20px; padding:26px 28px; }
.eff{ color:var(--faint); font-size:13px; margin-top:2px; }
.cta{ display:inline-block; margin-top:18px; padding:12px 22px; border-radius:999px; background:rgba(255,255,255,.09); border:1px solid rgba(255,255,255,.2); color:var(--ink); font-weight:500; }
footer{ text-align:center; margin-top:48px; color:var(--faint); font-size:13px; }
footer a{ color:var(--mut); }
.back{ font-size:14px; color:var(--mut); }
</style></head>
<body><div class="wrap">${body}
<footer><div>Lull · a <a href="https://tinybirdbigdreams.com">Tiny Bird, Big Dreams</a> app</div></footer>
</div></body></html>`;

const LANDING = SHELL("Lull — a minute to breathe", `
<div class="brand">
  <div class="orb" aria-hidden="true"></div>
  <div class="word">LULL</div>
  <div class="tag">a minute to breathe.</div>
</div>
<div class="card">
  <p class="lead">One glowing sphere that grows as you breathe in and softens as you breathe out. A breath when you need it, a slow wind‑down at night. No account, no streaks, fully offline.</p>
  <p style="margin-bottom:0">Coming soon to the App Store.</p>
  <a class="cta" href="/privacy">Privacy</a>
</div>`);

const PRIVACY = SHELL("Lull — Privacy Policy", `
<p class="back"><a href="/">← Lull</a></p>
<h1>Privacy Policy</h1>
<p class="eff">Effective ${EFFECTIVE}</p>
<div class="card" style="margin-top:22px">
<p class="lead">Lull is made by Scott Tavares under the studio Tiny Bird, Big Dreams. This policy explains how Lull handles your information. The short version: it doesn’t collect any.</p>
<h2>No data collected</h2>
<p>Lull does not collect, store, transmit, or sell any personal information. There are no accounts, logins, or profiles.</p>
<h2>Works offline</h2>
<p>Lull runs entirely on your device. It makes no network connections, so nothing you do in the app ever leaves your phone.</p>
<h2>No tracking or analytics</h2>
<p>Lull contains no analytics, advertising, tracking technologies, or third‑party SDKs. Your breathing sessions, settings, and usage are never recorded or shared.</p>
<h2>No third parties</h2>
<p>Because Lull collects nothing, there is no data to share with anyone.</p>
<h2>Children’s privacy</h2>
<p>Lull is rated 4+ and is safe for all ages. It does not knowingly collect information from anyone, including children under 13.</p>
<h2>Purchases</h2>
<p>Lull is currently free with no in‑app purchases. If a future version offers an optional purchase, the transaction is handled entirely by Apple under Apple’s own privacy policy; Lull never receives your payment details.</p>
<h2>The App Store</h2>
<p>When you download Lull, Apple processes that download under Apple’s privacy policy, which is outside our control.</p>
<h2>Changes</h2>
<p>If Lull’s data practices ever change, this page will be updated with a new effective date.</p>
<h2>Contact</h2>
<p style="margin-bottom:0">Questions? Email <a href="mailto:${CONTACT}">${CONTACT}</a>.</p>
</div>`);

const headers = { "content-type":"text/html; charset=utf-8", "x-content-type-options":"nosniff", "referrer-policy":"no-referrer", "cache-control":"public, max-age=3600" };

export default {
  fetch(req) {
    const { pathname } = new URL(req.url);
    if (pathname === "/privacy" || pathname === "/privacy.html" || pathname === "/privacy/")
      return new Response(PRIVACY, { headers });
    if (pathname === "/" || pathname === "/index.html")
      return new Response(LANDING, { headers });
    return new Response(LANDING, { status: 404, headers });
  }
};
