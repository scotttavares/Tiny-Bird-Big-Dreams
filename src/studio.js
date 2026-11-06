// /studio: the private dashboard. Answers the Monday-morning questions:
// how many visitors, what they did, what's important, emails submitted,
// visitors per app, and cookies accepted vs declined.

import {
  APP_NAMES, weekStart, daysOfWeek, readRange, readConsent, countUniques,
  pvByApp, totalPv, highlights,
} from "./analytics.js";
import { listMessages, listSignups, countSince } from "./inbox.js";
import { cfTraffic } from "./cf.js";

const WEEKS = 7;
const esc = (s) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const fmt = (n) => (n ?? 0).toLocaleString("en-US");
const sumObj = (o) => Object.values(o || {}).reduce((a, b) => a + b, 0);
const top = (o, n = 8) => Object.entries(o || {}).sort((a, b) => b[1] - a[1]).slice(0, n);

export async function collectStudio(env, now = new Date()) {
  const kv = env.VISITORS;
  const w0 = weekStart(now);
  const starts = Array.from({ length: WEEKS }, (_, i) => weekStart(new Date(new Date(w0 + "T00:00:00Z").getTime() - (WEEKS - 1 - i) * 7 * 86400000)));
  const weekAggs = await Promise.all(starts.map((s) => readRange(kv, daysOfWeek(s))));
  const weekUniques = await Promise.all(starts.map((s) => countUniques(kv, s)));
  const thisWeek = weekAggs[WEEKS - 1], lastWeek = weekAggs[WEEKS - 2];
  const [consentThis, consentLast, messages, signups] = await Promise.all([
    readConsent(kv, daysOfWeek(starts[WEEKS - 1])),
    readConsent(kv, daysOfWeek(starts[WEEKS - 2])),
    listMessages(kv, 50),
    listSignups(kv),
  ]);
  const perApp = Object.keys(APP_NAMES).map((app) => ({
    app, name: APP_NAMES[app],
    pv: pvByApp(thisWeek)[app], pvLast: pvByApp(lastWeek)[app],
    weeks: weekAggs.map((a) => pvByApp(a)[app]),
  }));
  const playClicks = (thisWeek.out["play:paperwars"] || 0);
  const outbound = sumObj(thisWeek.out);
  const messagesThis = countSince(messages, w0);
  const signupsThis = countSince(signups, w0);
  const uniquesThis = weekUniques[WEEKS - 1], uniquesLast = weekUniques[WEEKS - 2];

  let cfTotal = null;
  if (env.CF_ANALYTICS_TOKEN) {
    try {
      const t = await cfTraffic(env.CF_TBBD_BEACON, "tinybirdbigdreams.com", env);
      cfTotal = t?.totals?.d7?.visitors ?? null;
    } catch { cfTotal = null; }
  }

  return {
    asOf: now.toISOString(), weekStart: w0,
    thisWeek, lastWeek, uniquesThis, uniquesLast,
    pvThis: totalPv(thisWeek), pvLast: totalPv(lastWeek),
    weeks: starts.map((s, i) => ({ start: s, pv: totalPv(weekAggs[i]), uniques: weekUniques[i] })),
    perApp, playClicks, outbound,
    consent: { this: consentThis, last: consentLast },
    messages, signups, messagesThis, signupsThis, cfTotal,
    highlights: highlights({ thisWeek, lastWeek, uniquesThis, uniquesLast, consentThis, messagesThis, signupsThis }),
  };
}

/* ------------------------------- views ------------------------------- */

