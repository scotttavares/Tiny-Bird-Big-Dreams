/**
 * Lull — interactive app landing (in-browser breathing web app) + privacy policy
 * Serves:  /          → app landing with a live breathing exercise (the web version)
 *          /privacy   → privacy policy   (use this as the App Store Privacy Policy URL)
 * Tiny Bird, Big Dreams · deploy to lull.tinybirdbigdreams.com
 */
const EFFECTIVE = "June 24, 2026";

const SHELL = (title, body) => `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"/>
<title>${title}</title>
<meta name="description" content="Lull — a minute to breathe. One glowing sphere that paces your breath. No account, no streaks, fully offline. Try the web version, free."/>
<meta name="color-scheme" content="dark"/>
<meta name="theme-color" content="#0a0613"/>
<meta name="apple-mobile-web-app-capable" content="yes"/>
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent"/>
<meta name="apple-mobile-web-app-title" content="Lull"/>
<meta property="og:title" content="Lull — a minute to breathe"/>
<meta property="og:description" content="A pocket of calm whenever you need one. Try the breathing web app, free — no account, fully offline."/>
<meta property="og:type" content="website"/>
<meta property="og:url" content="https://lull.tinybirdbigdreams.com/"/>
<style>
:root{ --bg0:#1c1133; --bg1:#0a0613; --bg2:#070410; --ink:#f3efff; --mut:rgba(243,239,255,.62); --faint:rgba(243,239,255,.4); --lav:#bfa9ff; }
*{box-sizing:border-box}
html,body{margin:0;padding:0}
body{ min-height:100vh; background:radial-gradient(120% 90% at 50% 12%, var(--bg0), var(--bg1) 48%, var(--bg2) 100%); background-attachment:fixed; color:var(--ink); font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif; -webkit-font-smoothing:antialiased; }
.wrap{ max-width:680px; margin:0 auto; padding:40px 26px 96px; }
h1{ font-size:26px; font-weight:600; letter-spacing:-.01em; margin:0 0 6px; }
h2{ font-size:16px; font-weight:600; margin:30px 0 6px; color:var(--ink); }
p{ color:var(--mut); margin:0 0 14px; }
.lead{ color:var(--ink); }
a{ color:var(--lav); text-decoration:none; } a:hover{ text-decoration:underline; }
.card{ background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.08); border-radius:20px; padding:26px 28px; }
.eff{ color:var(--faint); font-size:13px; margin-top:2px; }
.back{ font-size:14px; color:var(--mut); }
footer{ text-align:center; margin-top:48px; color:var(--faint); font-size:13px; }
footer a{ color:var(--mut); }

/* ── landing ── */
.topbar{ display:flex; align-items:center; justify-content:space-between; margin-bottom:36px; }
.word{ font-size:15px; letter-spacing:.42em; text-indent:.42em; font-weight:700; opacity:.92; }
.top-privacy{ font-size:13px; color:var(--mut); }
.hero{ text-align:center; }
.kicker{ text-transform:uppercase; letter-spacing:.32em; text-indent:.32em; font-size:12px; color:var(--lav); margin:0 0 14px; }
.hero-h1{ font-size:clamp(28px,7vw,38px); line-height:1.12; font-weight:700; letter-spacing:-.02em; margin:0 0 16px; color:var(--ink); }
.hero-sub{ max-width:460px; margin:0 auto; color:var(--mut); font-size:16px; }

.breathe{ text-align:center; margin:30px 0 6px; }
.orb-wrap{ position:relative; height:300px; display:flex; align-items:center; justify-content:center; }
.orb-ring{ position:absolute; width:296px; height:296px; border-radius:50%; border:1px solid rgba(183,155,255,.14); }
.orb-ring.r2{ width:230px; height:230px; border-color:rgba(183,155,255,.10); }
.borb{ width:190px; height:190px; border-radius:50%; cursor:pointer; outline:none; -webkit-tap-highlight-color:transparent;
  background:radial-gradient(circle at 38% 32%, #efe6ff 0%, #b79bff 26%, #8a6cf0 52%, #5b3fb0 74%, #2a1c54 100%);
  box-shadow:0 0 80px 14px rgba(150,116,255,.45), inset -10px -12px 30px rgba(20,10,40,.7), inset 8px 8px 22px rgba(255,255,255,.25);
  transition:transform 1.4s ease-in-out; will-change:transform; }
.borb:focus-visible{ box-shadow:0 0 0 3px rgba(191,169,255,.7), 0 0 80px 14px rgba(150,116,255,.45), inset -10px -12px 30px rgba(20,10,40,.7), inset 8px 8px 22px rgba(255,255,255,.25); }
.cue{ font-size:22px; font-weight:600; min-height:28px; }
.cue-sub{ color:var(--mut); font-size:14px; min-height:20px; }
.controls{ display:inline-flex; align-items:center; gap:16px; margin-top:20px; }
.btn-primary{ padding:13px 32px; border-radius:999px; border:none; cursor:pointer; font:inherit; font-weight:600; font-size:15px; color:#1a1030; background:linear-gradient(180deg,#e7deff,#b79bff); box-shadow:0 10px 30px rgba(150,116,255,.4); transition:transform .15s ease, box-shadow .15s ease; }
.btn-primary:hover{ transform:translateY(-1px); box-shadow:0 14px 36px rgba(150,116,255,.5); }
.btn-primary:active{ transform:translateY(0); }
.timer{ color:var(--faint); font-variant-numeric:tabular-nums; font-size:14px; min-width:38px; text-align:left; }
.webapp-note{ margin:22px 0 0; font-size:13px; color:var(--faint); }

.features{ display:grid; gap:12px; margin:40px 0 0; }
.feature{ display:flex; gap:14px; align-items:flex-start; text-align:left; background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.08); border-radius:16px; padding:16px 18px; }
.feature .fi{ font-size:20px; flex-shrink:0; line-height:1.5; }
.feature b{ display:block; font-weight:600; font-size:15px; color:var(--ink); margin-bottom:2px; }
.feature p{ margin:0; font-size:13.5px; }

.appstore{ text-align:center; margin-top:38px; }
.badge{ display:inline-block; padding:11px 22px; border-radius:999px; background:rgba(255,255,255,.07); border:1px solid rgba(255,255,255,.16); font-weight:600; font-size:14px; color:var(--ink); }
.hint{ max-width:420px; margin:14px auto 0; font-size:13px; color:var(--faint); }

@media (max-width:520px){ .orb-wrap{ height:264px; } .borb{ width:162px; height:162px; } .orb-ring{ width:256px; height:256px; } .orb-ring.r2{ width:204px; height:204px; } }
@media (prefers-reduced-motion: reduce){ .borb{ transition:none; } }
</style></head>
<body><div class="wrap">${body}
<footer><div>Lull · a <a href="https://tinybirdbigdreams.com">Tiny Bird, Big Dreams</a> app · <a href="/privacy">Privacy</a></div></footer>
</div></body></html>`;

