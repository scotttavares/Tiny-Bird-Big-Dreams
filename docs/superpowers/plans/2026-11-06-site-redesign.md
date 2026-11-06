# tinybirdbigdreams.com Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the "A day with Tiny Bird" home page, a Shop, site-wide copy cleanup, ClearConsent-gated first-party analytics and a rebuilt `/studio` dashboard.

**Architecture:** Static HTML/CSS/JS as today (no framework, no build step). The home page becomes a plain static `index.html` (the worker stops rewriting it). The Cloudflare Worker keeps `/studio`, `/email-webhook`, `/gazette`, and gains `/track` v2, `/consent`, `/signup`; new worker logic lives in small ES modules under `src/` with `node:test` unit tests against a fake KV.

**Tech Stack:** HTML/CSS/vanilla JS, Cloudflare Workers + KV (`VISITORS`), ClearConsent (vendored), Node 20+ `node --test` (no dependencies), `html-validate` (CI).

**Spec:** `docs/superpowers/specs/2026-11-06-site-redesign-design.md`. Visual reference: `.superpowers/brainstorm/1596-1793978798/content/day.html` (+ `scene-*.jpg`, `orbit.png`, `pw.png`, `fg.png` beside it).

## Global Constraints

- No "Claude", "Anthropic", "one-person", "one founder", "1 founder", "one AI", "building in public with" on any public page we own; AI disclosure says "AI tools".
- Do not edit `play/paperwars/**` or `PaperWars/**`.
- URLs that must still return 200: `/`, `/apps`, `/paperwars`, `/paperwars-support`, `/paperwars-privacy`, `/fieldguide`, `/fieldguide-support`, `/fieldguide-privacy`, `/orbit`, `/orbit-support`, `/orbit-privacy`, `/privacy`, `/terms`, `/provenance`, `/play/paperwars/`.
- Nothing analytic runs and no visitor ID is created before ClearConsent grants `analytics`. Only the anonymous consent tally (`/consent`) and contact/signup submissions are recorded without it.
- ClearConsent config: `{"policyVersion":1,"honorGpc":true}` + categories essential, analytics; `ui.text.privacyPolicyUrl: "/privacy"`.
- Home subhead (exact): "Tiny Bird, Big Dreams is a small team making apps and games for the everyday moments that make a good day great."
- Hero (exact): "Small moments." / "Big life."; add-up line: "It adds up to a great day."; hummingbird fact only as the easter egg (spec §5), not a section; section 3 is the film reel (spec §4.3).
- App links: Lull `https://apps.apple.com/app/id6783862542`, Orbit `https://apps.apple.com/app/id6785966852`, Paper Wars `/play/paperwars/` and `/paperwars`, Field Guide `/fieldguide`.
- Placeholder quotes keep the visible "placeholder story" label; prices show "price TBC".
- All `*.html` must pass `npx html-validate "*.html"` with the repo's `.htmlvalidate.json`.
- Respect `prefers-reduced-motion`; usable at 375px wide with touch.

## Review Focus

1. Visitor declines (or GPC is on) → zero requests to `/track` and no Cloudflare beacon, ever on that page view. Test in Task 5.
2. Visitor accepts mid-page → analytics starts without reload and the page view is still counted. Test in Task 5.
3. Malformed/hostile `/track` bodies (huge arrays, non-string paths, unknown event types, bad vid) → 204 and nothing stored beyond capped, whitelisted fields. Test in Task 1.
4. Contact form from a non-consenting visitor → message stored and counted, no banner, no crash when `vid` is absent. Test in Task 2.
5. Phone width / reduced motion → home toys still usable, App Store buttons visible without the bird or animations. Verified in Task 6.

---

### Task 1: Analytics core (`src/analytics.js`)

**Files:**
- Create: `src/analytics.js`, `test/fake-kv.js`, `test/analytics.test.js`, `package.json` (only `{"private":true,"type":"module","scripts":{"test":"node --test test/"}}`)

