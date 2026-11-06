import { test } from "node:test";
import assert from "node:assert/strict";
import { FakeKV } from "./fake-kv.js";
import { recordBatch, recordConsent, sanitizeBatch } from "../src/analytics.js";
import { saveMessage, saveSignup } from "../src/inbox.js";
import { collectStudio, renderStudio, studioCsv, loginHTML } from "../src/studio.js";

const NOW = new Date("2026-11-06T15:00:00Z");
const VID = "0f8fad5b-d9cb-469f-a165-70867728950e";

async function seeded() {
  const kv = new FakeKV();
  await recordBatch(kv, sanitizeBatch({ vid: VID, events: [{ t: "pv", p: "/paperwars" }, { t: "pv", p: "/orbit" }, { t: "out", v: "appstore:6785966852" }, { t: "pick", v: "calm" }, { t: "toy", v: "lull" }] }), { now: NOW, referrer: "https://www.google.com/" });
  await recordBatch(kv, sanitizeBatch({ events: [{ t: "pv", p: "/paperwars" }] }), { now: new Date("2026-10-28T12:00:00Z") });
  await recordConsent(kv, "accept", NOW);
  await recordConsent(kv, "reject", NOW);
  await saveMessage(kv, { name: "<script>x</script>", email: "a@b.co", message: "hi", category: "safe", now: NOW });
  await saveSignup(kv, "fan@b.co", NOW);
  return kv;
}

test("collectStudio builds this week vs last week", async () => {
  const s = await collectStudio({ VISITORS: await seeded() }, NOW);
  assert.equal(s.uniquesThis, 1);
  assert.equal(s.pvThis, 2);
  assert.equal(s.pvLast, 1);
  assert.equal(s.perApp.find((a) => a.app === "paperwars").pv, 1);
  assert.equal(s.perApp.find((a) => a.app === "paperwars").weeks.length, 7);
  assert.deepEqual(s.consent.this, { accept: 1, reject: 1, custom: 0 });
  assert.equal(s.messagesThis, 1);
  assert.equal(s.signupsThis, 1);
  assert.equal(s.outbound, 1);
  assert.equal(s.cfTotal, null);
});

test("renderStudio shows every section and escapes input", async () => {
  const s = await collectStudio({ VISITORS: await seeded() }, NOW);
  const html = renderStudio(s);
  for (const label of ["What's important to know", "Visitors per app", "Lull", "Orbit", "Paper Wars", "Field Guide", "Cookies", "Consented visitors only", "What they did", "Emails", "Signups"]) {
    assert.ok(html.includes(label), label);
  }
  for (const h of s.highlights) assert.ok(html.includes(h.replace(/&/g, "&amp;")), h);
  assert.ok(!html.includes("<script>x</script>"));
  assert.ok(html.includes("&lt;script&gt;x&lt;/script&gt;"));
});

test("renderStudio works with an empty KV", async () => {
  const s = await collectStudio({ VISITORS: new FakeKV() }, NOW);
  assert.ok(renderStudio(s).includes("Visitors per app"));
});

test("studioCsv starts with a header row", async () => {
  const s = await collectStudio({ VISITORS: await seeded() }, NOW);
  const first = studioCsv(s).split("\n")[0];
  assert.match(first, /^section,metric,/);
});

test("loginHTML shows the error state", () => {
  assert.ok(loginHTML({ error: true, configured: true }).includes("Wrong password"));
});
