// Tiny Bird, Big Dreams: Cloudflare Worker.
// Everything except the routes below is served straight from static assets.
//
//   POST /track          consented analytics batches (aggregate-only, see analytics.js)
//   POST /consent        anonymous tally of cookie-banner choices
//   POST /signup         "notify me when something hatches" email list
//   POST /email-webhook  contact form: classify, store, auto-reply, alert the team
//   /studio[...]         password-gated dashboard (studio.js)
//   /gazette             gazette.js
//
// Secrets (Cloudflare -> Worker -> Settings -> Variables and secrets):
//   STUDIO_PASSWORD           password for /studio
//   ANTHROPIC_API_KEY         contact-form classifier + auto-reply drafts
//   RESEND_API_KEY            sending email
//   FORMSPREE_WEBHOOK_SECRET  optional, legacy JSON webhook signature
//   CF_ANALYTICS_TOKEN, CF_ACCOUNT_ID, CF_TBBD_ZONE_TAG, CF_TBBD_BEACON  Cloudflare traffic total on /studio

import { handleGazette } from "./gazette.js";
import { sanitizeBatch, recordBatch, recordConsent } from "./analytics.js";
import { saveMessage, markReplied, saveSignup } from "./inbox.js";
import { rateLimit, allowedOrigin, cleanName, isEmail } from "./guard.js";
import { collectStudio, renderStudio, studioCsv, loginHTML } from "./studio.js";

const SESSION_COOKIE = "tbbd_studio";
const SESSION_TTL = 60 * 60 * 24 * 30; // 30 days, in seconds

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });

async function readBody(request) {
  const type = request.headers.get("content-type") || "";
  try {
    if (type.includes("application/json") || type.includes("text/plain")) return JSON.parse(await request.text());
    const fd = await request.formData();
    return Object.fromEntries(fd.entries());
  } catch { return null; }
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const p = url.pathname;
    const post = request.method === "POST";

    if (p === "/gazette" || p === "/gazette/") return handleGazette(request);

    if (p === "/track" && post) {
      if (!allowedOrigin(request) || Number(request.headers.get("content-length") || 0) > 16000) return new Response(null, { status: 204 });
      if (!(await rateLimit(env.VISITORS, request, "track", 120, 3600))) return new Response(null, { status: 204 });
      const body = await readBody(request);
      const batch = sanitizeBatch(body);
      const referrer = typeof body?.ref === "string" ? body.ref : "";
      const work = recordBatch(env.VISITORS, batch, { referrer, ua: request.headers.get("user-agent") || "" })
        .catch((e) => console.error("[track]", e));
      if (ctx) ctx.waitUntil(work); else await work;
      return new Response(null, { status: 204 });
    }

    if (p === "/consent" && post) {
      if (!allowedOrigin(request)) return new Response(null, { status: 204 });
      if (!(await rateLimit(env.VISITORS, request, "consent", 20, 3600))) return new Response(null, { status: 204 });
      const body = await readBody(request);
      const work = recordConsent(env.VISITORS, body?.choice).catch((e) => console.error("[consent]", e));
      if (ctx) ctx.waitUntil(work); else await work;
      return new Response(null, { status: 204 });
    }

    if (p === "/signup" && post) {
      if (!env.VISITORS) return json({ ok: false }, 503);
      if (!allowedOrigin(request)) return json({ ok: false }, 403);
      const body = await readBody(request);
      if (body?.website) return json({ ok: true }); // honeypot
      if (!(await rateLimit(env.VISITORS, request, "signup", 5, 3600))) return json({ ok: false }, 429);
      const r = await saveSignup(env.VISITORS, body?.email);
      return r === "ok" ? json({ ok: true }) : json({ ok: false }, 400);
    }

    if (p === "/studio/login" && post) return handleLogin(request, env);
    if (p === "/studio/logout") return handleLogout();
    if (p === "/studio/export.csv") {
      if (await isAuthed(request, env)) return csvResponse(studioCsv(await collectStudio(env)));
      return new Response(null, { status: 303, headers: { location: "/studio" } });
    }
    if (p === "/studio" || p === "/studio/") {
      if (await isAuthed(request, env)) return html(renderStudio(await collectStudio(env)));
      return html(loginHTML({ error: false, configured: !!env.STUDIO_PASSWORD }), 401);
    }

    if (p === "/email-webhook" && post) return handleEmailWebhook(request, env, ctx);

    return env.ASSETS.fetch(request);
  },
};

