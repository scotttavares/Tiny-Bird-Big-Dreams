# Field Guide 1.1: "Grown-up Holiday" update (design)

Status: draft for the owner's approval, 2026-11-08. Nothing in 1.1 is built yet.
1.0 went live on 2026-11-08. 1.0.1 (Face ID Privacy Lock) is in PR 114 and ships first.

## Why

1.0 reads as a sketchbook for kids and families. The audience we want next is people from late teens up to adults who keep travel journals, nature notes and bullet journals. They share pages on Instagram and TikTok, and they want the notebook to look like *theirs*. The holidays are the natural moment for this. People travel, make cards and look back on the year.

## Goals

- Make Field Guide look and feel grown-up: covers, stickers, type and paper you'd be happy to show anyone.
- Give people a reason to share pages, using only the system share sheet.
- Earn the first revenue without making anything that is free today paid.
- Ship before the holiday rush (timing below).

## Non-goals

- No subscription and no ads.
- No accounts, no social network inside the app, and no feeds.
- No Meta, TikTok or other social SDKs, and no music in exports.
- No AI services. Everything runs on the phone.

## Anti-goals (a failure even if it works)

- Anything a 1.0 user has today ends up behind a paywall.
- The app collects data, which would change the "Data Not Collected" privacy label.
- It looks like a kids' sticker app with a dark coat of paint.

## What ships

### Free for everyone
1. **Cover designer.** The cover editor from the mockups covers:
   - travel, field and leather themes;
   - board colour;
   - title text and font (4 fonts);
   - an emblem (12 to choose from);
   - ink, including gold and silver foil;
   - corners (none, brass or stitched);
   - a label or leather title plate;
   - an elastic band and its colour;
   - "Surprise me".

   A few themes and foils are Plus (below). Every 1.0 cover stays free.
2. **Grown-up starter sticker pack.** Line-art botanicals, stamps and travel labels drawn in the same ink style as the covers.
3. **Make-your-own stickers.** Long-press a photo to lift the subject out (Apple's Vision subject lift, on the phone) and save it as a sticker.
4. **Vertical replay video (9:16)** for Stories, Reels and TikTok, with a small "Field Guide" mark in the corner that you can turn off.
5. **December prompts.** One small drawing idea a day, shown on the left page. Sharing suggests #FieldGuideSketch as a caption, but you can still share without it.
6. **Holiday card export.** Any page becomes a 5x7 card PDF or image with a short message on the back.

### Field Guide Plus: a one-time $4.99 in-app purchase (non-consumable)
- All premium sticker packs: travel stamps, botanicals, pressed flowers, tickets & labels, a stamp set, a holiday pack, an emoji set restyled to the ink look, and type sheets. 11 sheets were shown in the mockups.
- Premium cover themes, foil inks and leather plates.
- "Year in Sketches": a short video of every page you made this year, built on the phone.
- Restore Purchases in the library menu, and Family Sharing turned on.

## Built later (1.2 and after)
- An iMessage sticker pack, using the same art.
- New papers (dot grid, watercolour, black paper with white ink) and new art tools (marker, watercolour wash).
- Optional per-notebook locks on top of the 1.0.1 app lock.

## Constraints

- iOS 26+, SwiftUI, SwiftData + CloudKit. Any new model fields must be optional or have a default. The CloudKit schema is in Production, so only additive changes are allowed. Add them to `schema.ckdb` and redeploy before the build.
- StoreKit 2 for Plus, tested with a local `.storekit` configuration file.
- Sticker art is original. It's SVG drawn in-house, the same as the 1.0 stickers.
- Privacy label stays "Data Not Collected". The purchase goes through Apple and the app keeps no data about it.

## Owner tasks before Plus can sell

1. In App Store Connect, accept the Paid Apps agreement and enter bank and tax details. Only you can do this; Claude never enters these.
2. Approve the Plus name, the $4.99 price and the list of what's included.
3. Create the in-app purchase in App Store Connect. Claude can walk through it with you in the browser, but you enter anything secret.

## Timing

| Date | What |
|---|---|
| Nov 8–10 | 1.0.1 Face ID: CI, TestFlight build, try it on the iPhone, submit |
| Nov 10–17 | Build 1.1 (covers, stickers, Plus, vertical replay, prompts, card) |
| Nov 18–20 | Submit 1.1 (review takes about a day; the Thanksgiving week slows down) |
| ~Dec 1 | Turn on the December prompts (they're built into the app; they start by date) |
| Dec 10 | Last safe submission for any fix before Apple's holiday break |

## Decisions left to the builder

- How the cover designer is laid out inside the existing cover picker sheet.
- How the sticker art is stored: an SVG asset catalog or code-drawn like the covers.
- Exact prompt wording (31 prompts), in the app's voice: plain, warm, never cute.

## Open questions for the owner

1. Is Plus at $4.99 one-time right, or would you prefer $2.99?
2. Should the "Field Guide" mark on shared videos be on by default? I'd say yes, small, and easy to turn off.
3. Should the December prompts and the holiday card ship in 1.1, or move to a separate 1.1.1 in early December so 1.1 can go out sooner?
