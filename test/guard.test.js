import { test } from "node:test";
import assert from "node:assert/strict";
import { FakeKV } from "./fake-kv.js";
import { rateLimit, allowedOrigin, cleanName, isEmail } from "../src/guard.js";

const req = (headers = {}) => new Request("https://www.tinybirdbigdreams.com/x", { method: "POST", headers });

test("rateLimit allows up to the limit per client per window", async () => {
  const kv = new FakeKV();
  const r = req({ "cf-connecting-ip": "203.0.113.9" });
  const now = new Date("2026-11-06T15:00:00Z");
  for (let i = 0; i < 3; i++) assert.equal(await rateLimit(kv, r, "contact", 3, 3600, now), true);
  assert.equal(await rateLimit(kv, r, "contact", 3, 3600, now), false);
  assert.equal(await rateLimit(kv, req({ "cf-connecting-ip": "198.51.100.1" }), "contact", 3, 3600, now), true);
  assert.equal(await rateLimit(kv, r, "contact", 3, 3600, new Date("2026-11-06T16:00:01Z")), true);
  assert.ok(![...kv.map.keys()].some((k) => k.includes("203.0.113.9")), "IP must be hashed, never stored");
});

test("allowedOrigin accepts our site and local dev only", () => {
  assert.equal(allowedOrigin(req({ origin: "https://www.tinybirdbigdreams.com" })), true);
  assert.equal(allowedOrigin(req({ origin: "https://tinybirdbigdreams.com" })), true);
  assert.equal(allowedOrigin(req({ origin: "http://localhost:8787" })), true);
  assert.equal(allowedOrigin(req({ origin: "https://evil.example" })), false);
  assert.equal(allowedOrigin(req({})), true, "sendBeacon without Origin from same-site is allowed");
  assert.equal(allowedOrigin(req({ referer: "https://evil.example/page" })), false);
});

test("cleanName strips header-breaking characters", () => {
  assert.equal(cleanName('Eve <x@y>, "Bob"\r\nBcc: z'), "Eve xy Bob Bcc z");
  assert.equal(cleanName("x".repeat(300)).length, 80);
});

test("isEmail", () => {
  assert.ok(isEmail("a@b.co"));
  assert.ok(!isEmail("a@b"));
  assert.ok(!isEmail("a b@c.co"));
  assert.ok(!isEmail("x".repeat(250) + "@b.co"));
});
