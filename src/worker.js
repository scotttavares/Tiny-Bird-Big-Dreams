// Tiny Bird Studio — private dashboard gated behind a password.
// Everything except /studio is served straight from static assets.
// The password is provided as the STUDIO_PASSWORD secret (never in this file).

const SESSION_COOKIE = "tbbd_studio";
const SESSION_TTL = 60 * 60 * 24 * 30; // 30 days, in seconds

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
        return html(dashboardHTML());
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

// Real figures, pulled from the project databases. Update STUDIO_DATA
// when numbers change (or wire it to live Supabase queries later).
const STUDIO_DATA = {
  asOf: "Jun 11, 2026",
  projects: [
    {
      name: "Tiny Thoughts, Big Ideas",
      icon: "💡",
      tag: "Live",
      signups: 1,
      waitlist: 3,
      revenueCents: 0,
      // Revenue by tier (cents). Tiers seen in the DB; revenue is from Stripe.
      tiers: [
        { name: "BYO", users: 1, revenueCents: 0 },
        { name: "Pro", users: 0, revenueCents: 0 },
        { name: "Power", users: 0, revenueCents: 0 },
        { name: "Hosted", users: 0, revenueCents: 0 },
      ],
    },
    {
      name: "Tiny Superpowers",
      icon: "⚡",
      tag: "In development",
      signups: 1,
      downloads: 0,
      revenueCents: 0,
      traffic: null, // wire to Cloudflare analytics
      // Each "superpower" product: downloads + list price (cents).
      superpowers: [
        { name: "Data Analyzer", priceCents: 3900, downloads: 0 },
        { name: "Presentation Pro", priceCents: 2900, downloads: 0 },
        { name: "Meeting Memo", priceCents: 2400, downloads: 0 },
        { name: "Project Planner", priceCents: 1900, downloads: 0 },
        { name: "Brain Dump", priceCents: 1500, downloads: 0 },
        { name: "Focus Mode", priceCents: 1500, downloads: 0 },
        { name: "Email Wizard", priceCents: 1200, downloads: 0 },
        { name: "Content Blaster", priceCents: 0, downloads: 0 },
      ],
    },
  ],
};

function money(cents) {
  return "$" + (cents / 100).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}
function metric(value, label) {
  return `<div class="stat"><div class="n">${value}</div><div class="k">${label}</div></div>`;
}

function dashboardHTML() {
  const d = STUDIO_DATA;
  const ttbi = d.projects[0];
  const ts = d.projects[1];

  const tierRows = ttbi.tiers
    .map(
      (t) => `<tr>
        <td>${t.name}</td>
        <td style="text-align:right">${t.users}</td>
        <td style="text-align:right;color:var(--gold)">${money(t.revenueCents)}</td>
      </tr>`
    )
    .join("");

  const spRows = ts.superpowers
    .map(
      (s) => `<tr>
        <td>${s.name}</td>
        <td style="text-align:right;color:var(--muted)">${s.priceCents === 0 ? "Free" : money(s.priceCents)}</td>
        <td style="text-align:right;color:var(--gold)">${s.downloads}</td>
      </tr>`
    )
    .join("");

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
  th.r,td.r{text-align:right}
  td{padding:10px 0;border-top:1px solid rgba(251,247,242,.06)}
  .row2{display:grid;grid-template-columns:1fr 1fr;gap:34px}
  @media(max-width:680px){.row2{grid-template-columns:1fr}}
</style></head>
<body>
  <header class="top">
    <div class="brand">
      <div class="ic">🐤</div>
      <div><h1 class="serif">Tiny Bird Studio</h1><div class="meta">2 active projects · as of ${d.asOf}</div></div>
    </div>
    <a class="out" href="/studio/logout">Sign out</a>
  </header>
  <main class="wrap">

    <section class="panel">
      <div class="phead">
        <div class="pic">${ttbi.icon}</div>
        <h2>${ttbi.name}</h2>
        <span class="pill live">${ttbi.tag}</span>
      </div>
      <div class="statrow">
        ${metric(ttbi.signups, "Sign-ups")}
        ${metric(ttbi.waitlist, "Waitlist")}
        ${metric(money(ttbi.revenueCents), "Total revenue")}
      </div>
      <div class="sub">Revenue by tier</div>
      <table>
        <thead><tr><th>Tier</th><th class="r">Users</th><th class="r">Revenue</th></tr></thead>
        <tbody>${tierRows}</tbody>
      </table>
    </section>

    <section class="panel">
      <div class="phead">
        <div class="pic">${ts.icon}</div>
        <h2>${ts.name}</h2>
        <span class="pill">${ts.tag}</span>
      </div>
      <div class="statrow">
        ${metric(ts.signups, "Sign-ups")}
        ${metric(ts.downloads, "Downloads")}
        ${metric(money(ts.revenueCents), "Stripe revenue")}
        ${metric(ts.traffic == null ? "—" : ts.traffic, "Traffic")}
      </div>
      <div class="sub">Downloads by superpower</div>
      <table>
        <thead><tr><th>Superpower</th><th class="r">Price</th><th class="r">Downloads</th></tr></thead>
        <tbody>${spRows}</tbody>
      </table>
    </section>

  </main>
</body></html>`;
}
