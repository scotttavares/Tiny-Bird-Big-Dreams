# Tiny Bird, Big Dreams — Claude Instructions

## Deployments & GitHub

**Always handle deployments autonomously.** When a feature branch is ready:
1. Un-draft the PR if it's in draft state
2. Merge it (squash merge preferred)
3. Do not ask the user to merge — just do it

The Cloudflare deploy runs automatically via GitHub Actions on every push to `main` (`.github/workflows/cloudflare-deploy.yml`). No manual deploy step needed after merging.

## Project Overview

- **Stack**: Cloudflare Workers + KV + static assets (`wrangler.jsonc`)
- **Worker**: `src/worker.js` — handles `/track`, `/consent`, `/signup`, `/email-webhook`, `/studio`, `/gazette`; `/` is a plain static `index.html`
- **Tests**: `npm test` (node:test, no dependencies; fake KV in `test/fake-kv.js`)
- **KV namespace**: `VISITORS` (binding) → `TBBD_VISITORS` (namespace, ID: `37261423339b4133b6ebdb46d0cf6293`)
- **Dev branch convention**: `claude/relaxed-planck-QczTz`

## Orbit sub-site (the Orbit product pages)

- **Pages**: `orbit.html` (`/orbit`), `orbit-privacy.html` (`/orbit-privacy`), `orbit-support.html` (`/orbit-support`) — the marketing site for the **Orbit** iOS app (a warm lifestyle app for staying close to friends & family).
- **Own light theme**: these use `assets/orbit.css` — a warm, light "golden-hour" lifestyle look (Bricolage Grotesque + Hanken Grotesk), deliberately separate from the Tiny Bird studio theme (`assets/site.css`). Keep it light and warm; do **not** revert to the earlier dark cosmic style.
- **Faces must be REAL and EMBEDDED.** The orbit "balls" and the "moments" cards show real face photos — never initials or hotlinked image URLs. The deploy/preview environment blocks external image hosts (randomuser.me, Unsplash, …), so faces are **base64-embedded** as `.f-*` `background-image` classes inside `orbit.html`'s `<style>`. When adding or swapping a person, embed their photo the same way — don't leave a face as an initial or an external URL. (Current set: PrimeFaces demo avatars used as placeholders; swap for the user's own or properly-licensed stock when available.)

## Studio site (home page and brand)

- **Positioning**: Tiny Bird, Big Dreams is a *small independent team*. Never describe it as a one-person studio, a founder plus AI, or "building in public with Claude". Never name an AI provider on public pages; the AI disclosure says "AI tools" (see `privacy.html#ai`).
- **Home page** (`index.html`, `assets/home/`): "A day with Tiny Bird: Small moments. Big life." A "What brings you here?" picker, app "moments" through the day with playable mini-toys (the reel section was removed at the owner's request), the studio with the contact form, and the Shop. Tap the flying bird 5 times for the hummingbird easter egg. Design spec: `docs/superpowers/specs/2026-11-06-site-redesign-design.md`.
- **Simple pages** (`apps`, `privacy`, `terms`, `404`) use `assets/page.css`.
- **Photos/video** on the home page are AI-generated stand-ins. No customer quotes until real ones exist (add them as `<div class="quote">` in a moment scene).

## Key Systems

### Cookie consent and analytics
- Every page we own loads `/assets/consent.js` (ClearConsent, vendored as `assets/clearconsent.min.js`). Opt-in everywhere, GPC honoured.
- Nothing analytic runs before the visitor grants "analytics": then `assets/tb-analytics.js` and the Cloudflare beacon load. Withdrawing consent stops tracking and deletes `tb_vid`/`tb_msg` from localStorage.
- Worker stores aggregate-only data in KV (`src/analytics.js`): `d:{day}` totals, `uv:{week}:{vid}` for unique counts, `c:{day}` anonymous consent tally.
- `/studio` (password `STUDIO_PASSWORD`) shows visitors, per-app page views, what visitors did, highlights, emails, signups and cookie accept/decline (`src/studio.js`).
- The Paper Wars game page (`play/paperwars/`) is written by the Paper Wars publish script; it needs `<script src="/assets/consent.js" defer></script>` added there.

### Contact form and signups
- Contact form posts to `/email-webhook` (direct form POST). Every non-spam message is stored as `msg:*` in KV (`src/inbox.js`); the AI drafts a first reply as "the Tiny Bird team" and Resend sends it. Secrets: `ANTHROPIC_API_KEY`, `RESEND_API_KEY`; `FORMSPREE_WEBHOOK_SECRET` is required for the legacy JSON webhook path (unsigned JSON is refused).
- "Get news when something hatches" posts to `/signup` (`signup:{email}` in KV).
- Abuse protection (`src/guard.js`): same-site Origin check, hidden `website` honeypot field, per-IP (hashed) rate limits.
