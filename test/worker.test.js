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
  assert.equal(kv.map.size, 0);
});

test("POST /consent tallies valid choices only", async () => {
  const { kv, call } = setup();
  assert.equal((await call("/consent", postJSON({ choice: "reject" }))).status, 204);
  assert.equal((await call("/consent", postJSON({ choice: "x" }))).status, 204);
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

test("GET / is served as a static asset", async () => {
  const { call } = setup();
  const r = await call("/");
  assert.equal(await r.text(), "static");
});