const LANDING = SHELL("Lull — a minute to breathe", `
<div class="topbar">
  <div class="word">LULL</div>
  <a class="top-privacy" href="/privacy">Privacy</a>
</div>

<section class="hero">
  <p class="kicker">a minute to breathe</p>
  <h1 class="hero-h1">Find your calm in<br/>a single breath.</h1>
  <p class="hero-sub">Lull is one glowing sphere that grows as you breathe in and softens as you breathe out. No noise, no accounts, no pressure — just a pocket of quiet whenever you need one.</p>
</section>

<section class="breathe" aria-label="Breathing exercise">
  <div class="orb-wrap">
    <div class="orb-ring" aria-hidden="true"></div>
    <div class="orb-ring r2" aria-hidden="true"></div>
    <div id="orb" class="borb" role="button" tabindex="0" aria-label="Start or stop the breathing exercise"></div>
  </div>
  <div class="cue" id="cue" aria-live="polite">Ready when you are</div>
  <div class="cue-sub" id="cueSub">tap the orb to begin</div>
  <div class="controls">
    <button id="beginBtn" class="btn-primary" type="button">Begin</button>
    <span class="timer" id="timer">0:00</span>
  </div>
  <p class="webapp-note">This is the web version of Lull, running right here — no install needed.</p>
</section>

<section class="features">
  <div class="feature"><span class="fi" aria-hidden="true">🫧</span><div><b>Just breathe</b><p>Follow the orb. In as it grows, out as it softens. That's the whole app.</p></div></div>
  <div class="feature"><span class="fi" aria-hidden="true">🔒</span><div><b>No account, ever</b><p>Open it and exhale. Nothing to sign up for, nothing to remember.</p></div></div>
  <div class="feature"><span class="fi" aria-hidden="true">✈️</span><div><b>Works fully offline</b><p>On a plane, in a tunnel, mid‑moment. Lull never needs a connection.</p></div></div>
  <div class="feature"><span class="fi" aria-hidden="true">🌙</span><div><b>No streaks, no pressure</b><p>Calm shouldn't be one more thing to keep up with. Come back when you need it.</p></div></div>
</section>

<section class="appstore">
  <span class="badge">📱 Coming soon to the App Store</span>
  <p class="hint">Love it here? Add Lull to your home screen for one‑tap calm until the app lands.</p>
</section>

<script>
(function(){
  var orb=document.getElementById('orb'),
      cue=document.getElementById('cue'),
      sub=document.getElementById('cueSub'),
      btn=document.getElementById('beginBtn'),
      timerEl=document.getElementById('timer'),
      body=document.body;
  if(!orb||!btn) return;
  var phases=[
    {name:'Breathe in', sub:'fill up slowly', dur:4000, scale:1.18},
    {name:'Hold',       sub:'soft and easy',  dur:2000, scale:1.18},
    {name:'Breathe out',sub:'let it all go',  dur:6000, scale:0.6}
  ];
  var running=false, t=null, tick=null, started=0;
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  function rest(){ if(!reduce){ orb.style.transitionDuration='1.4s'; orb.style.transform='scale(0.85)'; } }
  function setPhase(i){
    var p=phases[i];
    cue.textContent=p.name; sub.textContent=p.sub;
    if(!reduce){ orb.style.transitionDuration=(p.dur/1000)+'s'; orb.style.transform='scale('+p.scale+')'; }
    t=setTimeout(function(){ setPhase((i+1)%phases.length); }, p.dur);
  }
  function fmt(s){ var m=Math.floor(s/60), x=s%60; return m+':'+(x<10?'0':'')+x; }
  function start(){
    running=true; started=Date.now();
    btn.textContent='Stop'; body.classList.add('is-breathing');
    setPhase(0);
    tick=setInterval(function(){ timerEl.textContent=fmt(Math.floor((Date.now()-started)/1000)); }, 250);
  }
  function stop(){
    running=false; clearTimeout(t); clearInterval(tick);
    btn.textContent='Begin'; body.classList.remove('is-breathing');
    cue.textContent='Nicely done'; sub.textContent='tap to go again'; timerEl.textContent='0:00'; rest();
  }
  function toggle(){ running ? stop() : start(); }
  btn.addEventListener('click', toggle);
  orb.addEventListener('click', toggle);
  orb.addEventListener('keydown', function(e){ if(e.key===' '||e.key==='Enter'){ e.preventDefault(); toggle(); } });
  rest();
})();
</script>`);

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
<p style="margin-bottom:0">Questions? <a href="https://tinybirdbigdreams.com/#contact">Get in touch through our contact form</a>.</p>
</div>`);

const headers = { "content-type":"text/html; charset=utf-8", "x-content-type-options":"nosniff", "referrer-policy":"no-referrer", "cache-control":"public, max-age=300" };

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