function csvResponse(text) {
  const day = new Date().toISOString().slice(0, 10);
  return new Response(text, {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="tiny-bird-studio-${day}.csv"`,
      "cache-control": "no-store",
    },
  });
}

/* ----------------------------- responses ----------------------------- */

function html(body, status = 200, extraHeaders = {}) {
  return new Response(body, {
    status,
    headers: {
      "content-type": "text/html;charset=UTF-8",
      "cache-control": "no-store",
      "x-robots-tag": "noindex, nofollow",
      ...extraHeaders,
    },
  });
}

async function handleLogin(request, env) {
  const pw = env.STUDIO_PASSWORD;
  let attempt = "";
  try {
    const form = await request.formData();
    attempt = form.get("password") || "";
  } catch {
    /* ignore */
  }
  if (!(await rateLimit(env.VISITORS, request, "login", 10, 900))) {
    return html(loginHTML({ error: true, configured: !!pw }), 429);
  }
  if (!pw || !timingSafeEqual(String(attempt), pw)) {
    return html(loginHTML({ error: true, configured: !!pw }), 401);
  }
  const token = await makeToken(env);
  return new Response(null, {
    status: 303,
    headers: {
      "set-cookie": `${SESSION_COOKIE}=${token}; Path=/studio; HttpOnly; Secure; SameSite=Lax; Max-Age=${SESSION_TTL}`,
      location: "/studio",
    },
  });
}

function handleLogout() {
  return new Response(null, {
    status: 303,
    headers: {
      "set-cookie": `${SESSION_COOKIE}=; Path=/studio; HttpOnly; Secure; SameSite=Lax; Max-Age=0`,
      location: "/studio",
    },
  });
}

/* ----------------------------- auth core ----------------------------- */

async function isAuthed(request, env) {
  if (!env.STUDIO_PASSWORD) return false;
  const cookie = request.headers.get("cookie") || "";
  const m = cookie.match(/(?:^|;\s*)tbbd_studio=([^;]+)/);
  if (!m) return false;
  return verifyToken(m[1], env);
}

// token = base64url(exp) "." hexHmac(exp)
async function makeToken(env) {
  const exp = String(Math.floor(Date.now() / 1000) + SESSION_TTL);
  const sig = await hmacHex(exp, env.STUDIO_PASSWORD);
  return `${b64u(exp)}.${sig}`;
}

async function verifyToken(token, env) {
  const parts = token.split(".");
  if (parts.length !== 2) return false;
  let exp;
  try {
    exp = ub64u(parts[0]);
  } catch {
    return false;
  }
  const expNum = parseInt(exp, 10);
  if (!expNum || expNum < Math.floor(Date.now() / 1000)) return false;
  const sig = await hmacHex(exp, env.STUDIO_PASSWORD);
  return timingSafeEqual(sig, parts[1]);
}

async function hmacHex(message, key) {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const buf = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(message));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

function b64u(s) {
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function ub64u(s) {
  return atob(s.replace(/-/g, "+").replace(/_/g, "/"));
}


/* ═══════════════════════════════════════════════════════════════
   EMAIL WEBHOOK — AI Auto-Responder

   Triggered by the site's contact form (direct POST) or a legacy Formspree webhook.

   Required Cloudflare Worker secrets:
     ANTHROPIC_API_KEY       — Anthropic API key (claude-haiku-4-5-20251001)
     RESEND_API_KEY          — Resend.com API key (free tier: 100 emails/day)
     FORMSPREE_WEBHOOK_SECRET — Optional: webhook secret from Formspree dashboard

   Setup:
     1. Resend: sign up at resend.com, verify tinybirdbigdreams.com domain, get API key
     2. Formspree: go to form settings → Webhooks → add https://tinybirdbigdreams.com/email-webhook
     3. Add all three secrets in Cloudflare → Workers → tbbd → Settings → Variables
   ═══════════════════════════════════════════════════════════════ */

async function handleEmailWebhook(request, env, ctx) {
  // Support both direct form POST (multipart/FormData) and legacy Formspree JSON webhook
  const contentType = request.headers.get("content-type") || "";
  let fields;

  if (contentType.includes("application/json")) {
    // Formspree JSON webhook path (kept for legacy / future use)
    // Only accepted when signed: without the secret this path would be an open relay.
    if (!env.FORMSPREE_WEBHOOK_SECRET) return new Response("Unauthorized", { status: 401 });
    const rawBody = await request.text();
    const sig = request.headers.get("X-Formspree-Signature") || "";
    const valid = await verifyHmacSha256(env.FORMSPREE_WEBHOOK_SECRET, rawBody, sig);
    if (!valid) return new Response("Unauthorized", { status: 401 });
    let body;
    try { body = JSON.parse(rawBody); } catch { return new Response("Bad Request", { status: 400 }); }
    fields = body.payload || body.data || body;
  } else {
    // Direct form POST from our own contact form.
    if (!allowedOrigin(request)) return new Response("Forbidden", { status: 403 });
    if (Number(request.headers.get("content-length") || 0) > 20000) return new Response("Too large", { status: 413 });
    try {
      const fd = await request.formData();
      fields = Object.fromEntries(fd.entries());
    } catch { return new Response("Bad Request", { status: 400 }); }
    // Honeypot: real people never fill the hidden "website" field. Pretend success.
    if (fields.website) return new Response("OK", { status: 200 });
    if (!(await rateLimit(env.VISITORS, request, "contact", 5, 3600))) return new Response("Too many messages, try again later", { status: 429 });
  }

  const senderEmail = String(fields.email || fields._replyto || "").trim();
  const senderName  = cleanName(fields.name);
  const message     = String(fields.message || fields.body || "").slice(0, 2000);

  if (senderEmail && !isEmail(senderEmail)) return new Response("Invalid email", { status: 400 });
  if (!senderEmail || !message.trim()) {
    console.log(`[webhook] missing fields — email="${senderEmail}" message="${message?.slice(0,40)}"`);
    return new Response("Missing required fields", { status: 400 });
  }

  // Classify the message before doing anything else.
  // spam   → drop silently (no reply, no team alert)
  // flagged → alert the team only, NO auto-reply (legal, media, abuse, etc.)
  // safe   → proceed with AI auto-reply + team notification
  let classification = { category: "safe", reason: "" };
  try {
    classification = await classifyMessage({ name: senderName, email: senderEmail, message }, env);
  } catch (err) {
    console.error("Classification failed — defaulting to safe:", err);
  }

  console.log(`[webhook] classification=${classification.category} reason=${classification.reason}`);

  if (classification.category === "spam") {
    console.log(`Spam dropped from ${senderEmail}: ${classification.reason}`);
    return new Response("OK", { status: 200 });
  }

  // Store every non-spam message (a direct request, not analytics: kept with or without cookie consent).
  let msgKey = null;
  if (env.VISITORS) {
    try {
      msgKey = await saveMessage(env.VISITORS, { name: senderName, email: senderEmail, message, category: classification.category });
    } catch (err) { console.error("[webhook] saveMessage failed:", err); }
  }

  if (classification.category === "flagged") {
    try {
      await sendEmail({
        to: "hello@tinybirdbigdreams.com",
        toName: "Tiny Bird team",
        subject: `[⚠️ NEEDS REVIEW] Message from ${senderName || senderEmail}`,
        html: teamFlaggedAlertHTML({ senderName, senderEmail, message, reason: classification.reason }),
      }, env);
    } catch (err) {
      console.error("Flagged alert failed:", err);
    }
    return new Response("OK", { status: 200 });
  }

  // Stage 2 (background): generate AI reply, send emails, then flip emailReplied → true.
  // Running in background means the 200 OK reaches Formspree immediately after Stage 1,
  // giving the visitor a visible window to see the "in progress" banner.
  if (ctx) ctx.waitUntil(sendEmailReply({ senderName, senderEmail, message, msgKey }, env));

  return new Response("OK", { status: 200 });
}

async function sendEmailReply({ senderName, senderEmail, message, msgKey }, env) {
  let aiResult;
  try {
    aiResult = await generateAIReply({ name: senderName || "there", email: senderEmail, message }, env);
  } catch (err) {
    console.error("AI reply generation failed:", err);
    return;
  }

  let replySent = false;
  try {
    await sendEmail({
      to: senderEmail,
      toName: senderName,
      subject: "Re: Your message to Tiny Bird, Big Dreams",
      html: aiResult.html,
    }, env);
    replySent = true;
    if (msgKey && env.VISITORS) await markReplied(env.VISITORS, msgKey);
  } catch (err) {
    console.error("Auto-reply send failed:", err);
  }

  try {
    await sendEmail({
      to: "hello@tinybirdbigdreams.com",
      toName: "Tiny Bird team",
      subject: `[AI Replied] Message from ${senderName || senderEmail}`,
      html: teamAlertHTML({ senderName, senderEmail, message, aiReply: aiResult.text }),
    }, env);
  } catch (err) {
    console.error("Team alert failed:", err);
  }
}

// Returns { category: "safe"|"spam"|"flagged", reason: string }
async function classifyMessage({ name, email, message }, env) {
  if (!env.ANTHROPIC_API_KEY) return { category: "safe", reason: "no api key" };

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 80,
      system: `Classify an incoming contact form message for a small indie app studio. Reply with ONLY valid JSON: {"category":"safe"|"spam"|"flagged","reason":"one short sentence"}.

Categories:
- safe: genuine inquiry, feedback, question about the apps, or friendly note
- spam: marketing solicitation, SEO/link-building pitch, unrelated offer, gibberish, or obvious test submission
- flagged: legal threat, DMCA/copyright claim, acquisition or investment inquiry, press/media inquiry, large partnership proposal requiring contract review, harassment or abusive language, data deletion/privacy request (GDPR/CCPA), or anything that could create legal or financial obligation`,
      messages: [{
        role: "user",
        content: `Name: ${name}\nEmail: ${email}\nMessage: ${message.slice(0, 800)}`,
      }],
    }),
  });

  if (!res.ok) throw new Error(`Anthropic classify ${res.status}`);
  const data = await res.json();
  const raw = data.content[0].text.trim();
  try {
    const parsed = JSON.parse(raw);
    if (["safe", "spam", "flagged"].includes(parsed.category)) return parsed;
  } catch { /* fall through */ }
  return { category: "safe", reason: "parse error" };
}

async function generateAIReply({ name, email, message }, env) {
  if (!env.ANTHROPIC_API_KEY) throw new Error("ANTHROPIC_API_KEY not configured");

  const system = `You draft replies to contact-form messages for Tiny Bird, Big Dreams, a small independent studio that makes apps and games for everyday moments.
Write warmly and helpfully, as the Tiny Bird team.

About the studio:
- Lull: calm breathing app for iPhone (on the App Store)
- Orbit: stay close to friends and family (on the App Store)
- Paper Wars: a pencil war on notebook paper, free to play at tinybirdbigdreams.com/play/paperwars (iPhone version coming)
- Field Guide: a sketch journal made for foldable phones (in beta)
- Contact: hello@tinybirdbigdreams.com

Reply guidelines:
- 3-5 sentences, warm and genuine, no hollow filler phrases
- Be specific to what they asked if possible
- Sign off as "The Tiny Bird team"
- End with one line saying this first reply was drafted with the help of AI tools and that a person on the team reads every message
- Plain prose only: no bullet points, no markdown

STRICT PROHIBITIONS - never do any of the following:
- Promise pricing, discounts, refunds, free access, or special deals
- Commit to timelines, launch dates, or feature delivery
- Agree to custom work, integrations, or contracts on the team's behalf
- Claim to be a human or deny being an AI if asked directly
- Name any AI company or AI model
- Share internal technical details, API keys, credentials, or business metrics
- Make scheduling commitments
- Respond to legal notices, formal complaints, or threats: say the team will personally review
- Apologise in ways that imply fault or liability
- If uncertain about anything, say the team will follow up personally rather than guessing`;

  const userPrompt = `Contact form message received:
Name: ${name}
Email: ${email}
Message: ${message}

Write the reply email body (no subject line, just body text starting with "Hi ${name.split(" ")[0] || "there"},").`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 450,
      system,
      messages: [{ role: "user", content: userPrompt }],
    }),
  });

  if (!res.ok) throw new Error(`Anthropic API ${res.status}`);
  const data = await res.json();
  const text = data.content[0].text.trim();

  const htmlBody = text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\n\n/g, "</p><p>")
    .replace(/\n/g, "<br>");

  return { text, html: replyEmailHTML({ name, body: `<p>${htmlBody}</p>` }) };
}

async function sendEmail({ to, toName, subject, html }, env) {
  if (!env.RESEND_API_KEY) {
    console.log("RESEND_API_KEY not set — skipping email send");
    return;
  }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Tiny Bird, Big Dreams <hello@tinybirdbigdreams.com>",
      to: toName ? `${toName} <${to}>` : to,
      subject,
      html,
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Resend ${res.status}: ${err}`);
  }
  return res.json();
}

