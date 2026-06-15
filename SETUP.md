# Setup — Email Automation & Studio

This covers everything you (the founder) need to do by hand to turn on the
AI email auto-responder. The code is already deployed; these steps just
flip on the credentials and wiring.

---

## 1. Email auto-responder

When someone submits the contact form, the flow is:

```
Formspree webhook
       ↓
  classify (spam / flagged / safe)
       ↓
  ┌─ spam ────→ dropped silently
  ├─ flagged ─→ ⚠️ alert to you only, NO auto-reply
  └─ safe ────→ AI reply to sender + alert to you
```

Until the secrets below are set, the form still emails you the normal
Formspree way — nothing breaks, the AI layer just stays dormant.

### Step 1 — Resend (sends the emails)
1. Sign up at [resend.com](https://resend.com) (free tier: 100 emails/day)
2. **Domains** → add `tinybirdbigdreams.com`
3. Add the DNS records Resend shows you (SPF, DKIM) at your DNS host, wait for them to verify
4. **API Keys** → create a key, copy it

### Step 2 — Anthropic (powers the classifier + reply writer)
- Get an API key from [console.anthropic.com](https://console.anthropic.com)
- Without this, every message defaults to "safe" but no reply is sent

### Step 3 — Add secrets to the Cloudflare Worker
Cloudflare dashboard → **Workers & Pages** → `tbbd` worker →
**Settings** → **Variables and Secrets** → add:

| Secret | Value | Required |
|---|---|---|
| `RESEND_API_KEY` | from Step 1 | ✅ |
| `ANTHROPIC_API_KEY` | from Step 2 | ✅ |
| `FORMSPREE_WEBHOOK_SECRET` | from Step 4 (below) | optional, recommended |

### Step 4 — Point Formspree at the webhook
1. [formspree.io](https://formspree.io) → your form (`mojbggwj`) → **Settings** → **Webhooks**
2. Add: `https://tinybirdbigdreams.com/email-webhook`
3. If Formspree gives you a signing secret, copy it into
   `FORMSPREE_WEBHOOK_SECRET` (Step 3). This stops randoms from POSTing
   fake submissions to the endpoint.

### Step 5 — Test it
Submit a real message through the contact form on the live site and confirm:
- The sender address gets an AI reply
- You get a founder alert at `hello@tinybirdbigdreams.com`

If something misbehaves, check the Worker logs:
Cloudflare → `tbbd` worker → **Logs** (Real-time).

---

## Guardrails (already built in)

The AI never sends a reply for messages classified as **flagged**:
legal threats, DMCA/copyright, acquisition/investor inquiries, press,
large partnership proposals, harassment, or GDPR/CCPA data requests.
Those come to you with a red "NO AUTO-REPLY SENT" alert instead.

The reply writer is also prohibited from: promising pricing/refunds,
committing to timelines, agreeing to contracts, denying it's an AI,
or sharing internal details. When unsure, it defers to you.

---

## 2. Studio dashboard secrets (reference)

The private `/studio` dashboard reads live metrics. These secrets are
already set if the dashboard is showing live data — listed here for
reference only:

`STUDIO_PASSWORD`, `TTBI_SERVICE_KEY`, `TS_SERVICE_KEY`, `STRIPE_KEY`,
`CF_ANALYTICS_TOKEN`, `CF_ACCOUNT_ID`, `CF_TBBD_ZONE_TAG`,
`CF_TTBI_ZONE_TAG`, `CF_TS_ZONE_TAG`, `CF_TBBD_BEACON`,
`CF_TTBI_BEACON`, `CF_TS_BEACON`.

---

## Deploy notes

- **Static site** (`index.html`, `assets/`) → GitHub Actions → GitHub Pages
- **Worker** (`src/worker.js`) → Cloudflare on push to `main`
- Pushing to `main` redeploys both.
