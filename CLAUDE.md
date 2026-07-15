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

## Orbit sub-site (the Orbit product pages)

- **Pages**: `orbit.html` (`/orbit`), `orbit-privacy.html` (`/orbit-privacy`), `orbit-support.html` (`/orbit-support`) — the marketing site for the **Orbit** iOS app (a warm lifestyle app for staying close to friends & family).
- **Own light theme**: these use `assets/orbit.css` — a warm, light "golden-hour" lifestyle look (Bricolage Grotesque + Hanken Grotesk), deliberately separate from the Tiny Bird studio theme (`assets/site.css`). Keep it light and warm; do **not** revert to the earlier dark cosmic style.
- **Faces must be REAL and EMBEDDED.** The orbit "balls" and the "moments" cards show real face photos — never initials or hotlinked image URLs. The deploy/preview environment blocks external image hosts (randomuser.me, Unsplash, …), so faces are **base64-embedded** as `.f-*` `background-image` classes inside `orbit.html`'s `<style>`. When adding or swapping a person, embed their photo the same way — don't leave a face as an initial or an external URL. (Current set: PrimeFaces demo avatars used as placeholders; swap for the user's own or properly-licensed stock when available.)

## Key Systems

### AI Visitor Personalization
Returning visitors get Claude-remixed homepage copy based on behavior (scroll depth, interests, visit count). Visit 1: default. Visit 2+: personalized content generated via Claude Haiku and cached in KV.

Markers in `index.html`: `<!--TBBD:PILL-->`, `<!--TBBD:HERO_SUB-->`, `<!--TBBD:STUDIO_BODY-->`, `<!--TBBD:CTA_H2-->`, `<!--TBBD:CTA_P-->`, `<!--TBBD:FOUNDER_NOTE-->`, `<!--TBBD:EMAIL_NOTE-->`

### Email Acknowledgment Banner
After a visitor submits the contact form, their KV profile gets `email` set. On every subsequent visit, `serveHome` injects a persistent "📬 Thanks for reaching out" banner — no timing-dependent flag needed.

- Banner condition: `if (profile.email)` — shows permanently once they've emailed
- Stage 1 (sync): writes visitor's email/name to KV profile, clears `generatedContent` cache
- Stage 2 (background via `ctx.waitUntil`): AI generates reply, Resend sends it, sends founder alert

The form hidden field uses `name="vid"` (not `_vid` — Formspree strips underscore-prefixed fields).

### Email Webhook
Formspree POSTs to `/email-webhook` on form submission. Requires Worker secrets: `ANTHROPIC_API_KEY`, `RESEND_API_KEY`, `FORMSPREE_WEBHOOK_SECRET` (optional).