**Interfaces:**
- Produces:
  - `sanitizeBatch(body: unknown) -> {vid: string|null, events: Event[]}`. `Event = {t: 'pv'|'scroll'|'out'|'toy'|'pick'|'shop'|'egg', p?: string, v?: string, n?: number}`; at most 50 events; strings trimmed to 80 chars; `p` must start with `/`; unknown `t` dropped; `vid` must match the UUID regex already in `worker.js` (`isValidVid`, move it here and export it).
  - `dayKey(date: Date) -> 'YYYY-MM-DD'` (UTC); `weekStart(date: Date) -> 'YYYY-MM-DD'` (Monday, UTC).
  - `recordBatch(kv, batch, {referrer?: string, ua?: string, now?: Date}) -> Promise<void>`: merges into `d:{day}` JSON `{pv:{path:n}, ref:{domain:n}, dev:{mobile|tablet|desktop:n}, scroll:{'25'|'50'|'75'|'100':n}, out:{v:n}, toy:{v:n}, pick:{v:n}, shop:{v:n}, egg:{v:n}}` (TTL 400 days); referrer stored as hostname only, own host → skip; if `vid` present writes `uv:{weekStart}:{vid}` = '1' (TTL 120 days).
  - `recordConsent(kv, choice: 'accept'|'reject'|'custom', now?: Date) -> Promise<void>` into `c:{day}` `{accept, reject, custom}`.
  - `readRange(kv, days: string[]) -> Promise<DayAgg>` (summed), `countUniques(kv, weekStart: string) -> Promise<number>` (KV list by prefix, follow cursor).
  - `appOf(path: string) -> 'lull'|'orbit'|'paperwars'|'fieldguide'|null` (`/paperwars*`→paperwars, `/orbit*`→orbit, `/fieldguide*`→fieldguide, `/lull*`→lull).
  - `highlights({thisWeek, lastWeek, uniquesThis, uniquesLast, consentThis, messagesThis, signupsThis}) -> string[]` (max 5, plain English, rules: per-app page-view change ≥ 25% and ≥ 10 views; total visitors change; new messages/signups count; consent accept rate %; top referrer).
- `test/fake-kv.js` exports `class FakeKV { get(k,{type}), put(k,v,opts), list({prefix,cursor}) }` matching the KV API (list returns `{keys:[{name}], list_complete, cursor}`, page size 2 to exercise cursors).

- [ ] **Step 1: Write failing tests** in `test/analytics.test.js`:
  - `sanitizeBatch` drops `{t:'evil'}`, truncates a 500-char `v` to 80, caps 200 events to 50, rejects `p:'http://x'`, returns `vid:null` for `'abc'`, returns `{vid:null, events:[]}` for `null`, `"str"`, `{events:"x"}`.
  - `recordBatch` twice with one `pv /paperwars` → `d:2026-11-06`.pv['/paperwars'] === 2; referrer `https://www.google.com/search?q=x` → ref['www.google.com'] === 1; referrer `https://www.tinybirdbigdreams.com/` → no ref entry; iPhone UA → dev.mobile === 1.
  - `countUniques` after 3 batches from 2 vids in the same week → 2.
  - `recordConsent` accept, accept, reject → `{accept:2,reject:1,custom:0}`.
  - `appOf('/orbit-support') === 'orbit'`, `appOf('/') === null`.
  - `highlights` with paperwars pv 40 vs 20 → includes a string containing "Paper Wars" and "100%".
- [ ] **Step 2:** `npm test` → FAIL (module missing).
- [ ] **Step 3:** Implement `src/analytics.js`.
- [ ] **Step 4:** `npm test` → all pass.
- [ ] **Step 5:** Commit `feat(analytics): aggregate-only consented analytics core`.

### Task 2: Messages and signups (`src/inbox.js`)

**Files:** Create `src/inbox.js`, `test/inbox.test.js`.

**Interfaces:**
- Produces:
  - `saveMessage(kv, {name, email, message, category: 'safe'|'flagged', now?: Date}) -> Promise<string>` key `msg:{ISO}:{4 random hex}` value `{name,email,message:first 2000 chars,category,replied:false,at}` (TTL 730 days). Returns key.
  - `markReplied(kv, key) -> Promise<void>`.
  - `saveSignup(kv, email: string, now?: Date) -> Promise<'ok'|'invalid'>`: validates `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`, lowercases, key `signup:{email}`, value `{at}`; idempotent.
  - `listMessages(kv, limit=50) -> Promise<Msg[]>` newest first; `listSignups(kv) -> Promise<{email, at}[]>`; `countSince(items, isoDate) -> number`.

- [ ] **Step 1: Failing tests:** save 3 messages → `listMessages` newest first, length 3; `markReplied` flips `replied`; message text 5000 chars stored as 2000; `saveSignup('A@B.co')` twice → one record `signup:a@b.co`; `saveSignup('nope')` → `'invalid'`.
- [ ] **Step 2:** run → FAIL. **Step 3:** implement. **Step 4:** run → PASS.
- [ ] **Step 5:** Commit `feat(inbox): store contact messages and signups`.

### Task 3: Worker routes and retiring home-page personalisation

**Files:** Modify `src/worker.js`, `wrangler.jsonc`; Create `test/worker.test.js`.

