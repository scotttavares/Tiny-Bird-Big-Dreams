// Consented, aggregate-only analytics for tinybirdbigdreams.com.
//
// Nothing here is called until a visitor has accepted "analytics" in the
// ClearConsent banner (the client only loads its tracker after consent).
// We store daily totals, never a per-person history:
//   d:{YYYY-MM-DD}            JSON day aggregate (see emptyDay)
//   uv:{weekStart}:{vid}      "1" — one key per consented visitor per week (unique count)
//   c:{YYYY-MM-DD}            JSON consent tally {accept, reject, custom} — anonymous

const DAY_TTL = 400 * 24 * 3600;
const UV_TTL = 120 * 24 * 3600;
const MAX_EVENTS = 50;
const MAX_STR = 80;
const OWN_HOSTS = new Set(["tinybirdbigdreams.com", "www.tinybirdbigdreams.com"]);
const EVENT_TYPES = new Set(["pv", "scroll", "out", "toy", "pick", "shop", "egg"]);
const BUCKETS = ["pv", "ref", "dev", "scroll", "out", "toy", "pick", "shop", "egg"];

export const APP_NAMES = { lull: "Lull", orbit: "Orbit", paperwars: "Paper Wars", fieldguide: "Field Guide" };

export function isValidVid(v) {
  return typeof v === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(v);
}

const str = (v) => (typeof v === "string" || typeof v === "number" ? String(v).trim().slice(0, MAX_STR) : "");

