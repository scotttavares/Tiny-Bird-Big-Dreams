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

function dashboardHTML() {
  // Placeholder figures matching the mockup — swap for real numbers anytime.
  const revenueBars = [40, 34, 30, 46, 62, 70, 66];
  const dlBars = [38, 44, 50, 58, 70, 82, 96];
  const bar = (h, on) =>
    `<div style="flex:1;height:${h}%;border-radius:6px 6px 3px 3px;background:${
      on
        ? "linear-gradient(180deg,#F0B83A,#E8A022)"
        : "rgba(251,247,242,.10)"
    }"></div>`;
  const chart = (vals, hotFrom) =>
    `<div style="display:flex;align-items:flex-end;gap:7px;height:90px;margin-top:8px">${vals
      .map((v, i) => bar(v, i >= hotFrom))
      .join("")}</div>`;

  return `<!DOCTYPE html><html lang="en"><head>
<meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<meta name="robots" content="noindex,nofollow"/>
<title>Tiny Bird Studio</title>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,700;1,9..144,400&family=DM+Sans:wght@300;400;500;600&display=swap" rel="stylesheet"/>
<style>${BASE_CSS}
  .top{max-width:1080px;margin:0 auto;padding:26px 24px;display:flex;align-items:center;justify-content:space-between}
  .brand{display:flex;align-items:center;gap:12px}
  .brand .ic{width:38px;height:38px;border-radius:11px;background:linear-gradient(150deg,#F0B83A,#E8A022);display:flex;align-items:center;justify-content:center;font-size:20px}
  .brand h1{font-size:20px;font-weight:700;letter-spacing:-.02em}
  .out{font-size:13px;color:var(--muted);text-decoration:none;border:1px solid rgba(251,247,242,.14);padding:8px 14px;border-radius:10px;transition:color .2s,border-color .2s}
  .out:hover{color:var(--cream);border-color:rgba(251,247,242,.3)}
  .grid{max-width:1080px;margin:0 auto;padding:6px 24px 60px;display:grid;grid-template-columns:repeat(12,1fr);gap:18px}
  .panel{background:var(--panel);border:1px solid rgba(251,247,242,.07);border-radius:20px;padding:24px}
  .lab{font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);margin-bottom:12px}
  .big{font-family:'Fraunces',serif;font-size:46px;font-weight:700;line-height:1;color:var(--gold)}
  .delta{font-size:13px;color:#6FBF8B;margin-top:10px}
  .statrow{display:flex;gap:30px;margin-top:18px;flex-wrap:wrap}
  .stat .n{font-family:'Fraunces',serif;font-size:26px;font-weight:700;color:var(--gold)}
  .stat .k{font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--muted);margin-top:4px}
  .c12{grid-column:span 12}.c7{grid-column:span 7}.c5{grid-column:span 5}.c6{grid-column:span 6}.c4{grid-column:span 4}
  @media(max-width:760px){.c7,.c5,.c6,.c4{grid-column:span 12}}
</style></head>
<body>
  <header class="top">
    <div class="brand"><div class="ic">🐤</div><h1 class="serif">Tiny Bird Studio</h1></div>
    <a class="out" href="/studio/logout">Sign out</a>
  </header>
  <main class="grid">
    <section class="panel c7">
      <div class="lab">Active projects</div>
      <div class="big">12</div>
      <div class="delta">↑ 3 new this month</div>
      <div class="statrow">
        <div class="stat"><div class="n">$2.4M</div><div class="k">Revenue</div></div>
        <div class="stat"><div class="n">47</div><div class="k">Apps</div></div>
        <div class="stat"><div class="n">12M</div><div class="k">Users</div></div>
      </div>
    </section>
    <section class="panel c5">
      <div class="lab">Revenue</div>
      ${chart(revenueBars, 4)}
    </section>
    <section class="panel c6">
      <div class="lab">Analytics — weekly downloads</div>
      <div class="big" style="font-size:34px">98k</div>
      <div class="k" style="font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--muted);margin-top:4px">Downloads</div>
      ${chart(dlBars, 4)}
    </section>
    <section class="panel c6">
      <div class="lab">D30 Retention</div>
      <div class="big">68%</div>
      <div class="delta" style="color:var(--muted)">Industry avg: 31%</div>
      <div class="statrow">
        <div class="stat"><div class="n">4.8</div><div class="k">Play Store</div></div>
        <div class="stat"><div class="n">4.9</div><div class="k">App Store</div></div>
      </div>
    </section>
  </main>
</body></html>`;
}
