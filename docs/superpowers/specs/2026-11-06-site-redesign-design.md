# tinybirdbigdreams.com redesign: "A day with Tiny Bird"

Date: 2026-11-06 · Branch: `claude/site-redesign` (from `origin/main` @ `7664ddd`)

Approved prototype (the visual and interaction reference for this whole document):
`.superpowers/brainstorm/1596-1793978798/content/day.html` plus the scene photos beside it (`scene-*.jpg`). The production home page should look and behave like that prototype unless this document says otherwise.

## 1. Intent and the why

Tiny Bird, Big Dreams should read as a **real, growing small app company**, not a solo founder working with an AI. The site has two jobs:

1. **Show off the apps and games**, front and centre, and make people want to use them.
2. **Make the name mean something.** Tiny Bird, Big Dreams = *tiny things go a long way*. Our apps are tiny moments (one breath, one hello, one page, one game) that add up to a better day. Tagline: **"Small moments. Big life."**

The user asked for something premium, high-end and genuinely creative: the site itself should be a showcase of craft ("show off super skills"). It should be *played with*, not just read, while staying grounded in how the apps help real people in a normal day.

References the user liked (inspiration, never copy): neal.fun/deep-sea (scroll as a journey), because-recollection.com (playful toy with sound), rewildyourself.com (living night sky, hand-drawn), landonorris.com (reactive, high-craft), Framer community gallery (polish and type), superpower.com (real people, warm cinematic photography, a "what brings you here?" chooser, clean product cards). Game-studio sites (Awaysis, AdHoc, Bad Robot…) were reviewed: they confirm a mascot-as-star and cinematic openings.

## 2. Goals, non-goals, anti-goals