export function sanitizeBatch(body) {
  const out = { vid: null, events: [] };
  if (!body || typeof body !== "object" || Array.isArray(body)) return out;
  if (isValidVid(body.vid)) out.vid = body.vid;
  if (!Array.isArray(body.events)) return out;
  for (const e of body.events) {
    if (out.events.length >= MAX_EVENTS) break;
    if (!e || typeof e !== "object" || !EVENT_TYPES.has(e.t)) continue;
    if (e.t === "pv") {
      if (typeof e.p !== "string" || !e.p.startsWith("/") || e.p.startsWith("//")) continue;
      out.events.push({ t: "pv", p: e.p.split(/[?#]/)[0].slice(0, MAX_STR) });
    } else {
      const v = str(e.v);
      if (!v) continue;
      out.events.push({ t: e.t, v });
    }
  }
  return out;
}

const pad = (n) => String(n).padStart(2, "0");
export function dayKey(date) {
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`;
}
export function weekStart(date) {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7));
  return dayKey(d);
}
export function daysOfWeek(start) {
  const d0 = new Date(start + "T00:00:00Z");
  return Array.from({ length: 7 }, (_, i) => dayKey(new Date(d0.getTime() + i * 86400000)));
}

function emptyDay() {
  return Object.fromEntries(BUCKETS.map((b) => [b, {}]));
}
const bump = (obj, key, n = 1) => { obj[key] = (obj[key] || 0) + n; };

function deviceOf(ua = "") {
  if (/iPad|Tablet/i.test(ua)) return "tablet";
  if (/Mobi|iPhone|Android/i.test(ua)) return "mobile";
  return "desktop";
}
function refHost(referrer) {
  try {
    const h = new URL(referrer).hostname;
    return h && !OWN_HOSTS.has(h) ? h.slice(0, MAX_STR) : null;
  } catch { return null; }
}

export async function recordBatch(kv, batch, { referrer, ua, now = new Date() } = {}) {
  if (!kv || !batch || !batch.events.length) return;
  const key = `d:${dayKey(now)}`;
  const day = { ...emptyDay(), ...((await kv.get(key, { type: "json" })) || {}) };
  let sawPv = false;
  for (const e of batch.events) {
    if (e.t === "pv") { bump(day.pv, e.p); sawPv = true; }
    else bump(day[e.t], e.v);
  }
  if (sawPv) {
    bump(day.dev, deviceOf(ua));
    const h = referrer ? refHost(referrer) : null;
    if (h) bump(day.ref, h);
  }
  await kv.put(key, JSON.stringify(day), { expirationTtl: DAY_TTL });
  if (batch.vid) await kv.put(`uv:${weekStart(now)}:${batch.vid}`, "1", { expirationTtl: UV_TTL });
}

export async function recordConsent(kv, choice, now = new Date()) {
  if (!kv || !["accept", "reject", "custom"].includes(choice)) return;
  const key = `c:${dayKey(now)}`;
  const c = { accept: 0, reject: 0, custom: 0, ...((await kv.get(key, { type: "json" })) || {}) };
  c[choice]++;
  await kv.put(key, JSON.stringify(c), { expirationTtl: DAY_TTL });
}

export async function readRange(kv, days) {
  const sum = emptyDay();
  const rows = await Promise.all(days.map((d) => kv.get(`d:${d}`, { type: "json" })));
  for (const row of rows) {
    if (!row) continue;
    for (const b of BUCKETS) for (const [k, n] of Object.entries(row[b] || {})) bump(sum[b], k, n);
  }
  return sum;
}

export async function readConsent(kv, days) {
  const sum = { accept: 0, reject: 0, custom: 0 };
  const rows = await Promise.all(days.map((d) => kv.get(`c:${d}`, { type: "json" })));
  for (const r of rows) if (r) for (const k of Object.keys(sum)) sum[k] += r[k] || 0;
  return sum;
}

export async function countUniques(kv, week) {
  let n = 0, cursor;
  do {
    const page = await kv.list({ prefix: `uv:${week}:`, cursor });
    n += page.keys.length;
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return n;
}

export function appOf(path) {
  const m = /^\/(lull|orbit|paperwars|fieldguide)(?:[-./]|$)/.exec(path || "");
  return m ? m[1] : null;
}

export function totalPv(agg) {
  return Object.values(agg?.pv || {}).reduce((a, b) => a + b, 0);
}
export function pvByApp(agg) {
  const out = { lull: 0, orbit: 0, paperwars: 0, fieldguide: 0 };
  for (const [p, n] of Object.entries(agg?.pv || {})) { const a = appOf(p); if (a) out[a] += n; }
  return out;
}

const pct = (a, b) => Math.round(((a - b) / b) * 100);

export function highlights({ thisWeek, lastWeek, uniquesThis = 0, uniquesLast = 0, consentThis, messagesThis = 0, signupsThis = 0 }) {
  const out = [];
  const now = pvByApp(thisWeek), before = pvByApp(lastWeek);
  const moves = Object.keys(now)
    .filter((a) => Math.max(now[a], before[a]) >= 10 && before[a] > 0 && Math.abs(pct(now[a], before[a])) >= 25)
    .sort((a, b) => Math.abs(pct(now[b], before[b])) - Math.abs(pct(now[a], before[a])));
  for (const a of moves.slice(0, 2)) {
    const p = pct(now[a], before[a]);
    out.push(`${APP_NAMES[a]} page views ${p > 0 ? "up" : "down"} ${Math.abs(p)}% on last week (${now[a]} vs ${before[a]}).`);
  }
  for (const a of Object.keys(now)) if (now[a] >= 10 && before[a] === 0) out.push(`${APP_NAMES[a]} pages got ${now[a]} views this week, up from none.`);
  if (uniquesLast > 0 && uniquesThis !== uniquesLast) {
    const p = pct(uniquesThis, uniquesLast);
    out.push(`${uniquesThis} consented visitors this week, ${p > 0 ? "up" : "down"} ${Math.abs(p)}% on last week.`);
  } else if (uniquesThis > 0 && uniquesLast === 0) {
    out.push(`${uniquesThis} consented visitors this week.`);
  }
  if (messagesThis || signupsThis) {
    const parts = [];
    if (messagesThis) parts.push(`${messagesThis} new message${messagesThis === 1 ? "" : "s"}`);
    if (signupsThis) parts.push(`${signupsThis} new signup${signupsThis === 1 ? "" : "s"}`);
    out.push(`${parts.join(" and ")} this week.`);
  }
  const c = consentThis || { accept: 0, reject: 0, custom: 0 };
  const decided = c.accept + c.reject + c.custom;
  if (decided >= 5) out.push(`${Math.round((c.accept / decided) * 100)}% of visitors who answered the cookie banner accepted (${c.accept} of ${decided}).`);
  const top = Object.entries(thisWeek?.ref || {}).sort((a, b) => b[1] - a[1])[0];
  if (top && top[1] >= 3) out.push(`Top referrer: ${top[0]} (${top[1]} visits).`);
  return out.slice(0, 5);
}
