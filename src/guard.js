// Abuse protection for the public POST endpoints.
// Rate limits key on a salted SHA-256 of the client IP (never the IP itself),
// stored for at most one window.

const OK_HOSTS = new Set(["tinybirdbigdreams.com", "www.tinybirdbigdreams.com", "localhost", "127.0.0.1"]);
const EMAIL_RE = /^[^\s@<>,;"]+@[^\s@<>,;"]+\.[^\s@<>,;"]+$/;

export function isEmail(s) {
  return typeof s === "string" && s.length <= 200 && EMAIL_RE.test(s.trim());
}

export function cleanName(s) {
  return String(s ?? "").replace(/[\r\n\t]/g, " ").replace(/[<>,;:"@]/g, "").replace(/\s+/g, " ").trim().slice(0, 80);
}

function hostOf(u) {
  try { return new URL(u).hostname; } catch { return null; }
}

// Browsers send Origin on cross-site POSTs (and on fetch/sendBeacon); when it is
// present it must be ours. Without Origin we fall back to Referer if present.
export function allowedOrigin(request) {
  const o = request.headers.get("origin");
  if (o) return OK_HOSTS.has(hostOf(o));
  const r = request.headers.get("referer");
  if (r) return OK_HOSTS.has(hostOf(r));
  return true;
}

async function sha(s) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].slice(0, 12).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function rateLimit(kv, request, bucket, limit, windowSec, now = new Date()) {
  if (!kv) return true;
  const ip = request.headers.get("cf-connecting-ip") || request.headers.get("x-forwarded-for") || "unknown";
  const win = Math.floor(now.getTime() / 1000 / windowSec);
  const key = `rl:${bucket}:${await sha(`tb:${bucket}:${ip}`)}:${win}`;
  const n = Number((await kv.get(key)) || 0);
  if (n >= limit) return false;
  await kv.put(key, String(n + 1), { expirationTtl: Math.max(60, windowSec + 60) });
  return true;
}