**Interfaces:**
- Consumes: Task 1 and Task 2 exports.
- Produces routes: `POST /track` (JSON `{vid?, events}` → `recordBatch` via `ctx.waitUntil`, always 204), `POST /consent` (JSON `{choice}` → `recordConsent`, 204; invalid choice → 204, nothing stored), `POST /signup` (form or JSON `email` → 200 `{ok:true}` / 400 `{ok:false}`), `/email-webhook` (as today, plus `saveMessage` for non-spam regardless of `vid`, and `markReplied` after the auto-reply sends; drop the `v:{vid}` profile writes).
- Remove: `serveHome`, `getOrSetVid`, `updateVisitor`, `applyBehavior`, `generatePersonalizedContent`, `injectContent`, the `/` route; Supabase (`SUPA`, `supaMetrics`, `SNAPSHOT`), Stripe (`stripeRevenue`) and non-TBBD Cloudflare zones. Keep `cfTraffic` for tinybirdbigdreams.com only.
- `wrangler.jsonc` `run_worker_first`: `["/track", "/consent", "/signup", "/studio", "/studio/*", "/email-webhook", "/gazette", "/gazette/"]` (no `/`).
- AI reply/classifier prompts: rewrite to speak as "the Tiny Bird team"; remove founder/one-person/AI-co-founder framing and any provider name; alert emails keep going to `hello@tinybirdbigdreams.com` but greet "Team" not "Scott".

- [ ] **Step 1: Failing tests** (`import worker from '../src/worker.js'`, call `worker.fetch(new Request(...), env, ctx)` with `env={VISITORS:new FakeKV()}` and a `ctx` collecting `waitUntil` promises): `/track` with one pv → 204 and after awaiting `d:` has it; `/track` with body `"garbage"` → 204, KV empty; `/consent` `{choice:'reject'}` → `c:` reject 1; `/consent` `{choice:'x'}` → KV empty; `/signup` bad email → 400; webhook form post without `vid` and no `ANTHROPIC_API_KEY` (classifier falls back to safe) → 200 and one `msg:` key; `GET /` is not handled by the worker path (falls through to `env.ASSETS.fetch`, stub it to return 'static').
- [ ] **Step 2:** run → FAIL. **Step 3:** implement. **Step 4:** `npm test` → PASS; `grep -nE "serveHome|generatePersonalizedContent|stripe|supabase|Scott" src/worker.js` → no matches (case-insensitive for stripe/supabase).
- [ ] **Step 5:** Commit `feat(worker): consented tracking, consent tally, signups; retire home rewrite`.

### Task 4: `/studio` dashboard (`src/studio.js`)

**Files:** Create `src/studio.js`, `test/studio.test.js`; Modify `src/worker.js` (`collectMetrics` → `collectStudio(env)` using Task 1/2 readers; `dashboardHTML` and `csvExport` move to `studio.js`).

**Interfaces:**
- Produces: `collectStudio(env, now?: Date) -> Promise<Studio>` with `{thisWeek: DayAgg, lastWeek: DayAgg, weeks: {start, pv, uniques}[] (7), perApp: {app, pv, weeks:number[]}[], uniquesThis, uniquesLast, consent:{this:{accept,reject,custom}, last:{…}}, messages: Msg[], signups:[], highlights: string[], cfTotal: number|null}`; `renderStudio(s: Studio) -> string` (HTML); `studioCsv(s) -> string`.
- Page sections in order: "What's important to know" (highlights), top row (Visitors this week vs last, Page views, Emails submitted, Signups, Clicks to App Store/TestFlight/Play, Cookies accepted vs declined with %), "Visitors per app" (Lull, Orbit, Paper Wars, Field Guide; each with inline-SVG sparkline of 7 weeks; Paper Wars shows "Play clicks"), "What they did" (top pages, referrers, devices, scroll depth, picker choices, toy plays, shop clicks), "Emails" (recent messages: date, name, email, replied/flagged; signups list), small footnote "Consented visitors only. Cloudflare total this week: N".
- Styled to the new brand (cream/ink/gold, Instrument Serif + Inter Tight), works on phone.

- [ ] **Step 1: Failing tests:** `renderStudio(sample)` contains "What's important to know", "Visitors per app", "Lull", "Orbit", "Paper Wars", "Field Guide", "Cookies", "Consented visitors only", and each highlight string; escapes `<script>` in a message name (`&lt;script&gt;`); `studioCsv` first line is a header row.
- [ ] **Step 2–4:** fail → implement → pass. `/studio` login flow unchanged (same `STUDIO_PASSWORD`).
- [ ] **Step 5:** Commit `feat(studio): dashboard for visitors, apps, emails and consent`.