const FONTS = `<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Inter+Tight:wght@400;500;600;700&display=swap" rel="stylesheet"/>`;
const CSS = `
*{box-sizing:border-box;margin:0;padding:0}
:root{--paper:#f6f1e8;--ink:#17130e;--muted:#7a6f60;--gold:#E8A022;--card:#fff;--line:#e7dfd0;--up:#2f7a4a;--down:#b5452f}
body{font-family:"Inter Tight",system-ui,sans-serif;background:var(--paper);color:var(--ink);-webkit-font-smoothing:antialiased}
.serif{font-family:"Instrument Serif",serif;font-weight:400}
a{color:inherit}
header{display:flex;justify-content:space-between;align-items:center;gap:16px;padding:22px 4vw;flex-wrap:wrap}
header .b{display:flex;align-items:center;gap:10px;font-weight:600}
header nav a{font-size:13px;margin-left:16px;color:var(--muted)}
main{max-width:1180px;margin:0 auto;padding:10px 4vw 60px}
h1{font-size:clamp(40px,6vw,72px);line-height:1;letter-spacing:-.02em}
h2{font-size:30px;margin:46px 0 14px;letter-spacing:-.01em}
.sub{color:var(--muted);margin-top:8px;font-size:14px}
.hl{margin-top:26px;background:var(--ink);color:#fff;border-radius:24px;padding:22px 26px}
.hl h2{margin:0 0 10px;font-size:26px;color:var(--gold)}
.hl li{margin:8px 0 0 18px;line-height:1.5}
.grid{display:grid;gap:14px}
.k{grid-template-columns:repeat(auto-fit,minmax(170px,1fr));margin-top:22px}
.card{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:18px 20px}
.card .n{font-family:"Instrument Serif";font-size:48px;line-height:1}
.card .l{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin-top:6px}
.card .d{font-size:13px;margin-top:6px;color:var(--muted)}
.up{color:var(--up)}.down{color:var(--down)}
.apps{grid-template-columns:repeat(auto-fit,minmax(240px,1fr))}
.app h3{font-size:18px}.app .n{font-size:40px}
svg.sp{width:100%;height:46px;margin-top:10px}
.two{grid-template-columns:repeat(auto-fit,minmax(300px,1fr))}
table{width:100%;border-collapse:collapse;font-size:14px}
td,th{text-align:left;padding:8px 6px;border-bottom:1px solid var(--line);vertical-align:top}
th{font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);font-weight:600}
td.r{text-align:right;font-variant-numeric:tabular-nums}
.tag{display:inline-block;font-size:11px;font-weight:600;padding:3px 8px;border-radius:99px;background:#eee}
.tag.ok{background:#e3f1e7;color:var(--up)}.tag.fl{background:#fbe5df;color:var(--down)}.tag.wait{background:#fdf0d9;color:#8a5a00}
.empty{color:var(--muted);font-size:14px;padding:6px 0}
.foot{margin-top:40px;color:var(--muted);font-size:13px;line-height:1.6}
`;

function delta(now, before) {
  if (!before) return now ? `<span class="up">new</span>` : "";
  const p = Math.round(((now - before) / before) * 100);
  if (!p) return `flat on last week`;
  return `<span class="${p > 0 ? "up" : "down"}">${p > 0 ? "▲" : "▼"} ${Math.abs(p)}%</span> vs last week (${fmt(before)})`;
}
function card(n, label, d = "") {
  return `<div class="card"><div class="n">${n}</div><div class="l">${esc(label)}</div>${d ? `<div class="d">${d}</div>` : ""}</div>`;
}
function sparkline(values) {
  const max = Math.max(1, ...values), w = 200, h = 40, step = w / Math.max(1, values.length - 1);
  const pts = values.map((v, i) => `${(i * step).toFixed(1)},${(h - (v / max) * (h - 4) - 2).toFixed(1)}`).join(" ");
  return `<svg class="sp" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" aria-hidden="true"><polyline points="${pts}" fill="none" stroke="#E8A022" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/></svg>`;
}
function table(title, rows, cols = ["", "Count"]) {
  const body = rows.length
    ? rows.map(([k, v]) => `<tr><td>${esc(k)}</td><td class="r">${fmt(v)}</td></tr>`).join("")
    : `<tr><td colspan="2" class="empty">Nothing yet.</td></tr>`;
  return `<div class="card"><h3 style="font-size:16px;margin-bottom:8px">${esc(title)}</h3><table><tr><th>${cols[0]}</th><th style="text-align:right">${cols[1]}</th></tr>${body}</table></div>`;
}
const pick = (o, map) => top(o).map(([k, v]) => [map?.[k] || k, v]);
const SCROLL = { 25: "Reached 25%", 50: "Reached 50%", 75: "Reached 75%", 100: "Reached the end" };

