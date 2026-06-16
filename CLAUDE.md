# Tiny Bird, Big Dreams — Claude Instructions

## Deployments & GitHub

**Always handle deployments autonomously.** When a feature branch is ready:
1. Un-draft the PR if it's in draft state
2. Merge it (squash merge preferred)
3. Do not ask the user to merge — just do it

The Cloudflare deploy runs automatically via GitHub Actions on every push to `main` (`.github/workflows/cloudflare-deploy.yml`). No manual deploy step needed after merging.

## Project Overview

- **Stack**: Cloudflare Workers + KV + static assets (`wrangler.jsonc`)
- **Worker**: `src/worker.js` — handles `/`, `/track`, `/studio`, `/email-webhook`
- **KV namespace**: `VISITORS` (binding) → `TBBD_VISITORS` (namespace, ID: `37261423339b4133b6ebdb46d0cf6293`)
- **Dev branch convention**: `claude/relaxed-planck-QczTz`

## Key Systems

### AI Visitor Personalization
Returning visitors get Claude-remixed homepage copy based on behavior (scroll depth, interests, visit count). Visit 1: default. Visit 2+: personalized content generated via Claude Haiku and cached in KV.

Markers in `index.html`: `<!--TBBD:PILL-->`, `<!--TBBD:HERO_SUB-->`, `<!--TBBD:STUDIO_BODY-->`, `<!--TBBD:CTA_H2-->`, `<!--TBBD:CTA_P-->`, `<!--TBBD:FOUNDER_NOTE-->`, `<!--TBBD:EMAIL_NOTE-->`

### Email Acknowledgment Banner
After a visitor submits the contact form:
- Stage 1 (sync): `emailReplied: false` written to KV → visitor sees "📬 Your message landed safely" banner on next page load
- Stage 2 (background via `ctx.waitUntil`): AI generates reply, Resend sends it, then `emailReplied: true` → banner disappears

The form hidden field uses `name="vid"` (not `_vid` — Formspree strips underscore-prefixed fields).

### Email Webhook
Formspree POSTs to `/email-webhook` on form submission. Requires Worker secrets: `ANTHROPIC_API_KEY`, `RESEND_API_KEY`, `FORMSPREE_WEBHOOK_SECRET` (optional).
