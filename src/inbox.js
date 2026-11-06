// Contact-form messages and "notify me" signups.
// These are direct requests from the visitor, not analytics, so they are stored
// whether or not the visitor accepted cookies.
//   msg:{ISO time}:{rand}   {name, email, message, category, replied, at}
//   signup:{email}          {at}

const MSG_TTL = 730 * 24 * 3600;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function listPrefix(kv, prefix) {
  const names = [];
  let cursor;
  do {
    const page = await kv.list({ prefix, cursor });
    names.push(...page.keys.map((k) => k.name));
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return names;
}

export async function saveMessage(kv, { name = "", email = "", message = "", category = "safe", now = new Date() }) {
  const rand = Math.floor(Math.random() * 0xffff).toString(16).padStart(4, "0");
  const key = `msg:${now.toISOString()}:${rand}`;
  const rec = {
    name: String(name).slice(0, 200), email: String(email).slice(0, 200),
    message: String(message).slice(0, 2000), category, replied: false, at: now.toISOString(),
  };
  await kv.put(key, JSON.stringify(rec), { expirationTtl: MSG_TTL });
  return key;
}

export async function markReplied(kv, key) {
  const rec = await kv.get(key, { type: "json" });
  if (!rec) return;
  rec.replied = true;
  await kv.put(key, JSON.stringify(rec), { expirationTtl: MSG_TTL });
}

export async function saveSignup(kv, email, now = new Date()) {
  if (typeof email !== "string") return "invalid";
  const e = email.trim().toLowerCase();
  if (e.length > 200 || !EMAIL_RE.test(e)) return "invalid";
  const key = `signup:${e}`;
  if (!(await kv.get(key))) await kv.put(key, JSON.stringify({ at: now.toISOString() }));
  return "ok";
}

export async function listMessages(kv, limit = 50) {
  const names = (await listPrefix(kv, "msg:")).sort().reverse().slice(0, limit);
  const recs = await Promise.all(names.map(async (k) => ({ key: k, ...(await kv.get(k, { type: "json" })) })));
  return recs.filter((r) => r.at);
}

export async function listSignups(kv) {
  const names = await listPrefix(kv, "signup:");
  const recs = await Promise.all(names.map(async (k) => ({ email: k.slice(7), ...((await kv.get(k, { type: "json" })) || {}) })));
  return recs.sort((a, b) => String(b.at).localeCompare(String(a.at)));
}

export function countSince(items, isoDate) {
  return items.filter((i) => String(i.at) >= isoDate).length;
}