export function renderStudio(s) {
  const c = s.consent.this, decided = c.accept + c.reject + c.custom;
  const rate = decided ? Math.round((c.accept / decided) * 100) : 0;
  const hl = s.highlights.length ? s.highlights.map((h) => `<li>${esc(h)}</li>`).join("") : `<li>Quiet week so far. Highlights appear once there's enough data.</li>`;
  const apps = s.perApp.map((a) => `<div class="card app"><h3>${esc(a.name)}</h3><div class="n serif">${fmt(a.pv)}</div><div class="l" style="font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)">page views this week</div><div class="d" style="font-size:13px;margin-top:4px;color:var(--muted)">${delta(a.pv, a.pvLast)}</div>${a.app === "paperwars" ? `<div class="d" style="font-size:13px;margin-top:4px">${fmt(s.playClicks)} "Play" clicks</div>` : ""}${sparkline(a.weeks)}</div>`).join("");
  const msgs = s.messages.length
    ? s.messages.slice(0, 20).map((m) => `<tr><td>${esc(String(m.at).slice(0, 10))}</td><td>${esc(m.name)}<br/><a href="mailto:${esc(m.email)}">${esc(m.email)}</a></td><td>${esc(String(m.message).slice(0, 140))}</td><td>${m.category === "flagged" ? `<span class="tag fl">needs review</span>` : m.replied ? `<span class="tag ok">replied</span>` : `<span class="tag wait">not replied</span>`}</td></tr>`).join("")
    : `<tr><td colspan="4" class="empty">No messages yet.</td></tr>`;
  const sups = s.signups.length
    ? s.signups.slice(0, 30).map((u) => `<tr><td>${esc(u.email)}</td><td class="r">${esc(String(u.at).slice(0, 10))}</td></tr>`).join("")
    : `<tr><td colspan="2" class="empty">No signups yet.</td></tr>`;

  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><meta name="robots" content="noindex,nofollow"/>
<title>Tiny Bird Studio</title>${FONTS}<style>${CSS}</style></head><body>
<header><div class="b">🐦 Tiny Bird Studio</div><nav><a href="/studio/export.csv">Export CSV</a><a href="/">View site</a><a href="/studio/logout">Sign out</a></nav></header>
<main>
<h1 class="serif">This week</h1>
<p class="sub">Week starting ${esc(s.weekStart)} (Monday, UTC) · updated ${esc(s.asOf.slice(0, 16).replace("T", " "))} UTC</p>

<section class="hl"><h2 class="serif">What's important to know</h2><ul>${hl}</ul></section>

<div class="grid k">
${card(fmt(s.uniquesThis), "Visitors", delta(s.uniquesThis, s.uniquesLast))}
${card(fmt(s.pvThis), "Page views", delta(s.pvThis, s.pvLast))}
${card(fmt(s.messagesThis), "Emails submitted", `${fmt(s.messages.length)} in the inbox`)}
${card(fmt(s.signupsThis), "Signups", `${fmt(s.signups.length)} on the list`)}
${card(fmt(s.outbound), "Clicks to App Store, TestFlight & Play")}
${card(`${rate}%`, "Cookies accepted", `${fmt(c.accept)} accepted · ${fmt(c.reject)} declined${c.custom ? ` · ${fmt(c.custom)} custom` : ""}`)}
</div>

<h2 class="serif">Visitors per app</h2>
<div class="grid apps">${apps}</div>

<h2 class="serif">What they did</h2>
<div class="grid two">
${table("Top pages", top(s.thisWeek.pv), ["Page", "Views"])}
${table("Where they came from", top(s.thisWeek.ref), ["Site", "Visits"])}
${table("Devices", top(s.thisWeek.dev), ["Device", "Visits"])}
${table("How far they scrolled", pick(s.thisWeek.scroll, SCROLL), ["Depth", "Pages"])}
${table("Outbound clicks", top(s.thisWeek.out), ["Link", "Clicks"])}
${table("\"What brings you here?\" picks", top(s.thisWeek.pick), ["Choice", "Picks"])}
${table("Toys played", top(s.thisWeek.toy), ["Toy", "Plays"])}
${table("Shop clicks", top(s.thisWeek.shop), ["Item", "Clicks"])}
</div>

<h2 class="serif">Emails</h2>
<div class="card"><table><tr><th>Date</th><th>From</th><th>Message</th><th>Status</th></tr>${msgs}</table></div>

<h2 class="serif">Signups</h2>
<div class="card"><table><tr><th>Email</th><th style="text-align:right">Joined</th></tr>${sups}</table></div>

<p class="foot">Consented visitors only: people who decline cookies aren't counted (except the anonymous accept/decline tally), so real traffic is higher than these numbers.${s.cfTotal != null ? ` Cloudflare total this week (all visitors, cross-check): ${fmt(s.cfTotal)}.` : ""}${s.thisWeek.egg?.hummingbird ? ` 🐦 ${fmt(s.thisWeek.egg.hummingbird)} people found the hummingbird easter egg.` : ""}</p>
</main></body></html>`;
}

const csvCell = (v) => { const t = String(v ?? ""); return /[",\n]/.test(t) ? `"${t.replace(/"/g, '""')}"` : t; };
export function studioCsv(s) {
  const rows = [["section", "metric", "this_week", "last_week"]];
  rows.push(["totals", "visitors", s.uniquesThis, s.uniquesLast], ["totals", "page_views", s.pvThis, s.pvLast]);
  rows.push(["totals", "emails_submitted", s.messagesThis, ""], ["totals", "signups", s.signupsThis, ""]);
  rows.push(["consent", "accepted", s.consent.this.accept, s.consent.last.accept], ["consent", "declined", s.consent.this.reject, s.consent.last.reject], ["consent", "custom", s.consent.this.custom, s.consent.last.custom]);
  for (const a of s.perApp) rows.push(["app", a.name, a.pv, a.pvLast]);
  for (const w of s.weeks) rows.push(["week", w.start, w.pv, w.uniques]);
  for (const [k, v] of top(s.thisWeek.pv, 50)) rows.push(["page", k, v, s.lastWeek.pv[k] || 0]);
  for (const [k, v] of top(s.thisWeek.ref, 50)) rows.push(["referrer", k, v, s.lastWeek.ref[k] || 0]);
  rows.push([], ["signups", "email", "joined", ""]);
  for (const u of s.signups) rows.push(["signup", u.email, String(u.at).slice(0, 10), ""]);
  rows.push([], ["messages", "date", "name", "email", "status", "message"]);
  for (const m of s.messages) rows.push(["message", String(m.at).slice(0, 10), m.name, m.email, m.category === "flagged" ? "needs review" : m.replied ? "replied" : "not replied", m.message]);
  return rows.map((r) => r.map(csvCell).join(",")).join("\n") + "\n";
}