**Goals**
- New home page built as "A day with Tiny Bird" (structure in §4).
- Apps and games are the heart of the page and are one click from their App Store / play / beta links.
- A **Shop** section listing every app, game and in-game item.
- Remove every "one founder / one-person studio / one AI / building in public with Claude" message across the public site. Keep a short, honest **AI disclosure** that says "AI tools" and **never names a provider** (no "Claude", no "Anthropic"), because the studio may use different tools.
- **Cookie consent** with ClearConsent (the user's own open-source CMP) on every page we own.
- **Analytics that answer the user's Monday questions** (see §6), with every app page counted.
- Everything works on phones (touch replaces hover/cursor) and honours `prefers-reduced-motion`.

**Non-goals**
- No redesign of the individual app pages' look (`paperwars.html`, `orbit*.html`, `fieldguide*.html`); they only get copy fixes, the consent banner and analytics.
- No real e-commerce / checkout. "Shop" cards link out (App Store, TestFlight, `/play/paperwars/`, in-game).
- No change to repo visibility or hosting.

**Anti-goals (failure even if it "works")**
- Anything that still reads as "one guy and an AI".
- Gimmicks that hide the apps or make it slow/janky on a phone. Toys must be instant and optional; the App Store buttons must always be obvious.
- Breaking any URL an App Store listing points to (§3).
- Tracking anyone before they consent.

## 3. Constraints (must keep working)

- **URLs that must not move or break:** `/paperwars`, `/paperwars-support`, `/paperwars-privacy`, `/fieldguide`, `/fieldguide-support`, `/fieldguide-privacy`, `/orbit`, `/orbit-support`, `/orbit-privacy`, `/privacy` (`privacy.html`), `/terms`, `/apps` (`apps.html`, in sitemap), `/provenance`, `/play/paperwars/`, and `PaperWars/PaperWars/Resources/game.html`.
- **Paper Wars files are owned by another session.** `play/paperwars/**` and `PaperWars/**` are written by `paper-war/publish-web.py`; do not edit them here. Adding consent/analytics to the game page must be requested via that session/the user (list it as a follow-up).
- **Hosting:** Cloudflare Worker + static assets (`wrangler.jsonc`, deploy on push to main) and GitHub Pages (CNAME). The page must work as a plain static file (GitHub Pages has no worker); worker features are enhancements.
- **Orbit pages:** keep `assets/orbit.css` light "golden-hour" theme and base64-embedded faces (see CLAUDE.md).
- **Fonts/scripts:** no external image hosts; ship images from the repo. Google Fonts are fine.
- **Merging** needs the user's explicit OK in chat (this overrides the CLAUDE.md auto-merge rule for this task, per the session brief).

## 4. The home page (`index.html`), as agreed

Sky, clock and bird run across the whole page; sections in order:

1. **Header:** bird logo + "Tiny Bird, Big Dreams"; glass pill nav (Our idea · A day with us · Studio · **Shop** highlighted); sound toggle (off by default). Bottom-right **day clock** (time + label + little sun arc) that follows scroll.
2. **Hero (6:00 am, dawn):** "Small moments. / *Big life.*" (line-by-line reveal). Sub: "Tiny Bird, Big Dreams is a small team making apps and games for the everyday moments that make a good day great." Hint chip: you're the bird.
3. **Life with our apps (film reel, sunrise):** *user decision: replaces the hummingbird photo section.* A full-bleed, muted, auto-playing, looping reel of four short real-life clips (morning breath with Lull → lunch-break hello with Orbit → kitchen-table drawing with Field Guide → couch game night with Paper Wars), crossfading one into the next. Overlay: small eyebrow "Life with Tiny Bird", a large serif line, and a caption that changes per clip (time + app, e.g. "7:12 am · Lull"); a pause/play button (accessibility). Clips are AI-generated stand-ins (image-to-video from the scene photos, 16:9, no audio, ~6s each, MP4 H.264, each ≤ ~4 MB) with the wide scene still as `poster`. Reduced motion or data-saver: show the poster stills as a static crossfade-free grid, no autoplay.
4. **"What brings you here?"**: four pills (calmer → Lull, miss my people → Orbit, remember more → Field Guide, something fun → Paper Wars) that smooth-scroll to the moment.
5. **The day:** four "moments", alternating left/right. Each: real-life photo with clip-reveal and parallax, time chip, short quote with name ("placeholder story" until real ones exist), app eyebrow with icon + status, big serif headline, description, an "In real life" note, primary CTA, and a **mini-toy** floating over the photo corner:
   - 7:12 am **Lull** (hold to breathe in, release to breathe out, breath count).
   - 12:40 pm **Orbit** (drag a friend away; spring back with tether line).
   - 6:30 pm **Field Guide** (tap to place stickers on a journal page).
   - 9:15 pm **Paper Wars** (draw a line; shot follows it; BOOM or miss; tap for a new sheet).
6. **It adds up:** "It adds up to *a great day*." and 1 breath + 1 hello + 1 page + 1 game = a big life.
7. **Studio (night):** nest (the bird lands in it), "Small team. *Big dreams.*", short paragraph, three values (Made for every day · Private by design · Small on purpose), plus a **contact form** (posts to `/email-webhook` as today) and the email-signup/"say hello".
8. **The Shop** (light cream panel): tabs All / Apps / Games; product cards (photo, icon, badge, name, category/platform, one line, price/status, button): Lull, Orbit, Field Guide (beta), Paper Wars (play free; iPhone soon; mention Operation Drumstick), Full Arsenal crate (in-game), "Something's hatching" mystery egg. Then "Get news when something hatches" signup.
9. **Footer:** Privacy · Terms · Support · Press · Cookie settings · ©.

Sky colours, clouds, stars, moon follow the clock (dawn → day → golden hour → dusk → night). Optional soft synthesized sounds (flap, breath, pencil, pop) only after the sound toggle.

**Mobile:** single column; photo then copy; toys sit under/over the photo at a usable size; the bird follows taps, not hover; nav collapses to a compact menu with Shop visible. **Reduced motion:** no flying bird/parallax/counters animation; everything shown statically; toys still usable.

## 5. Copy and content rules

- Voice: "we", small team, warm and confident. No founder, no "one person", no AI-as-co-founder, no provider names.
- Real links: Lull `https://apps.apple.com/app/id6783862542`, Orbit `https://apps.apple.com/app/id6785966852`, Paper Wars `/play/paperwars/` + `/paperwars`, Field Guide `/fieldguide` (beta).
- **Photos:** the five AI-generated scene photos are stand-ins (ship optimised JPG/WebP in `assets/home/`); the user may replace them with real photos later. Quotes/names are placeholders and must stay visibly marked until real ones exist.
- **Lull icon:** no icon file exists in the repo; use the glowing-sphere rendering from the prototype unless the user provides one.
- **Hummingbird easter egg** (user decision): the fact lives on as a hidden "cool bird fact". Trigger: tap/click the flying golden bird 5 times (or the header logo bird 5 times on touch devices). A small card pops up near the bird with the hummingbird photo (`scene-hummingbird`), "Cool bird fact", "The ruby-throated hummingbird weighs about 3 grams (about a penny) and flies roughly 500 miles across the Gulf of Mexico without stopping. Tiny bird, big dreams.", and a close button; the bird does a little celebratory loop. Also shown as the fact on `404.html`. Facts: ≈ 3 g, ≈ 500 miles nonstop across the Gulf of Mexico.
- **Remove old-story copy site-wide:** `index.html` (replaced), `apps.html`, `privacy.html` ("Claude by Anthropic" → "AI tools"), `paperwars.html` ("one-person studio building in public with Claude"), `orbit.html`, `orbit-privacy.html`, `orbit-support.html` ("Made with Claude · Shipped from scratch"), `provenance.html`. Also drop the old Tiny Thoughts / Tiny Superpowers mentions from `apps.html`.
- `apps.html` stays at its URL; restyle it to match the new site and list the same products as the Shop (or make it a slim page pointing at `/#shop`; builder's choice).
- Fix the broken `assets/icon-512.png` (it is base64 text, not a PNG) and make sure the manifest/OG images are real files.

## 6. Analytics and the `/studio` dashboard

The user's questions on a Monday: **how many visitors, what they did, what's important to know, how many emails were submitted, visitors to each app page, and how many accepted vs declined cookies.**

- **Collection:** after "analytics" consent, a small first-party script (`assets/site.js` or new `assets/tb-analytics.js`) sends events to the worker (`POST /track`, extended): page view (path, referrer domain, device class), scroll depth, outbound clicks (App Store / TestFlight / play), toy interactions, picker choice, shop tab/card clicks. Stored in KV as daily aggregates (counters keyed by day + metric), not per-person histories.
- **Consent tally:** every banner decision (accept / reject / custom) increments an anonymous counter (no ID, no cookie), so declines are counted without tracking the person.
- **Emails submitted:** count and list (name, email, date, replied/flagged) from the existing webhook flow.
- **Cloudflare Web Analytics** beacon stays as an aggregate cross-check, gated by consent (user decision, see below).
- **Dashboard (`/studio`, same password):** replace the old Tiny Thoughts / Tiny Superpowers / Stripe panels with:
  - Top row: visitors this week vs last, emails submitted, outbound clicks to App Store/TestFlight/play, consent accepted vs declined.
  - Visitors per app (marketing + support + privacy pages, plus Paper Wars web plays), each with a 7-week sparkline.
  - What they did: top pages, referrers, devices, scroll depth, picker choices, toy plays, shop clicks.
  - **What's important to know:** 3–5 plain-English highlights computed by rules (biggest week-over-week moves, new emails, consent rate change, top referrer). No AI needed.
  - Recent emails list.
  - CSV export kept.
- **User decision: everything waits for consent.** Apart from the anonymous accept/decline tally and contact/signup submissions, nothing is counted until the visitor accepts "analytics": no server-side cookieless counters, and the Cloudflare beacon is gated too. App pages stay static (no new `run_worker_first` paths); they're counted by the consented client script. Paper Wars web plays are estimated from clicks on our own "Play" links (the game page itself is out of scope here).
- **"Visitors"** = unique consented visitor IDs per week; page views shown alongside.
- Note: first-party numbers will undercount real traffic; the dashboard says so next to the numbers ("consented visitors only").
- **"Get news when something hatches" signup** (my call): its own endpoint (e.g. `POST /signup`) storing `signup:{email}` records in KV, with no AI reply and no alert. Shown on `/studio` as its own count and list (separate from contact emails) and exportable as CSV.
- **Contact emails** (my call): every non-spam submission is saved as its own KV record (`msg:{timestamp}`) whether or not the sender accepted cookies, because it is a direct request, not analytics. The dashboard's email count and list read these. The "message landed in the nest" banner shows only for consented visitors (it needs the visitor ID).
- **Existing `v:*` visitor profiles** (my call): stop creating new per-person profiles; existing ones are left to expire on their current 365-day TTL (nothing is deleted by hand). New analytics are aggregate counters only.
- **Old `/studio` panels** (my call): remove Supabase (Tiny Thoughts / Tiny Superpowers) and Stripe panels and code. Keep the Cloudflare traffic query for tinybirdbigdreams.com only, shown as a small "Cloudflare total" cross-check figure.
- **ClearConsent source:** the repo `scotttavares/Adobe-Analytics-DTM` is private but contains `site/clearconsent.min.js` under an MIT licence; vendoring it puts that file on the public site, which is intended.

## 7. Cookie consent (ClearConsent)

- Source: the user's repo `scotttavares/Adobe-Analytics-DTM` (MIT). Vendor `clearconsent.min.js` into `assets/` and load it on every page we own: `index`, `apps`, `privacy`, `terms`, `404`, `provenance`, and all `paperwars*`, `fieldguide*`, `orbit*` pages (not the game page; see §3).
- Config: `{"policyVersion":1,"honorGpc":true}`; categories used: essential + analytics.
- Gate with `ClearConsent.instance.gate('analytics', …)`: our tracking script, the Cloudflare beacon, and the visitor-ID cookie.
- **Worker change:** `serveHome` currently sets the `tbbd_vid` cookie for every visitor; it must only do so after consent (e.g. the client asks the worker for an ID after consent, or the cookie is set by a consented `/track` call).
- Footer "Cookie settings" link reopens the banner. Banner styled to match the site.
- `privacy.html` gains a Cookies & analytics section describing exactly the above.

## 8. Worker changes (`src/worker.js`)

- **Retire the AI copy-remix of the home page** (the `TBBD:*` markers and `generatePersonalizedContent`). It rewrote the copy in the old founder/AI voice and would fight the designed page. *My call.* Keep `serveHome` only for the visitor-ID and the "message landed in the nest" banner for people who have emailed (restyled for the new page).
- Contact-form auto-reply (`generateAIReply`) stays, but its prompts must speak as "the Tiny Bird team" with no founder/AI framing or provider names. *My call.*
- Extend `/track` + add consent-tally endpoint + new dashboard as in §6.

## 9. Decided by the user vs left to the builder

**User decided:** small-startup positioning; apps front and centre; premium, playful, interactive; the "A day with Tiny Bird" concept and prototype; "Small moments. Big life."; the hummingbird fact as an easter egg (not a section); a film reel of life with our apps near the top; real-life photos (AI now, real later); a Shop; ClearConsent; the dashboard questions; generic AI disclosure.

Also user-decided: all analytics wait for consent (only the anonymous consent tally and direct submissions are recorded without it).

**My calls (flagged for the user):** retire home-page AI personalisation; keep AI email replies with new voice; aggregate-only KV analytics; rule-based "important to know"; Lull uses the sphere instead of an icon; separate signup list; contact messages stored regardless of consent; old visitor profiles left to expire; old `/studio` panels removed except a Cloudflare total.

**Left to the builder:** file/CSS/JS structure (keep it framework-free static HTML/CSS/JS like today), image formats and sizes, exact animation timings, how `apps.html` is restyled, mobile nav pattern, KV key layout, dashboard chart library (inline SVG is fine).

## 10. Done means

Built on `claude/site-redesign`; previewed locally for the user (desktop + phone width + reduced motion); every URL in §3 still returns 200; no "Claude"/"Anthropic"/"one-person"/"founder" left in public pages we own; consent blocks tracking until accepted; dashboard shows the §6 numbers; PR open. Merge only on the user's explicit go-ahead.

Follow-ups outside this branch: add consent + analytics to `/play/paperwars/` via the Paper Wars session's publish script; replace stand-in photos/quotes with real ones; confirm prices and the "Private by design" wording per app.