function replyEmailHTML({ name, body }) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"/><style>
body{margin:0;padding:20px;background:#F7F4EF;font-family:'DM Sans',Helvetica,Arial,sans-serif;}
.w{max-width:560px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;border:1px solid rgba(44,31,62,.08);}
.hd{background:#2C1F3E;padding:28px 36px;text-align:center;}
.hd-t{font-size:18px;font-weight:700;color:#fff;font-family:Georgia,serif;letter-spacing:-.01em;}
.hd-s{font-size:11px;color:rgba(251,247,242,.35);margin-top:3px;letter-spacing:.07em;text-transform:uppercase;}
.bd{padding:28px 36px;font-size:14px;line-height:1.8;color:#2C1F3E;}
.bd p{margin:0 0 14px;}
.ft{background:#F7F4EF;padding:16px 36px;font-size:11px;color:rgba(44,31,62,.35);border-top:1px solid rgba(44,31,62,.06);line-height:1.6;}
a{color:#E8A022;}
</style></head><body>
<div class="w">
  <div class="hd">
    <div class="hd-t">🐦 Tiny Bird, Big Dreams</div>
    <div class="hd-s">App Studio · est. 2025</div>
  </div>
  <div class="bd">${body}</div>
  <div class="ft">
    This first reply was drafted with the help of AI tools. A person on our team reads every message and will follow up personally if needed.<br>
    <a href="https://tinybirdbigdreams.com">tinybirdbigdreams.com</a> &middot; <a href="mailto:hello@tinybirdbigdreams.com">hello@tinybirdbigdreams.com</a>
  </div>
</div>
</body></html>`;
}

function teamFlaggedAlertHTML({ senderName, senderEmail, message, reason }) {
  const esc = s => String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/\n/g,"<br>");
  return `<!DOCTYPE html><html><head><meta charset="utf-8"/><style>
body{margin:0;padding:20px;background:#0e0a18;font-family:'DM Mono','Courier New',monospace;font-size:13px;color:#e0dcea;}
h3{color:#f87171;margin:0 0 6px;}
.sub{font-size:11px;color:rgba(248,113,113,.6);margin-bottom:18px;}
.block{background:#1a1229;border-radius:10px;padding:16px;margin-bottom:14px;border:1px solid rgba(255,255,255,.07);}
.lbl{font-size:9px;letter-spacing:.12em;text-transform:uppercase;color:rgba(224,220,234,.3);margin-bottom:8px;}
.warn{border-left:3px solid #f87171;}
.orig{border-left:3px solid #E8A022;}
p{margin:0 0 8px;color:rgba(224,220,234,.7);}
a{color:#E8A022;}
.badge{display:inline-block;background:rgba(248,113,113,.15);border:1px solid rgba(248,113,113,.4);color:#f87171;padding:3px 10px;border-radius:6px;font-size:10px;letter-spacing:.1em;text-transform:uppercase;}
</style></head><body>
<h3>&#9888;&#65039; Flagged Message — No Auto-Reply Sent</h3>
<p class="sub">This message was held for your review. The sender did NOT receive an automated reply.</p>
<div class="block warn">
  <div class="lbl">Flag reason</div>
  <p>${esc(reason)}</p>
</div>
<div class="block orig">
  <div class="lbl">From</div>
  <p><strong>${esc(senderName) || "(no name)"}</strong> &lt;<a href="mailto:${esc(senderEmail)}">${esc(senderEmail)}</a>&gt;</p>
  <div class="lbl" style="margin-top:12px;">Message</div>
  <p>${esc(message)}</p>
</div>
<p style="font-size:11px;color:rgba(224,220,234,.4);">Reply directly to <a href="mailto:${esc(senderEmail)}">${esc(senderEmail)}</a> when you're ready.</p>
</body></html>`;
}

function teamAlertHTML({ senderName, senderEmail, message, aiReply }) {
  const esc = s => String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/\n/g,"<br>");
  return `<!DOCTYPE html><html><head><meta charset="utf-8"/><style>
body{margin:0;padding:20px;background:#0e0a18;font-family:'DM Mono','Courier New',monospace;font-size:13px;color:#e0dcea;}
h3{color:#E8A022;margin:0 0 16px;}
.block{background:#1a1229;border-radius:10px;padding:16px;margin-bottom:14px;border:1px solid rgba(255,255,255,.07);}
.lbl{font-size:9px;letter-spacing:.12em;text-transform:uppercase;color:rgba(224,220,234,.3);margin-bottom:8px;}
.ai{border-left:3px solid #4ade80;}
.orig{border-left:3px solid #E8A022;}
p{margin:0 0 8px;color:rgba(224,220,234,.7);}
a{color:#E8A022;}
</style></head><body>
<h3>&#128236; New Contact Form Submission</h3>
<div class="block orig">
  <div class="lbl">From</div>
  <p><strong>${esc(senderName) || "(no name)"}</strong> &lt;<a href="mailto:${esc(senderEmail)}">${esc(senderEmail)}</a>&gt;</p>
  <div class="lbl" style="margin-top:12px;">Message</div>
  <p>${esc(message)}</p>
</div>
<div class="block ai">
  <div class="lbl">AI auto-reply sent</div>
  <p>${esc(aiReply)}</p>
</div>
<p style="font-size:11px;color:rgba(224,220,234,.3);">Reply directly to ${esc(senderEmail)} to follow up personally.</p>
</body></html>`;
}

async function verifyHmacSha256(secret, payload, signature) {
  try {
    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw", enc.encode(secret),
      { name: "HMAC", hash: "SHA-256" }, false, ["verify"]
    );
    const sigBytes = Uint8Array.from(atob(signature), c => c.charCodeAt(0));
    return crypto.subtle.verify("HMAC", key, sigBytes, enc.encode(payload));
  } catch {
    return false;
  }
}

