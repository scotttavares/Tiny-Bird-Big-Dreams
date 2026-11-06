import { test } from "node:test";
import assert from "node:assert/strict";
import { FakeKV } from "./fake-kv.js";
import {
  sanitizeBatch, dayKey, weekStart, recordBatch, recordConsent,
  readRange, countUniques, appOf, highlights, isValidVid,
} from "../src/analytics.js";

const VID = "0f8fad5b-d9cb-469f-a165-70867728950e";
const VID2 = "7c9e6679-7425-40de-944b-e07fc1f90ae7";
const NOW = new Date("2026-11-06T15:00:00Z"); // a Friday

test("sanitizeBatch rejects junk bodies", () => {
  for (const b of [null, "str", 42, { events: "x" }, []]) {
    assert.deepEqual(sanitizeBatch(b), { vid: null, events: [] });
  }
});

test("sanitizeBatch whitelists, truncates and caps", () => {
  const many = Array.from({ length: 200 }, () => ({ t: "pv", p: "/" }));
  assert.equal(sanitizeBatch({ events: many }).events.length, 50);
  const r = sanitizeBatch({
    vid: "abc",
    events: [{ t: "evil" }, { t: "toy", v: "x".repeat(500) }, { t: "pv", p: "http://x" }, { t: "pv", p: 5 }, { t: "egg", v: "hummingbird" }],
  });
  assert.equal(r.vid, null);
  assert.equal(r.events.length, 2);
  assert.equal(r.events[0].v.length, 80);
  assert.equal(r.events[1].t, "egg");
  assert.equal(sanitizeBatch({ vid: VID, events: [] }).vid, VID);
  const paths = sanitizeBatch({ events: [{ t: "pv", p: "/paperwars.html" }, { t: "pv", p: "/index.html" }, { t: "pv", p: "/play/paperwars/" }, { t: "pv", p: "/orbit?x=1" }] }).events.map((e) => e.p);
  assert.deepEqual(paths, ["/paperwars", "/", "/play/paperwars", "/orbit"]);
  assert.ok(isValidVid(VID));
});

test("dayKey and weekStart use UTC Monday weeks", () => {
  assert.equal(dayKey(NOW), "2026-11-06");
  assert.equal(weekStart(NOW), "2026-11-02");
  assert.equal(weekStart(new Date("2026-11-02T00:00:00Z")), "2026-11-02");
  assert.equal(weekStart(new Date("2026-11-08T23:59:00Z")), "2026-11-02");
});

test("recordBatch aggregates page views, referrers and devices", async () => {
  const kv = new FakeKV();
  const iphone = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)";
  await recordBatch(kv, sanitizeBatch({ events: [{ t: "pv", p: "/paperwars" }] }), { referrer: "https://www.google.com/search?q=x", ua: iphone, now: NOW });
  await recordBatch(kv, sanitizeBatch({ events: [{ t: "pv", p: "/paperwars" }, { t: "scroll", v: "75" }, { t: "out", v: "appstore:6783862542" }] }), { referrer: "https://www.tinybirdbigdreams.com/", ua: "Mozilla/5.0 (Windows NT 10.0)", now: NOW });
  const d = await kv.get("d:2026-11-06", { type: "json" });
  assert.equal(d.pv["/paperwars"], 2);
  assert.equal(d.ref["www.google.com"], 1);
  assert.equal(Object.keys(d.ref).length, 1);
  assert.equal(d.dev.mobile, 1);
  assert.equal(d.dev.desktop, 1);
  assert.equal(d.scroll["75"], 1);
  assert.equal(d.out["appstore:6783862542"], 1);
});

test("countUniques counts distinct consented visitors per week", async () => {
  const kv = new FakeKV();
  for (const vid of [VID, VID2, VID]) {
    await recordBatch(kv, sanitizeBatch({ vid, events: [{ t: "pv", p: "/" }] }), { now: NOW });
  }
  await recordBatch(kv, sanitizeBatch({ events: [{ t: "pv", p: "/" }] }), { now: NOW });
  assert.equal(await countUniques(kv, "2026-11-02"), 2);
  assert.equal(await countUniques(kv, "2026-10-26"), 0);
});

test("recordBatch caps distinct keys and writes each weekly visitor once", async () => {
  const kv = new FakeKV();
  for (let i = 0; i < 7; i++) {
    const events = Array.from({ length: 50 }, (_, j) => ({ t: "pv", p: `/junk-${i}-${j}` }));
    await recordBatch(kv, { vid: VID, events }, { now: NOW });
  }
  const d = await kv.get("d:2026-11-06", { type: "json" });
  assert.equal(Object.keys(d.pv).length, 301);
  assert.equal(d.pv["(other)"], 50);
  const before = kv.puts;
  await recordBatch(kv, { vid: VID, events: [{ t: "pv", p: "/" }] }, { now: NOW });
  assert.equal(kv.puts - before, 1, "only the day key is rewritten for a known visitor");
});

test("recordConsent tallies choices and ignores junk", async () => {
  const kv = new FakeKV();
  await recordConsent(kv, "accept", NOW);
  await recordConsent(kv, "accept", NOW);
  await recordConsent(kv, "reject", NOW);
  await recordConsent(kv, "nope", NOW);
  assert.deepEqual(await kv.get("c:2026-11-06", { type: "json" }), { accept: 2, reject: 1, custom: 0 });
});

test("readRange sums days", async () => {
  const kv = new FakeKV();
  await recordBatch(kv, sanitizeBatch({ events: [{ t: "pv", p: "/" }] }), { now: new Date("2026-11-05T10:00:00Z") });
  await recordBatch(kv, sanitizeBatch({ events: [{ t: "pv", p: "/" }, { t: "pick", v: "calm" }] }), { now: NOW });
  const r = await readRange(kv, ["2026-11-05", "2026-11-06", "2026-11-07"]);
  assert.equal(r.pv["/"], 2);
  assert.equal(r.pick.calm, 1);
});

test("appOf maps paths to apps", () => {
  assert.equal(appOf("/orbit-support"), "orbit");
  assert.equal(appOf("/paperwars"), "paperwars");
  assert.equal(appOf("/fieldguide-privacy.html"), "fieldguide");
  assert.equal(appOf("/"), null);
});

test("highlights call out big moves", () => {
  const h = highlights({
    thisWeek: { pv: { "/paperwars": 40, "/": 10 }, ref: { "www.google.com": 7 } },
    lastWeek: { pv: { "/paperwars": 20, "/": 10 }, ref: {} },
    uniquesThis: 30, uniquesLast: 20,
    consentThis: { accept: 6, reject: 4, custom: 0 },
    messagesThis: 3, signupsThis: 0,
  });
  assert.ok(h.length <= 5);
  assert.ok(h.some((s) => s.includes("Paper Wars") && s.includes("100%")), h.join(" | "));
  assert.ok(h.some((s) => s.includes("60%")), "consent rate");
  assert.ok(h.some((s) => s.includes("3 new messages")));
});
