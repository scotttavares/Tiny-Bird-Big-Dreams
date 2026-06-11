// Tiny Bird Studio — private dashboard gated behind a password.
// Everything except /studio is served straight from static assets.
// On /studio it pulls LIVE metrics from Supabase + Stripe (server-side),
// falling back to a snapshot when a source/secret isn't available.
//
// Secrets (set in Cloudflare → Worker → Settings → Variables and secrets):
//   STUDIO_PASSWORD   – password for the login gate
//   TTBI_SERVICE_KEY  – Supabase service_role key (Tiny Thoughts, Big Ideas)
//   TS_SERVICE_KEY    – Supabase service_role key (tinysuperpowers)
//   STRIPE_KEY        – Stripe restricted, read-only secret key

const SESSION_COOKIE = "tbbd_studio";
const SESSION_TTL = 60 * 60 * 24 * 30; // 30 days, in seconds

const SUPA = {
  ttbi: { url: "https://eljbsalptkzmtavsbebb.supabase.co", keyEnv: "TTBI_SERVICE_KEY" },
  ts: { url: "https://mzggnfnlyxpndbtgegwg.supabase.co", keyEnv: "TS_SERVICE_KEY" },
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const p = url.pathname;

    if (p === "/studio/login" && request.method === "POST") {
      return handleLogin(request, env);
    }
    if (p === "/studio/logout") {
      return handleLogout();
    }
    if (p === "/studio" || p === "/studio/") {
      if (await isAuthed(request, env)) {
        const metrics = await collectMetrics(env);
        return html(dashboardHTML(metrics));
      }
      return html(loginHTML({ error: false, configured: !!env.STUDIO_PASSWORD }), 401);
    }

    // Everything else → the public static site.
    return env.ASSETS.fetch(request);
  },
};

/* ----------------------------- responses ----------------------------- */

function html(body, status = 200, extraHeaders = {}) {
  return new Response(body, {
    status,
    headers: {
      "content-type": "text/html;charset=UTF-8",
      "cache-control": "no-store",
      "x-robots-tag": "noindex, nofollow",
      ...extraHeaders,
    },
  });
}

async function handleLogin(request, env) {
  const pw = env.STUDIO_PASSWORD;
  let attempt = "";
  try {
    const form = await request.formData();
    attempt = form.get("password") || "";
  } catch {
    /* ignore */
  }
  if (!pw || attempt !== pw) {
    return html(loginHTML({ error: true, configured: !!pw }), 401);
  }
  const token = await makeToken(env);
  return new Response(null, {
    status: 303,
    headers: {
      "set-cookie": `${SESSION_COOKIE}=${token}; Path=/studio; HttpOnly; Secure; SameSite=Lax; Max-Age=${SESSION_TTL}`,
      location: "/studio",
    },
  });
}

function handleLogout() {
  return new Response(null, {
    status: 303,
    headers: {
      "set-cookie": `${SESSION_COOKIE}=; Path=/studio; HttpOnly; Secure; SameSite=Lax; Max-Age=0`,
      location: "/studio",
    },
  });
}

/* ----------------------------- auth core ----------------------------- */

async function isAuthed(request, env) {
  if (!env.STUDIO_PASSWORD) return false;
  const cookie = request.headers.get("cookie") || "";
  const m = cookie.match(/(?:^|;\s*)tbbd_studio=([^;]+)/);
  if (!m) return false;
  return verifyToken(m[1], env);
}

// token = base64url(exp) "." hexHmac(exp)
async function makeToken(env) {
  const exp = String(Math.floor(Date.now() / 1000) + SESSION_TTL);
  const sig = await hmacHex(exp, env.STUDIO_PASSWORD);
  return `${b64u(exp)}.${sig}`;
}

async function verifyToken(token, env) {
  const parts = token.split(".");
  if (parts.length !== 2) return false;
  let exp;
  try {
    exp = ub64u(parts[0]);
  } catch {
    return false;
  }
  const expNum = parseInt(exp, 10);
  if (!expNum || expNum < Math.floor(Date.now() / 1000)) return false;
  const sig = await hmacHex(exp, env.STUDIO_PASSWORD);
  return timingSafeEqual(sig, parts[1]);
}

