import { test } from "node:test";
import assert from "node:assert/strict";
import { FakeKV } from "./fake-kv.js";
import worker from "../src/worker.js";

function setup() {
  const kv = new FakeKV();
  const waits = [];
  const env = { VISITORS: kv, ASSETS: { fetch: async () => new Response("static", { status: 200 }) } };
  const ctx = { waitUntil: (p) => waits.push(p) };
  const call = async (path, init) => {
    const res = await worker.fetch(new Request("https://www.tinybirdbigdreams.com" + path, init), env, ctx);
    await Promise.all(waits);
    return res;
  };
  return { kv, call };
}
const postJSON = (obj) => ({ method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(obj) });
const keys = (kv, prefix) => [...kv.map.keys()].filter((k) => k.startsWith(prefix));

test("POST /track records a consented page view", async () => {
  const { kv, call } = setup();
  const r = await call("/track", postJSON({ vid: "0f8fad5b-d9cb-469f-a165-70867728950e", ref: "https://news.ycombinator.com/", events: [{ t: "pv", p: "/orbit" }] }));
  assert.equal(r.status, 204);
  const day = keys(kv, "d:");
  assert.equal(day.length, 1);
  const agg = await kv.get(day[0], { type: "json" });
  assert.equal(agg.pv["/orbit"], 1);
  assert.equal(agg.ref["news.ycombinator.com"], 1);
  assert.equal(keys(kv, "uv:").length, 1);
});

test("POST /track with garbage stores nothing", async () => {
  const { kv, call } = setup();
  const r = await call("/track", { method: "POST", headers: { "content-type": "application/json" }, body: "garbage{" });
  assert.equal(r.status, 204);
  assert.equal(keys(kv, "d:").length + keys(kv, "uv:").length, 0);
});

test("POST /consent tallies valid choices only", async () => {
  const { kv, call } = setup();
  assert.equal((await call("/consent", postJSON({ choice: "reject" }))).status, 204);
  assert.equal((await call("/consent", postJSON({ choice: "x" }))).status, 204);
  assert.equal(keys(kv, "c:").length, 1);
  const c = await kv.get(keys(kv, "c:")[0], { type: "json" });
  assert.deepEqual(c, { accept: 0, reject: 1, custom: 0 });
});

test("POST /signup validates email", async () => {
  const { kv, call } = setup();
  assert.equal((await call("/signup", postJSON({ email: "bad" }))).status, 400);
  const ok = await call("/signup", postJSON({ email: "Hi@Example.com" }));
  assert.equal(ok.status, 200);
  assert.deepEqual(await ok.json(), { ok: true });
  assert.deepEqual(keys(kv, "signup:"), ["signup:hi@example.com"]);
});

test("contact form without a visitor id is stored", async () => {
  const { kv, call } = setup();
  const fd = new FormData();
  fd.set("name", "Pat"); fd.set("email", "pat@example.com"); fd.set("message", "Love Lull!");
  const r = await call("/email-webhook", { method: "POST", body: fd });
  assert.equal(r.status, 200);
  const m = keys(kv, "msg:");
  assert.equal(m.length, 1);
  const rec = await kv.get(m[0], { type: "json" });
  assert.equal(rec.email, "pat@example.com");
  assert.equal(rec.category, "safe");
});

const contactForm = (extra = {}) => {
  const fd = new FormData();
  fd.set("name", "Pat"); fd.set("email", "pat@example.com"); fd.set("message", "Hi");
  for (const [k, v] of Object.entries(extra)) fd.set(k, v);
  return fd;
};

test("contact form rejects other sites, honeypots, bad emails and floods", async () => {
  const { kv, call } = setup();
  const evil = await call("/email-webhook", { method: "POST", headers: { origin: "https://evil.example" }, body: contactForm() });
  assert.equal(evil.status, 403);
  const bot = await call("/email-webhook", { method: "POST", body: contactForm({ website: "spam.biz" }) });
  assert.equal(bot.status, 200);
  assert.equal(keys(kv, "msg:").length, 0, "honeypot submissions are not stored");
  const bad = await call("/email-webhook", { method: "POST", body: contactForm({ email: "x@y" }) });
  assert.equal(bad.status, 400);
  const statuses = [];
  for (let i = 0; i < 6; i++) statuses.push((await call("/email-webhook", { method: "POST", headers: { "cf-connecting-ip": "203.0.113.5" }, body: contactForm() })).status);
  assert.deepEqual(statuses.slice(-2), [200, 429]);
});

test("unsigned JSON webhook is refused", async () => {
  const { call } = setup();
  const r = await call("/email-webhook", postJSON({ email: "a@b.co", message: "hi" }));
  assert.equal(r.status, 401);
});

test("tracking from another site is ignored", async () => {
  const { kv, call } = setup();
  const init = postJSON({ events: [{ t: "pv", p: "/" }] });
  init.headers.origin = "https://evil.example";
  assert.equal((await call("/track", init)).status, 204);
  assert.equal(keys(kv, "d:").length, 0);
});

test("signup honeypot and cross-site posts", async () => {
  const { kv, call } = setup();
  assert.equal((await call("/signup", postJSON({ email: "a@b.co", website: "x" }))).status, 200);
  assert.equal(keys(kv, "signup:").length, 0);
  const init = postJSON({ email: "a@b.co" });
  init.headers.origin = "https://evil.example";
  assert.equal((await call("/signup", init)).status, 403);
});

test("GET / is served as a static asset", async () => {
  const { call } = setup();
  const r = await call("/");
  assert.equal(await r.text(), "static");
});