### Task 5: Consent + client analytics on every owned page

**Files:**
- Create: `assets/clearconsent.min.js` (vendored from `scotttavares/Adobe-Analytics-DTM` `site/clearconsent.min.js`, keep MIT header/notice; add `assets/clearconsent.LICENSE.txt`), `assets/consent.js`, `assets/tb-analytics.js`.
- Modify: `index.html`, `apps.html`, `privacy.html`, `terms.html`, `404.html`, `provenance.html`, `paperwars.html`, `paperwars-support.html`, `paperwars-privacy.html`, `fieldguide.html`, `fieldguide-support.html`, `fieldguide-privacy.html`, `orbit.html`, `orbit-support.html`, `orbit-privacy.html`; remove `assets/site.js` behaviour-beacon block.

**Interfaces:**
- `consent.js` (loaded right after `clearconsent.min.js`, both `defer`): inits ClearConsent with the Global Constraints config and brand theme (`ui.layout:'box'`, `position:'bottom-left'`, `blocking:false`, surface `#17130e`, accent `#E8A022`); on `clearConsent:change` posts `/consent` `{choice}` (accept if analytics granted & all, reject if none, else custom) once per decision; `gate('analytics', …)` → loads `/assets/tb-analytics.js` and the Cloudflare beacon (`token b0b9b5a0ff9345038eb0ab5e85b9ac3d`); wires any `[data-cookie-settings]` link to `openPreferences()`.
- `tb-analytics.js` exposes `window.tb.track(t, v)`; creates `localStorage.tb_vid` (UUID) on first run; queues `pv` for `location.pathname`, scroll buckets, outbound clicks (`apps.apple.com`→`appstore:{id}`, `testflight`→`testflight`, `/play/paperwars`→`play:paperwars`); flushes with `navigator.sendBeacon('/track', JSON)` on `pagehide`/`visibilitychange=hidden` and every 20 events. Sets hidden `input[name=vid]` on forms.
- Every owned page: replace the hard-coded Cloudflare beacon `<script>` with the two scripts; footer gets `<a href="#" data-cookie-settings>Cookie settings</a>`.

- [ ] **Step 1:** Vendor the file and add the scripts to all pages listed.
- [ ] **Step 2: Browser test (decline):** serve the repo (`npx http-server -p 8788 -c-1 .` or `python -m http.server 8788`), open `/`, click Reject in the banner, scroll and click an App Store link; `read_network_requests` with `urlPattern:'/track'` → none; `cloudflareinsights` → none; `/consent` → one request.
- [ ] **Step 3: Browser test (accept mid-page):** fresh profile (clear localStorage/cookies), open `/paperwars`, accept; scroll, then trigger `pagehide` (navigate away) → one `/track` beacon whose body has `{t:'pv',p:'/paperwars'}` and a `vid`.
- [ ] **Step 4: GPC:** with `navigator.globalPrivacyControl` forced true via an init script, analytics is not granted by default.
- [ ] **Step 5:** `npx html-validate "*.html"` → no errors. Commit `feat(consent): ClearConsent and gated first-party analytics site-wide`.

### Task 6: The new home page

**Files:** Replace `index.html`; Create `assets/home/home.css`, `assets/home/home.js`, `assets/home/{hummingbird,lull,orbit,fieldguide,paperwars}.jpg` (from `scene-*.jpg`; hummingbird ≤ 900px wide for the easter-egg card, others ≤ 1100px, quality ~82), `assets/home/reel/{lull,orbit,fieldguide,paperwars}.mp4` + `-poster.jpg` (from the generated reel clips, 1280px wide, H.264, muted), `assets/home/icon-{orbit,paperwars,fieldguide}.png` (256px, from the prototype's icons); `assets/og-image.png` (1200×630, a reel still + wordmark; it's referenced by meta tags and currently missing).

