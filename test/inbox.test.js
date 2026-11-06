import { test } from "node:test";
import assert from "node:assert/strict";
import { FakeKV } from "./fake-kv.js";
import { saveMessage, markReplied, saveSignup, listMessages, listSignups, countSince } from "../src/inbox.js";

test("messages are stored newest first and can be marked replied", async () => {
  const kv = new FakeKV();
  await saveMessage(kv, { name: "A", email: "a@x.co", message: "one", category: "safe", now: new Date("2026-11-01T10:00:00Z") });
  const k2 = await saveMessage(kv, { name: "B", email: "b@x.co", message: "two", category: "flagged", now: new Date("2026-11-03T10:00:00Z") });
  await saveMessage(kv, { name: "C", email: "c@x.co", message: "x".repeat(5000), category: "safe", now: new Date("2026-11-02T10:00:00Z") });
  const list = await listMessages(kv);
  assert.deepEqual(list.map((m) => m.name), ["B", "C", "A"]);
  assert.equal(list[1].message.length, 2000);
  assert.equal(list[0].replied, false);
  await markReplied(kv, k2);
  assert.equal((await listMessages(kv))[0].replied, true);
  assert.equal(countSince(list, "2026-11-02"), 2);
});

test("signups are validated, lowercased and idempotent", async () => {
  const kv = new FakeKV();
  assert.equal(await saveSignup(kv, "A@B.co"), "ok");
  assert.equal(await saveSignup(kv, "a@b.co"), "ok");
  assert.equal(await saveSignup(kv, "nope"), "invalid");
  assert.equal(await saveSignup(kv, 42), "invalid");
  await saveSignup(kv, "c@d.co");
  await saveSignup(kv, "e@f.co");
  const gets = kv.gets;
  const s = await listSignups(kv);
  assert.equal(kv.gets, gets, "listing signups does no per-key reads");
  assert.equal(s.length, 3);
  assert.ok(s.every((x) => x.at));
  assert.ok(s.some((x) => x.email === "a@b.co"));
});
