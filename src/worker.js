// Tiny Bird Studio — private dashboard gated behind a password.
// Everything except /studio is served straight from static assets.
// On /studio it pulls LIVE metrics from Supabase + Stripe (server-side),
// falling back to a snapshot when a source/secret isn't available.
//
// Secrets (set in Cloudflare → Worker → Settings → Variables and secrets):
//   STUDIO_PASSWORD      – password for the login gate
//   TTBI_SERVICE_KEY     – Supabase service_role key (Tiny Thoughts, Big Ideas)
//   TS_SERVICE_KEY       – Supabase service_role key (tinysuperpowers)
//   STRIPE_KEY           – Stripe restricted, read-only secret key
//   CF_ANALYTICS_TOKEN   – Cloudflare API token (Account Analytics: Read)
//   CF_ACCOUNT_ID        – Cloudflare account tag (for the beacon fallback)
//   CF_TBBD_ZONE_TAG     – Cloudflare zone tag for tinybirdbigdreams.com
//   CF_TTBI_ZONE_TAG     – Cloudflare zone tag for tinythoughtsbigideas.com
//   CF_TS_ZONE_TAG       – Cloudflare zone tag for tinysuperpowers.com
//   CF_TBBD_BEACON       – Web Analytics site tag for tinybirdbigdreams.com (fallback)
//   CF_TTBI_BEACON       – Web Analytics site tag for tinythoughtsbigideas.com (fallback)
//   CF_TS_BEACON         – Web Analytics site tag for tinysuperpowers.com (fallback)

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
    if (p === "/studio/export.csv") {
      if (await isAuthed(request, env)) {
        const metrics = await collectMetrics(env);
        return csvExport(metrics);
      }
      return new Response(null, { status: 303, headers: { location: "/studio" } });
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
  ttbi: {
    signups: 1,
    waitlist: 3,
    tiers: [
      { tier: "byo", users: 1, waitlist: 1 },
    ],
    weekly_signups: [],
  },
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
    weekly_signups: [],
    weekly_revenue: [],
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

function getMondayStr(ms) {
  const d = new Date(ms);
  const day = d.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setUTCDate(d.getUTCDate() + diff);
  return d.toISOString().slice(0, 10);
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
  const weekly = {};
  const cutoff = Date.now() - 12 * 7 * 24 * 3600 * 1000;
  for (const c of j.data || []) {
    if (c.paid && !c.refunded && c.status === "succeeded") {
      const amount = (c.amount || 0) - (c.amount_refunded || 0);
      cents += amount;
      count += 1;
      currency = c.currency || currency;
      const ms = (c.created || 0) * 1000;
      if (ms >= cutoff) {
        const w = getMondayStr(ms);
        weekly[w] = (weekly[w] || 0) + amount;
      }
    }
  }
  return { cents, count, currency, weekly, more: !!j.has_more };
}

/* -------------------- Cloudflare Web Analytics -------------------- */

// Extract bare 32-char hex token from a raw value that may be the full <script> snippet
function beaconToken(raw) {
  if (!raw) return null;
  const m = raw.match(/["']token["']\s*:\s*["']([a-f0-9]{32})["']/i);
  return m ? m[1] : raw.trim();
}

function cfAuthHeader(env) {
  return { Authorization: `Bearer ${(env.CF_ANALYTICS_TOKEN || "").replace(/\s/g, "")}` };
}

let _cfAccountId = null;

async function cfGetAccountId(env) {
  if (_cfAccountId) return _cfAccountId;
  if (env.CF_ACCOUNT_ID) {
    _cfAccountId = env.CF_ACCOUNT_ID.trim();
    return _cfAccountId;
  }
  throw new Error("CF_ACCOUNT_ID secret not set");
}

// Shared aggregation logic for both zone-level and beacon traffic data
function parseCfGroups(groups, extractor) {
  const d7start = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const d1start = new Date(Date.now() - 1 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const totals = {
    d30: { visitors: 0, pageviews: 0 },
    d7: { visitors: 0, pageviews: 0 },
    d1: { visitors: 0, pageviews: 0 },
  };
  const weekly = {};
  for (const g of groups) {
    const date = g.dimensions?.date || "";
    const { v, pv } = extractor(g);
    totals.d30.visitors += v;
    totals.d30.pageviews += pv;
    if (date >= d7start) { totals.d7.visitors += v; totals.d7.pageviews += pv; }
    if (date >= d1start) { totals.d1.visitors += v; totals.d1.pageviews += pv; }
    const w = getMondayStr(new Date(date + "T00:00:00Z").getTime());
    if (!weekly[w]) weekly[w] = { visitors: 0, pageviews: 0 };
    weekly[w].visitors += v;
    weekly[w].pageviews += pv;
  }
  return { totals, weekly };
}

// Lookup zone tag — check explicit env secrets first, then auto-discover via REST API
async function cfGetZoneTag(hostname, env) {
  if (hostname === "tinybirdbigdreams.com" && env.CF_TBBD_ZONE_TAG) return env.CF_TBBD_ZONE_TAG.trim();
  if (hostname === "tinythoughtsbigideas.com" && env.CF_TTBI_ZONE_TAG) return env.CF_TTBI_ZONE_TAG.trim();
  if (hostname === "tinysuperpowers.com" && env.CF_TS_ZONE_TAG) return env.CF_TS_ZONE_TAG.trim();
  const r = await fetch(
    `https://api.cloudflare.com/client/v4/zones?name=${encodeURIComponent(hostname)}&per_page=1`,
    { headers: cfAuthHeader(env) }
  );
  if (!r.ok) throw new Error("cf zones " + r.status);
  const j = await r.json();
  const id = j.result?.[0]?.id;
  if (!id) throw new Error("zone not found: " + hostname);
  return id;
}

// Zone-level CDN analytics — matches the numbers shown on the CF Domains dashboard
async function cfTrafficZone(zoneId, env) {
  const endDate = new Date().toISOString().slice(0, 10);
  const startDate = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const r = await fetch("https://api.cloudflare.com/client/v4/graphql", {
    method: "POST",
    headers: { ...cfAuthHeader(env), "Content-Type": "application/json" },
    body: JSON.stringify({
      query:
        `{viewer{zones(filter:{zoneTag:"${zoneId}"}){
        httpRequests1dGroups(
        filter:{AND:[{date_geq:"${startDate}"},{date_leq:"${endDate}"}]},
        limit:365,orderBy:[date_ASC]
        ){dimensions{date}sum{requests}uniq{uniques}}}}}`,
    }),
  });
  if (!r.ok) throw new Error("cf graphql zone " + r.status);
  const j = await r.json();
  if (j.errors?.length) throw new Error("cf gql zone: " + j.errors[0].message);
  const groups = j.data?.viewer?.zones?.[0]?.httpRequests1dGroups || [];
  return parseCfGroups(groups, (g) => ({ v: g.uniq?.uniques || 0, pv: g.sum?.requests || 0 }));
}

// Beacon-based Web Analytics — only tracks visits with the JS snippet installed
async function cfTrafficBeacon(siteTag, env) {
  const accountId = await cfGetAccountId(env);
  const endDate = new Date().toISOString().slice(0, 10);
  const startDate = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const r = await fetch("https://api.cloudflare.com/client/v4/graphql", {
    method: "POST",
    headers: { ...cfAuthHeader(env), "Content-Type": "application/json" },
    body: JSON.stringify({
      query:
        `{viewer{accounts(filter:{accountTag:"${accountId}"}){
        rumPageloadEventsAdaptiveGroups(
        filter:{AND:[{siteTag:"${siteTag}"},{date_geq:"${startDate}"},{date_leq:"${endDate}"}]},
        limit:10000,orderBy:[date_ASC]
        ){count dimensions{date}sum{visits}}}}}`,
    }),
  });
  if (!r.ok) throw new Error("cf graphql beacon " + r.status);
  const j = await r.json();
  if (j.errors?.length) throw new Error("cf gql beacon: " + j.errors[0].message);
  const groups = j.data?.viewer?.accounts?.[0]?.rumPageloadEventsAdaptiveGroups || [];
  return parseCfGroups(groups, (g) => ({ v: g.sum?.visits || 0, pv: g.count || 0 }));
}

// Try zone-level CDN analytics first (real traffic), fall back to JS beacon data
async function cfTraffic(rawTag, hostname, env) {
  if (!env.CF_ANALYTICS_TOKEN) throw new Error("no cf token");
  try {
    const zoneId = await cfGetZoneTag(hostname, env);
    return await cfTrafficZone(zoneId, env);
  } catch {
    const siteTag = beaconToken(rawTag);
    if (!siteTag) throw new Error("no cf config");
    return await cfTrafficBeacon(siteTag, env);
  }
}

async function collectMetrics(env) {
  const [ttbi, ts, stripe, tbbdTraf, ttbiTraf, tsTraf] = await Promise.allSettled([
    supaMetrics(SUPA.ttbi, env),
    supaMetrics(SUPA.ts, env),
    stripeRevenue(env),
    cfTraffic(env.CF_TBBD_BEACON, "tinybirdbigdreams.com", env),
    cfTraffic(env.CF_TTBI_BEACON, "tinythoughtsbigideas.com", env),
    cfTraffic(env.CF_TS_BEACON, "tinysuperpowers.com", env),
  ]);

  const ttbiData = ttbi.status === "fulfilled" ? ttbi.value : SNAPSHOT.ttbi;
  const tsData = ts.status === "fulfilled" ? ts.value : SNAPSHOT.ts;
  const stripeData = stripe.status === "fulfilled" ? stripe.value : null;
  const tbbdTrafData = tbbdTraf.status === "fulfilled" ? tbbdTraf.value : null;
  const ttbiTrafData = ttbiTraf.status === "fulfilled" ? ttbiTraf.value : null;
  const tsTrafData = tsTraf.status === "fulfilled" ? tsTraf.value : null;

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
      traffic:
        tbbdTraf.status === "fulfilled" ||
        ttbiTraf.status === "fulfilled" ||
        tsTraf.status === "fulfilled",
    },
    ttbi: ttbiData,
    ts: tsData,
    stripe: stripeData,
    traffic: { tbbd: tbbdTrafData, ttbi: ttbiTrafData, ts: tsTrafData },
  };
}

/* ----------------------------- CSV export ---------------------------- */

function csvRow(cells) {
  return cells
    .map((c) => {
      const s = String(c ?? "");
      if (s.includes(",") || s.includes('"') || s.includes("\n")) {
        return '"' + s.replace(/"/g, '""') + '"';
      }
      return s;
    })
    .join(",");
}

function csvExport(m) {
  const rows = [];
  rows.push(["Tiny Bird Studio Export", m.asOf]);
  rows.push([]);
  rows.push(["OVERVIEW"]);
  rows.push(["Revenue", ((m.stripe ? m.stripe.cents : 0) + (m.ts.purchases_revenue_cents || 0)) / 100]);
  rows.push(["Total sign-ups", (m.ttbi.signups || 0) + (m.ts.signups || 0)]);
  rows.push(["Total downloads", m.ts.downloads_total || 0]);
  rows.push([]);
  rows.push(["TINY THOUGHTS BIG IDEAS"]);
  rows.push(["Sign-ups", m.ttbi.signups]);
  rows.push(["Waitlist", m.ttbi.waitlist]);
  rows.push(["Revenue", m.stripe ? (m.stripe.cents / 100).toFixed(2) : ""]);
  rows.push(["Tier", "Active Users", "Waitlist"]);
  for (const t of m.ttbi.tiers || []) {
    rows.push([t.tier.toUpperCase(), t.users ?? 0, t.waitlist ?? 0]);
  }
  rows.push([]);
  rows.push(["TINY SUPERPOWERS"]);
  rows.push(["Sign-ups", m.ts.signups]);
  rows.push(["Downloads", m.ts.downloads_total]);
  rows.push([
    "Revenue",
    m.ts.purchases_revenue_cents ? (m.ts.purchases_revenue_cents / 100).toFixed(2) : 0,
  ]);
  rows.push([]);
  rows.push(["Superpower", "Price", "Downloads", "Revenue"]);
  for (const p of m.ts.products || []) {
    rows.push([
      p.title,
      p.price_cents === 0 ? "Free" : (p.price_cents / 100).toFixed(2),
      p.downloads,
      p.revenue_cents > 0
        ? (p.revenue_cents / 100).toFixed(2)
        : p.downloads > 0
        ? "0.00"
        : "",
    ]);
  }
  if (m.traffic?.tbbd?.totals || m.traffic?.ttbi?.totals || m.traffic?.ts?.totals) {
    rows.push([]);
    rows.push(["TRAFFIC (last 30 days)"]);
    if (m.traffic?.tbbd?.totals) {
      rows.push(["Tiny Bird Big Dreams Visits", m.traffic.tbbd.totals.d30.visitors]);
      rows.push(["Tiny Bird Big Dreams Requests", m.traffic.tbbd.totals.d30.pageviews]);
    }
    if (m.traffic?.ttbi?.totals) {
      rows.push(["TTBI Visits", m.traffic.ttbi.totals.d30.visitors]);
      rows.push(["TTBI Requests", m.traffic.ttbi.totals.d30.pageviews]);
    }
    if (m.traffic?.ts?.totals) {
      rows.push(["Tiny Superpowers Visits", m.traffic.ts.totals.d30.visitors]);
      rows.push(["Tiny Superpowers Requests", m.traffic.ts.totals.d30.pageviews]);
    }
  }
  const today = new Date().toISOString().slice(0, 10);
  const csv = rows.map(csvRow).join("\n");
  return new Response(csv, {
    headers: {
      "content-type": "text/csv;charset=UTF-8",
      "content-disposition": `attachment; filename="tiny-bird-studio-${today}.csv"`,
      "cache-control": "no-store",
    },
  });
}

/* ----------------------------- chart data ---------------------------- */

function lastNWeeks(n) {
  const weeks = [];
  const now = new Date();
  const day = now.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  const monday = new Date(now);
  monday.setUTCDate(monday.getUTCDate() + diff);
  monday.setUTCHours(0, 0, 0, 0);
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date(monday);
    d.setUTCDate(d.getUTCDate() - i * 7);
    weeks.push(d.toISOString().slice(0, 10));
  }
  return weeks;
}

function buildChartData(m) {
  const weeks = lastNWeeks(12);
  const labels = weeks.map((w) => {
    const d = new Date(w + "T00:00:00Z");
    return (d.getUTCMonth() + 1) + "/" + d.getUTCDate();
  });

  const ttbiSignupMap = {};
  for (const pt of m.ttbi.weekly_signups || []) {
    ttbiSignupMap[pt.week.slice(0, 10)] = Number(pt.count);
  }
  const tsSignupMap = {};
  for (const pt of m.ts.weekly_signups || []) {
    tsSignupMap[pt.week.slice(0, 10)] = Number(pt.count);
  }
  const tsRevMap = {};
  for (const pt of m.ts.weekly_revenue || []) {
    tsRevMap[pt.week.slice(0, 10)] = Number(pt.revenue_cents);
  }
  const stripeWeekly = m.stripe ? (m.stripe.weekly || {}) : {};

  const tbbdTrafW = m.traffic?.tbbd?.weekly || {};
  const ttbiTrafW = m.traffic?.ttbi?.weekly || {};
  const tsTrafW = m.traffic?.ts?.weekly || {};

  return {
    labels,
    signups: {
      ttbi: weeks.map((w) => ttbiSignupMap[w] || 0),
      ts: weeks.map((w) => tsSignupMap[w] || 0),
    },
    revenue: {
      stripe: weeks.map((w) => +((stripeWeekly[w] || 0) / 100).toFixed(2)),
      ts: weeks.map((w) => +((tsRevMap[w] || 0) / 100).toFixed(2)),
    },
    traffic: {
      tbbd: weeks.map((w) => (tbbdTrafW[w] ? tbbdTrafW[w].visitors : 0)),
      ttbi: weeks.map((w) => (ttbiTrafW[w] ? ttbiTrafW[w].visitors : 0)),
      ts: weeks.map((w) => (tsTrafW[w] ? tsTrafW[w].visitors : 0)),
    },
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
  const chartData = buildChartData(m);
  const trafficStats = {
    tbbd: m.traffic?.tbbd?.totals || null,
    ttbi: m.traffic?.ttbi?.totals || null,
    ts: m.traffic?.ts?.totals || null,
  };

  const ttbiRevCents = m.stripe ? m.stripe.cents : 0;
  const tsRevCents = ts.purchases_revenue_cents || 0;
  const totalRevCents = ttbiRevCents + tsRevCents;
  const totalRevStr = (m.stripe || tsRevCents) ? money(totalRevCents) + (m.stripe?.more ? "+" : "") : "—";
  const ttbiRevStr = m.stripe ? money(m.stripe.cents) + (m.stripe.more ? "+" : "") : "—";

  const tierRows = (ttbi.tiers || []).map((t) => {
    const subRows = (t.waitlist_users || []).map((u) => `<tr style="background:rgba(251,247,242,.03)">
        <td style="padding-left:20px;font-size:13px;color:var(--muted)">↳ ${u.name || "—"}<span style="font-size:11px;margin-left:8px;opacity:.6">${u.email || ""}</span></td>
        <td colspan="2" style="text-align:right;font-size:11px;color:var(--muted)">${u.status || "pending"}</td>
        <td></td>
      </tr>`).join("");
    const rev = t.tier === "byo" ? ttbiRevStr : "—";
    return `<tr>
        <td>${t.tier.toUpperCase()}</td>
        <td style="text-align:right;color:var(--gold)">${t.users ?? 0}</td>
        <td style="text-align:right;color:var(--muted)">${t.waitlist ?? 0}</td>
        <td style="text-align:right;color:var(--gold)">${rev}</td>
      </tr>${subRows}`;
  }).join("");

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
  .phead{display:flex;align-items:center;gap:12px;margin-bottom:22px;flex-wrap:wrap}
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
  .filter-stack{margin-left:auto;display:flex;flex-direction:column;gap:8px;align-items:flex-end}
  .filters{display:flex;gap:8px}
  .fbtn{background:var(--panel2);border:1px solid rgba(251,247,242,.1);color:var(--muted);border-radius:8px;padding:6px 14px;font-size:12px;cursor:pointer;transition:all .2s}
  .fbtn.active{background:rgba(232,160,34,.18);border-color:var(--gold);color:var(--gold)}
  .fbtn:hover:not(.active){border-color:rgba(251,247,242,.3);color:var(--cream)}
  .wbtn{background:var(--panel2);border:1px solid rgba(251,247,242,.08);color:var(--muted);border-radius:7px;padding:4px 10px;font-size:11px;cursor:pointer;transition:all .2s}
  .wbtn.active{background:rgba(232,160,34,.1);border-color:rgba(232,160,34,.4);color:rgba(232,160,34,.9)}
  .wbtn:hover:not(.active){border-color:rgba(251,247,242,.25);color:var(--cream)}
  .traffic-note{color:var(--muted);font-size:13px;padding:30px 0;text-align:center}
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
        ${metric(totalRevStr, "Revenue")}
        ${metric(num(ttbi.signups == null ? null : (ttbi.signups + (ts.signups || 0))), "Total sign-ups")}
        ${metric(num(ts.downloads_total), "Total downloads")}
      </div>
    </section>

    <section class="panel">
      <div class="phead">
        <div class="pic">📈</div>
        <h2>Trends</h2>
        <div class="filter-stack">
          <div class="filters">
            <button class="fbtn active" data-filter="signups" onclick="setFilter('signups')">Sign-ups</button>
            <button class="fbtn" data-filter="revenue" onclick="setFilter('revenue')">Revenue</button>
            <button class="fbtn" data-filter="traffic" onclick="setFilter('traffic')">Traffic</button>
          </div>
          <div class="filters">
            <button class="wbtn active" data-window="30" onclick="setWindow(30)">30 days</button>
            <button class="wbtn" data-window="7" onclick="setWindow(7)">7 days</button>
            <button class="wbtn" data-window="1" onclick="setWindow(1)">24 hours</button>
          </div>
        </div>
      </div>
      <canvas id="trend-chart" height="80"></canvas>
      <div id="traffic-note" class="traffic-note" style="display:none">Traffic not connected yet — add <code>CF_ANALYTICS_TOKEN</code> and the zone-tag secrets.</div>
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
        ${metric(ttbiRevStr, "Revenue")}
        <div class="stat"><div class="n" id="ttbi-visits">—</div><div class="k">Visits (<span class="wl">30d</span>)</div></div>
        <div class="stat"><div class="n" id="ttbi-pv">—</div><div class="k">Requests (<span class="wl">30d</span>)</div></div>
      </div>
      <div class="sub">Sign-ups by tier</div>
      <table>
        <thead><tr><th>Tier</th><th class="r">Active users</th><th class="r">Waitlist</th><th class="r">Revenue</th></tr></thead>
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
        ${metric(money(ts.purchases_revenue_cents), "Revenue")}
        <div class="stat"><div class="n" id="ts-visits">—</div><div class="k">Visits (<span class="wl">30d</span>)</div></div>
        <div class="stat"><div class="n" id="ts-pv">—</div><div class="k">Requests (<span class="wl">30d</span>)</div></div>
      </div>
      <div class="sub">Downloads by superpower</div>
      <table>
        <thead><tr><th>Superpower</th><th class="r">Price</th><th class="r">Downloads</th><th class="r">Revenue</th></tr></thead>
        <tbody>${spRows}</tbody>
      </table>
    </section>

  </main>
  <div style="max-width:1080px;margin:0 auto;padding:0 24px 24px;display:flex;justify-content:flex-end">
    <a href="/studio/export.csv" style="background:var(--panel);border:1px solid rgba(251,247,242,.14);color:var(--cream);border-radius:10px;padding:10px 18px;font-size:13px;display:flex;align-items:center;gap:8px;text-decoration:none">
      ↓ Download spreadsheet
    </a>
  </div>
  <div class="foot">
    ${dot(m.live.stripe)} Stripe &nbsp; ${dot(m.live.ttbi)} Tiny Thoughts DB &nbsp; ${dot(m.live.ts)} Tiny Superpowers DB &nbsp; ${dot(m.live.traffic)} Traffic
    &nbsp;— filled dot = live data; hollow dot = snapshot or not connected yet.
  </div>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"><\/script>
<script>
var CD = ${JSON.stringify(chartData)};
var TS = ${JSON.stringify(trafficStats)};
var currentFilter = 'signups';
var currentWindow = 30;
var chart = null;

function fmt(n) {
  if (n == null || n === '') return '—';
  n = Number(n);
  if (n >= 10000) return (n / 1000).toFixed(1).replace(/\.0$/, '') + 'k';
  return n.toLocaleString('en-US');
}

function weeksFor(w) {
  return w === 1 ? 1 : w === 7 ? 2 : 12;
}

function getDatasets(filter) {
  var n = weeksFor(currentWindow);
  var g = {tension:0.4, fill:true, pointRadius:3};
  var green = Object.assign({}, g, {borderColor:'#6FBF8B', backgroundColor:'rgba(111,191,139,0.08)'});
  var gold  = Object.assign({}, g, {borderColor:'#E8A022',  backgroundColor:'rgba(232,160,34,0.08)'});
  var blue  = Object.assign({}, g, {borderColor:'#8B9DF0', backgroundColor:'rgba(139,157,240,0.08)'});
  if (filter === 'signups') return [
    Object.assign({label:'TTBI', data:CD.signups.ttbi.slice(-n)}, green),
    Object.assign({label:'Tiny Superpowers', data:CD.signups.ts.slice(-n)}, gold)
  ];
  if (filter === 'revenue') return [
    Object.assign({label:'Stripe (all apps)', data:CD.revenue.stripe.slice(-n)}, green),
    Object.assign({label:'Tiny Superpowers', data:CD.revenue.ts.slice(-n)}, gold)
  ];
  if (filter === 'traffic') return [
    Object.assign({label:'Tiny Bird Big Dreams visitors', data:CD.traffic.tbbd.slice(-n)}, blue),
    Object.assign({label:'TTBI visitors', data:CD.traffic.ttbi.slice(-n)}, green),
    Object.assign({label:'Tiny Superpowers visitors', data:CD.traffic.ts.slice(-n)}, gold)
  ];
  return [];
}

function hasTraffic() {
  return TS && (TS.tbbd || TS.ttbi || TS.ts);
}

function updateChart() {
  var n = weeksFor(currentWindow);
  var canvas = document.getElementById('trend-chart');
  var note = document.getElementById('traffic-note');
  var showNote = (currentFilter === 'traffic' && !hasTraffic());
  canvas.style.display = showNote ? 'none' : '';
  note.style.display = showNote ? '' : 'none';
  if (!showNote && chart) {
    chart.data.labels = CD.labels.slice(-n);
    chart.data.datasets = getDatasets(currentFilter);
    chart.update();
  }
}

function updateTrafficStats() {
  var key = currentWindow === 1 ? 'd1' : currentWindow === 7 ? 'd7' : 'd30';
  var wlabel = currentWindow === 1 ? '24h' : currentWindow === 7 ? '7d' : '30d';
  var ttbiT = TS.ttbi ? TS.ttbi[key] : null;
  var tsT = TS.ts ? TS.ts[key] : null;
  function upd(id, v) { var el = document.getElementById(id); if (el) el.textContent = v; }
  upd('ttbi-visits', ttbiT ? fmt(ttbiT.visitors) : '—');
  upd('ttbi-pv',     ttbiT ? fmt(ttbiT.pageviews) : '—');
  upd('ts-visits',   tsT ? fmt(tsT.visitors) : '—');
  upd('ts-pv',       tsT ? fmt(tsT.pageviews) : '—');
  document.querySelectorAll('.wl').forEach(function(el) { el.textContent = wlabel; });
}

function setFilter(filter) {
  currentFilter = filter;
  document.querySelectorAll('.fbtn').forEach(function(b) {
    b.classList.toggle('active', b.dataset.filter === filter);
  });
  updateChart();
}

function setWindow(w) {
  currentWindow = w;
  document.querySelectorAll('.wbtn').forEach(function(b) {
    b.classList.toggle('active', +b.dataset.window === w);
  });
  updateTrafficStats();
  updateChart();
}

(function() {
  updateTrafficStats();
  var ctx = document.getElementById('trend-chart').getContext('2d');
  chart = new Chart(ctx, {
    type: 'line',
    data: {labels: CD.labels.slice(-12), datasets: getDatasets('signups')},
    options: {
      responsive: true,
      plugins: {
        legend: {labels: {color: 'rgba(251,247,242,0.7)', font: {size: 12}}}
      },
      scales: {
        x: {ticks: {color: 'rgba(251,247,242,0.5)', font: {size: 11}}, grid: {color: 'rgba(251,247,242,0.05)'}},
        y: {ticks: {color: 'rgba(251,247,242,0.5)', font: {size: 11}}, grid: {color: 'rgba(251,247,242,0.05)'}, beginAtZero: true}
      }
    }
  });
})();
<\/script>
</body></html>`;
}