**Interfaces:**
- Consumes: Task 5 scripts (`window.tb?.track` may be undefined → guard every call), `/signup`, `/email-webhook`.
- Port the prototype faithfully (sections §4 of the spec), with these changes:
  - Real hrefs (Global Constraints); Shop cards' buttons link out; "Something's hatching" → `#join`.
  - Studio section gets the contact form (`id="contactForm"`, `action="/email-webhook"`, fields name/email/message + hidden `vid`) with inline success state, and on success if `localStorage.tb_vid` exists set `localStorage.tb_msg='1'`; on load, if `tb_msg` is set, show the "Your message has landed in the nest" note in the studio section.
  - Signup form posts `/signup` (fetch, JSON) and shows "You're on the list ✦" / an inline error.
  - Analytics hooks: picker click → `tb.track('pick', key)`, toy first interaction per toy → `tb.track('toy', name)`, shop tab/card button → `tb.track('shop', id)`.
  - Mobile (<900px): compact header with a menu button (sheet with the four links, Shop highlighted); bird follows taps only; toys sit below the photo at 70% width.
  - `prefers-reduced-motion`: no bird, no parallax/clip/counter animation (final values shown), sky static per section.
  - `<title>Tiny Bird, Big Dreams: small apps for a great day</title>`, meta description, OG/Twitter tags (existing URLs), `theme-color #f2c9a5`, manifest link, favicon.
  - Reel: two stacked `<video muted playsinline preload="metadata">` elements alternating with a 900ms crossfade; only the visible/next clip loads; pauses when off-screen (IntersectionObserver) and via a visible pause button; reduced motion → static posters.
  - Easter egg: 5 clicks on the flying bird within 4s (the bird gets `pointer-events:auto` + a 56px hit area) or 5 taps on the header logo → hummingbird fact card (spec §5) + `tb.track('egg','hummingbird')`.
  - Remove all `TBBD:*` markers.
- [ ] **Step 1:** Build it. **Step 2:** `npx html-validate index.html` → clean.
- [ ] **Step 3: Browser check** at 1440×900, 768×1024, 375×812 and with reduced motion: every section renders, no console errors, each toy works once, the reel crossfades through all four clips and pauses off-screen, the easter egg opens after 5 bird clicks, picker scrolls to the right moment, Shop tabs filter, both forms show success (stub with a local fake if the worker isn't running: forms must show the error state gracefully on 404 from the static server).
- [ ] **Step 4:** Commit `feat(home): "A day with Tiny Bird" home page and shop`.

### Task 7: Copy cleanup, apps page, privacy, assets

**Files:** Modify `apps.html`, `privacy.html`, `paperwars.html`, `orbit.html`, `orbit-privacy.html`, `orbit-support.html`, `provenance.html`, `404.html`, `terms.html` (footer only), `assets/site.css` (only if `apps.html`/`404` keep using it), `site.webmanifest`, `sitemap.xml`; replace `assets/icon-512.png` and `assets/icon-192.png` with real PNGs (the golden bird on `#f6f1e8`).

- `apps.html`: same products as the Shop in the new look (reuse `assets/home/home.css` shop styles), header/footer like the home page; drop Tiny Thoughts/Tiny Superpowers and "Skylark" placeholders.
- `privacy.html`: "Claude by Anthropic" → "AI tools"; add "Cookies & analytics" section: ClearConsent banner; nothing measured before consent except an anonymous count of banner choices; after consent a random visitor ID in your browser's local storage, page views, referrer site, device type, scroll depth and clicks, stored as daily totals; Cloudflare Web Analytics after consent; contact messages and signups stored to reply/notify; GPC honoured; change your choice any time via "Cookie settings".
- Footers on owned pages: "Made with Claude · Shipped from scratch" → "Made with care by Tiny Bird, Big Dreams"; `paperwars.html` "a one-person studio building in public with Claude" → "a small independent studio".
- `sitemap.xml`: add `/orbit`, `/paperwars-support`, `/orbit-support`; keep existing.

- [ ] **Step 1:** Make the edits.
- [ ] **Step 2: Verify:** `grep -rniE "claude|anthropic|one-person|one founder|1 founder|one ai|building in public" --include=*.html . | grep -vE "^./(play|PaperWars|orbit/|FieldGuide)/"` → no output; `python -c "from PIL import Image;[print(Image.open(p).size) for p in ['assets/icon-192.png','assets/icon-512.png','assets/og-image.png']]"` → (192,192) (512,512) (1200,630); `npx html-validate "*.html"` → clean.
- [ ] **Step 3:** Commit `chore(copy): small-team voice, generic AI disclosure, cookies policy, real icons`.

### Task 8: Final verification and PR

- [ ] `npm test` → all pass.
- [ ] Serve statically; request every Global Constraints URL (with `.html` fallback as Cloudflare's `auto-trailing-slash` does) → 200.
- [ ] Browser walkthrough with the user (desktop, phone, reduced motion); note anything not verifiable locally (worker routes need deploy or `wrangler dev`).
- [ ] Push branch, open PR to `main` with summary + screenshots + follow-ups (game page consent/analytics via Paper Wars session; real photos/quotes/prices; Lull icon). Do not merge without the user's go-ahead.