async function hmacHex(message, key) {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const buf = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(message));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

function b64u(s) {
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function ub64u(s) {
  return atob(s.replace(/-/g, "+").replace(/_/g, "/"));
}

/* --------------------------- live metrics ---------------------------- */

// Last-known snapshot — used as a fallback when a live source is missing.
const SNAPSHOT = {
  ttbi: { signups: 1, waitlist: 3, tiers: [{ tier: "byo", users: 1 }] },
  ts: {
    signups: 1,
    downloads_total: 2,
    purchases: 2,
    purchases_revenue_cents: 1500,
    products: [
      { title: "Brain Dump", price_cents: 1500, downloads: 1, revenue_cents: 1500 },
      { title: "Content Blaster", price_cents: 0, downloads: 1, revenue_cents: 0 },
      { title: "Data Analyzer", price_cents: 3900, downloads: 0, revenue_cents: 0 },
      { title: "Presentation Pro", price_cents: 2900, downloads: 0, revenue_cents: 0 },
      { title: "Meeting Memo", price_cents: 2400, downloads: 0, revenue_cents: 0 },
      { title: "Project Planner", price_cents: 1900, downloads: 0, revenue_cents: 0 },
      { title: "Focus Mode", price_cents: 1500, downloads: 0, revenue_cents: 0 },
      { title: "Email Wizard", price_cents: 1200, downloads: 0, revenue_cents: 0 },
    ],
  },
};

async function supaMetrics(cfg, env) {
  const key = env[cfg.keyEnv];
  if (!key) throw new Error("no key");
  const r = await fetch(`${cfg.url}/rest/v1/rpc/studio_metrics`, {
    method: "POST",
    headers: {
      apikey: key,
      authorization: `Bearer ${key}`,
      "content-type": "application/json",
    },
    body: "{}",
  });
  if (!r.ok) throw new Error("supabase " + r.status);
  return r.json();
}

async function stripeRevenue(env) {
  const key = env.STRIPE_KEY;
  if (!key) throw new Error("no key");
  const r = await fetch("https://api.stripe.com/v1/charges?limit=100", {
    headers: { authorization: `Bearer ${key}` },
  });
  if (!r.ok) throw new Error("stripe " + r.status);
  const j = await r.json();
  let cents = 0;
  let count = 0;
  let currency = "usd";
  for (const c of j.data || []) {
    if (c.paid && !c.refunded && c.status === "succeeded") {
      cents += (c.amount || 0) - (c.amount_refunded || 0);
      count += 1;
      currency = c.currency || currency;
    }
  }
  return { cents, count, currency, more: !!j.has_more };
}

async function collectMetrics(env) {
  const [ttbi, ts, stripe] = await Promise.allSettled([
    supaMetrics(SUPA.ttbi, env),
    supaMetrics(SUPA.ts, env),
    stripeRevenue(env),
  ]);

  const ttbiData = ttbi.status === "fulfilled" ? ttbi.value : SNAPSHOT.ttbi;
  const tsData = ts.status === "fulfilled" ? ts.value : SNAPSHOT.ts;
  const stripeData = stripe.status === "fulfilled" ? stripe.value : null;

  return {
    asOf: new Date().toLocaleString("en-US", {
      timeZone: "UTC",
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
    }) + " UTC",
    live: {
      ttbi: ttbi.status === "fulfilled",
      ts: ts.status === "fulfilled",
      stripe: stripe.status === "fulfilled",
    },
    ttbi: ttbiData,
    ts: tsData,
    stripe: stripeData,
  };
}

/* ------------------------------- views ------------------------------- */

const BASE_CSS = `
  *{box-sizing:border-box;margin:0;padding:0}
  :root{--gold:#E8A022;--cream:#FBF7F2;--bg:#0E0A18;--panel:#1A1326;--panel2:#241a33;--muted:rgba(251,247,242,.45)}
  body{font-family:'DM Sans',system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:radial-gradient(1200px 600px at 50% -10%,#241a33 0%,var(--bg) 60%);color:var(--cream);min-height:100vh;-webkit-font-smoothing:antialiased}
  .serif{font-family:'Fraunces',Georgia,serif}
`;

function loginHTML({ error, configured }) {
  return `<!DOCTYPE html><html lang="en"><head>
<meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<meta name="robots" content="noindex,nofollow"/>
<title>Tiny Bird Studio — Sign in</title>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,700;1,9..144,400&family=DM+Sans:wght@300;400;500;600&display=swap" rel="stylesheet"/>
<style>${BASE_CSS}
  .wrap{min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px}
  .card{width:100%;max-width:380px;background:var(--panel);border:1px solid rgba(251,247,242,.08);border-radius:22px;padding:38px 32px;box-shadow:0 30px 80px rgba(0,0,0,.5)}
  .logo{width:46px;height:46px;border-radius:13px;background:linear-gradient(150deg,#F0B83A,#E8A022);display:flex;align-items:center;justify-content:center;font-size:24px;margin-bottom:22px}
  h1{font-size:24px;font-weight:700;letter-spacing:-.02em;margin-bottom:6px}
  .sub{font-size:14px;color:var(--muted);margin-bottom:26px}
  label{display:block;font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--muted);margin-bottom:8px}
  input{width:100%;background:#0f0a1a;border:1px solid rgba(251,247,242,.12);border-radius:12px;padding:14px 16px;color:var(--cream);font-size:15px;outline:none;transition:border-color .2s}
  input:focus{border-color:var(--gold)}
  button{width:100%;margin-top:18px;background:var(--gold);color:#2C1F3E;border:none;border-radius:12px;padding:14px;font-size:15px;font-weight:600;cursor:pointer;transition:background .2s,transform .15s}
  button:hover{background:#f0b030;transform:translateY(-1px)}
  .err{background:rgba(214,77,77,.12);border:1px solid rgba(214,77,77,.4);color:#f0a3a3;font-size:13px;padding:11px 14px;border-radius:10px;margin-bottom:18px}
  .note{font-size:12px;color:var(--muted);margin-top:18px;line-height:1.6}
</style></head>
<body><div class="wrap"><form class="card" method="POST" action="/studio/login">
  <div class="logo">🐤</div>
  <h1 class="serif">Tiny Bird Studio</h1>
  <p class="sub">Private dashboard. Members only.</p>
  ${error ? `<div class="err">Wrong password. Try again.</div>` : ``}
  <label for="pw">Password</label>
  <input id="pw" name="password" type="password" autocomplete="current-password" autofocus required/>
  <button type="submit">Enter the studio →</button>
  ${configured ? `` : `<p class="note">⚠️ The studio password hasn't been set yet. Add the <code>STUDIO_PASSWORD</code> secret, then redeploy.</p>`}
</form></div></body></html>`;
}

function money(cents) {
  if (cents == null) return "—";
  return "$" + (cents / 100).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}
function num(v) {
  return v == null ? "—" : v;
}
function metric(value, label) {
  return `<div class="stat"><div class="n">${value}</div><div class="k">${label}</div></div>`;
}
function dot(on) {
  return `<span class="dot ${on ? "on" : "off"}" title="${on ? "Live" : "Snapshot"}"></span>`;
}

function dashboardHTML(m) {
  const ttbi = m.ttbi;
  const ts = m.ts;

  const tierRows = (ttbi.tiers || [])
    .map(
      (t) => `<tr>
        <td>${String(t.tier).toUpperCase()}</td>
        <td style="text-align:right">${t.users}</td>
      </tr>`
    )
    .join("") || `<tr><td colspan="2" style="color:var(--muted)">No tiers yet</td></tr>`;

  const spRows = (ts.products || [])
    .map(
      (s) => `<tr>
        <td>${s.title}</td>
        <td style="text-align:right;color:var(--muted)">${s.price_cents === 0 ? "Free" : money(s.price_cents)}</td>
        <td style="text-align:right;color:var(--gold)">${s.downloads}</td>
        <td style="text-align:right;color:var(--gold)">${s.revenue_cents > 0 ? money(s.revenue_cents) : (s.downloads > 0 ? "$0" : "—")}</td>
      </tr>`
    )
    .join("");

  const stripeStr = m.stripe ? money(m.stripe.cents) + (m.stripe.more ? "+" : "") : "—";

  return `<!DOCTYPE html><html lang="en"><head>
<meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<meta name="robots" content="noindex,nofollow"/>
<title>Tiny Bird Studio</title>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,700;1,9..144,400&family=DM+Sans:wght@300;400;500;600&display=swap" rel="stylesheet"/>
<style>${BASE_CSS}
  .top{max-width:1080px;margin:0 auto;padding:26px 24px;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px}
  .brand{display:flex;align-items:center;gap:12px}
  .brand .ic{width:38px;height:38px;border-radius:11px;background:linear-gradient(150deg,#F0B83A,#E8A022);display:flex;align-items:center;justify-content:center;font-size:20px}
  .brand h1{font-size:20px;font-weight:700;letter-spacing:-.02em}
  .brand .meta{font-size:12px;color:var(--muted);margin-top:2px}
  .out{font-size:13px;color:var(--muted);text-decoration:none;border:1px solid rgba(251,247,242,.14);padding:8px 14px;border-radius:10px;transition:color .2s,border-color .2s}
  .out:hover{color:var(--cream);border-color:rgba(251,247,242,.3)}
  .wrap{max-width:1080px;margin:0 auto;padding:6px 24px 60px;display:flex;flex-direction:column;gap:18px}
  .panel{background:var(--panel);border:1px solid rgba(251,247,242,.07);border-radius:20px;padding:26px}
  .banner{display:flex;gap:34px;flex-wrap:wrap;align-items:flex-end}
  .phead{display:flex;align-items:center;gap:12px;margin-bottom:22px}
  .phead .pic{width:34px;height:34px;border-radius:10px;background:var(--panel2);display:flex;align-items:center;justify-content:center;font-size:18px}
  .phead h2{font-family:'Fraunces',serif;font-size:21px;font-weight:700}
  .pill{font-size:10px;letter-spacing:.1em;text-transform:uppercase;padding:4px 9px;border-radius:20px;background:rgba(232,160,34,.14);color:var(--gold)}
  .pill.live{background:rgba(111,191,139,.16);color:#8fd6a8}
  .statrow{display:flex;gap:34px;flex-wrap:wrap}
  .stat .n{font-family:'Fraunces',serif;font-size:30px;font-weight:700;color:var(--gold);line-height:1}
  .stat .k{font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--muted);margin-top:6px}
  .sub{font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);margin:24px 0 10px}
  table{width:100%;border-collapse:collapse;font-size:14px}
  th{text-align:left;font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted);font-weight:500;padding:0 0 10px}
  th.r{text-align:right}
  td{padding:10px 0;border-top:1px solid rgba(251,247,242,.06)}
  .dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-left:8px;vertical-align:middle}
  .dot.on{background:#6FBF8B;box-shadow:0 0 0 3px rgba(111,191,139,.18)}
  .dot.off{background:rgba(251,247,242,.25)}
  .foot{max-width:1080px;margin:0 auto;padding:0 24px 50px;font-size:12px;color:var(--muted);line-height:1.7}
</style></head>
<body>
  <header class="top">
    <div class="brand">
      <div class="ic">🐤</div>
      <div><h1 class="serif">Tiny Bird Studio</h1><div class="meta">2 active projects · updated ${m.asOf}</div></div>
    </div>
    <a class="out" href="/studio/logout">Sign out</a>
  </header>
  <main class="wrap">

    <section class="panel">
      <div class="banner">
        ${metric(stripeStr, "Stripe gross revenue")}
        ${metric(num(ttbi.signups == null ? null : (ttbi.signups + (ts.signups || 0))), "Total sign-ups")}
        ${metric(num(ts.downloads_total), "Total downloads")}
      </div>
    </section>

    <section class="panel">
      <div class="phead">
        <div class="pic">💡</div>
        <h2>Tiny Thoughts, Big Ideas</h2>
        <span class="pill live">Live</span>${dot(m.live.ttbi)}
      </div>
      <div class="statrow">
        ${metric(num(ttbi.signups), "Sign-ups")}
        ${metric(num(ttbi.waitlist), "Waitlist")}
        ${metric(m.stripe ? money(m.stripe.cents) + (m.stripe.more ? "+" : "") : "—", "Stripe revenue")}
      </div>
      <div class="sub">Sign-ups by tier</div>
      <table>
        <thead><tr><th>Tier</th><th class="r">Users</th></tr></thead>
        <tbody>${tierRows}</tbody>
      </table>
    </section>

    <section class="panel">
      <div class="phead">
        <div class="pic">⚡</div>
        <h2>Tiny Superpowers</h2>
        <span class="pill">In development</span>${dot(m.live.ts)}
      </div>
      <div class="statrow">
        ${metric(num(ts.signups), "Sign-ups")}
        ${metric(num(ts.downloads_total), "Downloads")}
        ${metric(money(ts.purchases_revenue_cents), "Revenue (recorded)")}
        ${metric("—", "Traffic")}
      </div>
      <div class="sub">Downloads by superpower</div>
      <table>
        <thead><tr><th>Superpower</th><th class="r">Price</th><th class="r">Downloads</th><th class="r">Revenue</th></tr></thead>
        <tbody>${spRows}</tbody>
      </table>
    </section>

  </main>
  <div style="max-width:1080px;margin:0 auto;padding:0 24px 24px;display:flex;justify-content:flex-end">
    <button onclick="exportCSV()" style="background:var(--panel);border:1px solid rgba(251,247,242,.14);color:var(--cream);border-radius:10px;padding:10px 18px;font-size:13px;cursor:pointer;display:flex;align-items:center;gap:8px">
      ↓ Download spreadsheet
    </button>
  </div>
  <div class="foot">
    ${dot(m.live.stripe)} Stripe &nbsp; ${dot(m.live.ttbi)} Tiny Thoughts DB &nbsp; ${dot(m.live.ts)} Tiny Superpowers DB
    &nbsp;— a filled dot means live; a hollow dot means showing the last snapshot (add the missing secret to go live).
    Traffic is not wired yet.
  </div>
<script>
const DATA = ${JSON.stringify({ asOf: m.asOf, stripe: m.stripe, ttbi: m.ttbi, ts: m.ts })};
function csvRow(cells) {
  return cells.map(c => {
    const s = String(c ?? '');
    return s.includes(',') || s.includes('"') || s.includes('\n') ? '"' + s.replace(/"/g,'""') + '"' : s;
  }).join(',');
}
function exportCSV() {
  const rows = [];
  rows.push(['Tiny Bird Studio Export', DATA.asOf]);
  rows.push([]);
  rows.push(['OVERVIEW']);
  rows.push(['Stripe gross revenue', DATA.stripe ? (DATA.stripe.cents/100).toFixed(2) : '']);
  rows.push(['Total sign-ups', (DATA.ttbi.signups||0)+(DATA.ts.signups||0)]);
  rows.push(['Total downloads', DATA.ts.downloads_total||0]);
  rows.push([]);
  rows.push(['TINY THOUGHTS BIG IDEAS']);
  rows.push(['Sign-ups', DATA.ttbi.signups]);
  rows.push(['Waitlist', DATA.ttbi.waitlist]);
  rows.push(['Stripe revenue', DATA.stripe ? (DATA.stripe.cents/100).toFixed(2) : '']);
  rows.push(['Tier','Users']);
  (DATA.ttbi.tiers||[]).forEach(t => rows.push([t.tier.toUpperCase(), t.users]));
  rows.push([]);
  rows.push(['TINY SUPERPOWERS']);
  rows.push(['Sign-ups', DATA.ts.signups]);
  rows.push(['Downloads', DATA.ts.downloads_total]);
  rows.push(['Revenue (recorded)', DATA.ts.purchases_revenue_cents ? (DATA.ts.purchases_revenue_cents/100).toFixed(2) : 0]);
  rows.push([]);
  rows.push(['Superpower','Price','Downloads','Revenue']);
  (DATA.ts.products||[]).forEach(p => rows.push([
    p.title,
    p.price_cents === 0 ? 'Free' : (p.price_cents/100).toFixed(2),
    p.downloads,
    p.revenue_cents > 0 ? (p.revenue_cents/100).toFixed(2) : (p.downloads > 0 ? '0.00' : '')
  ]));
  const csv = rows.map(csvRow).join('\n');
  const a = document.createElement('a');
  a.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
  a.download = 'tiny-bird-studio-' + new Date().toISOString().slice(0,10) + '.csv';
  a.click();
}
<\/script>
</body></html>`;
}