export function loginHTML({ error, configured }) {
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><meta name="robots" content="noindex,nofollow"/>
<title>Tiny Bird Studio: sign in</title>${FONTS}<style>${CSS}
.wrap{min-height:100vh;display:grid;place-items:center;padding:24px}
form{width:100%;max-width:380px;background:#fff;border:1px solid var(--line);border-radius:24px;padding:36px 30px}
form h1{font-size:44px;margin:14px 0 6px}
label{display:block;font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--muted);margin:22px 0 8px}
input{width:100%;border:1px solid var(--line);border-radius:12px;padding:14px 16px;font:inherit;font-size:15px;outline:none}
input:focus{border-color:var(--gold)}
button{width:100%;margin-top:16px;background:var(--ink);color:#fff;border:none;border-radius:99px;padding:14px;font:inherit;font-weight:600;cursor:pointer}
.err{margin-top:16px;background:#fbe5df;color:var(--down);font-size:13px;padding:10px 14px;border-radius:10px}
</style></head><body><div class="wrap"><form method="POST" action="/studio/login">
<div style="font-size:30px">🐦</div><h1 class="serif">Tiny Bird Studio</h1><p class="sub">Private dashboard.</p>
${error ? `<div class="err">Wrong password. Try again.</div>` : ""}
<label for="pw">Password</label><input id="pw" name="password" type="password" autocomplete="current-password" autofocus required/>
<button type="submit">Enter the studio →</button>
${configured ? "" : `<p class="sub" style="margin-top:14px">The studio password hasn't been set yet. Add the <code>STUDIO_PASSWORD</code> secret, then redeploy.</p>`}
</form></div></body></html>`;
}
