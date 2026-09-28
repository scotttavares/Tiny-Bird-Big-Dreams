# Lull in-app purchases: setup checklist

This is the full path to turn on real purchases in Lull (orb packs, sound packs,
and the Everything bundle) using RevenueCat on top of the App Store.

Most of it is now done. The code is wired, the products exist, RevenueCat is
configured, and the public key is live in both repos. What is left is testing a
real purchase in sandbox and submitting the app version. See the status below.

## Where things stand (as of September 28, 2026)

Done:

- [x] Five products created in App Store Connect (all Non-Consumable)
- [x] In-App Purchase key generated in App Store Connect and uploaded to
      RevenueCat (RevenueCat shows "Valid credentials")
- [x] RevenueCat project and App Store app created (bundle
      `com.tinybirdbigdreams.lull`)
- [x] All five products added to RevenueCat
- [x] `everything` entitlement created, with the Everything product attached
- [x] Public `appl_` key received and set in both repos (the `RC_IOS_KEY` value),
      bundles rebuilt, committed, and pushed
- [x] Tax form (W-9) Active

Waiting on Apple:

- [ ] Paid Applications Agreement: was Processing. Purchases and sandbox product
      fetch generally do not work until this reads Active (up to about a day).
- [ ] Banking: was Processing.

Still to do:

- [ ] Create a sandbox tester
- [ ] Kick a Codemagic build, then test a real purchase and Restore in sandbox
- [ ] Create App Store version 2.1.1, attach the build, add the five in-app
      purchases, and submit them together

## The products

Five one time purchases, all Non-Consumable. These are the exact product IDs the
app asks for.

| What it unlocks | Product ID | Type | Price |
| --- | --- | --- | --- |
| Swirls orb pack | `com.tinybirdbigdreams.lull.pack.swirls` | Non-Consumable | $0.99 |
| Cosmos orb pack | `com.tinybirdbigdreams.lull.pack.cosmos` | Non-Consumable | $0.99 |
| Aura orb pack | `com.tinybirdbigdreams.lull.pack.aura` | Non-Consumable | $0.99 |
| Nature sound pack | `com.tinybirdbigdreams.lull.pack.nature` | Non-Consumable | $0.99 |
| Everything (all packs) | `com.tinybirdbigdreams.lull.everything` | Non-Consumable | $3.99 |

The Everything bundle unlocks all current and future packs at once, so anything
added later is already covered for people who bought it.

## Security note

The `appl_` key is a public client key. It ships inside the app and is safe to
share. Everything else is not: never paste tax IDs, SSN, EIN, bank details, the
`.p8` key file contents, or any App Store Connect password into a chat. None of
that is needed.

## Steps

### 1. App Store Connect: agreements, tax, and banking

In App Store Connect, open Business (agreements, tax, and banking).

- [x] Complete the tax form (W-9 for a US individual or sole proprietor). Active.
- [ ] Sign the Paid Applications Agreement. Signed, was Processing. Paid
      purchases do not work until this reads Active. It can sit in Processing for
      up to about a day.
- [ ] Add a bank account. Added, was Processing.
- [ ] Wait for the agreement and banking to read Active.
- [x] Apple Small Business Program: appears enrolled. The proceeds shown in App
      Store Connect were 85 percent, which is the reduced 15 percent commission.

### 2. App Store Connect: create the five purchases

Your app, then Monetization, then In-App Purchases.

- [x] Created all five as Non-Consumable, using the exact product IDs.
- [x] Set price ($0.99 for the four packs, $3.99 for Everything), added an
      English (U.S.) display name and description for each.
- [x] All five sit at Prepare for Submission. That is the correct state. They do
      not get submitted on their own. They ride along with the app version in the
      last step. Do not click Add for Review yet.

### 3. App Store Connect: a sandbox tester

Users and Access, then Sandbox, then Testers.

- [ ] Add a sandbox tester with an email you are not already using for an Apple
      ID. This is the account you sign into on the phone to buy without real
      money.

### 4. App Store Connect: the key RevenueCat needs

- [x] Created an In-App Purchase key under Users and Access, then Integrations,
      then In-App Purchase. Downloaded the `.p8` (only downloadable once), and
      kept the Key ID and Issuer ID. This is the key RevenueCat validates
      purchases with. Required for StoreKit 2, which Lull uses.

### 5. RevenueCat: project and app

At app.revenuecat.com.

- [x] Created a project (Lull: Calm Breathing).
- [x] Added an App Store app with bundle ID `com.tinybirdbigdreams.lull`.
- [x] Uploaded the `.p8` In-App Purchase key with its Key ID and Issuer ID.
      RevenueCat confirmed "Valid credentials".

### 6. RevenueCat: products and the entitlement

- [x] Added all five products, using the same product IDs. They read "Could not
      check" for now, which is expected until Apple approves them. It clears after
      review and does not block sandbox testing.
- [x] Created an entitlement named exactly `everything`.
- [x] Attached the `com.tinybirdbigdreams.lull.everything` product to that
      entitlement. This is how the app knows a person owns the full bundle. The
      four individual packs unlock on their own product IDs and do not need an
      entitlement.

### 7. RevenueCat: the public key

- [x] Copied the public Apple SDK key (starts with `appl_`) from API keys.
- [x] Set it as `RC_IOS_KEY` in both the web repo and the native iOS repo, rebuilt
      the bundle, bumped the service worker, committed, and pushed. The app now
      points at your RevenueCat account.

### 8. Build and test in sandbox

- [ ] Start a Codemagic build from `main` so a fresh iOS build carries the key.
      A push to `main` may auto-start one. Codemagic re-bundles from source and
      syncs the key into the iOS app on every build.
- [ ] On the test phone, sign into the sandbox tester under Settings, then App
      Store, then Sandbox Account.
- [ ] In Lull, buy a pack. Confirm it unlocks.
- [ ] Force quit and reopen, or use Restore, and confirm the unlock sticks.
- [ ] If the store screen shows no prices or an empty list, the Paid Applications
      Agreement is most likely still Processing. Wait for it to read Active, then
      retry. Sandbox purchases are free and reversible.

### 9. Submit the version with the purchases

- [ ] In App Store Connect, create a new app version. The live version is 1.0 and
      current builds are 2.1.1, so create version 2.1.1.
- [ ] Attach the build from Codemagic.
- [ ] In that version, add the five in-app purchases so they are reviewed and
      released together with the app.
- [ ] Submit for review.

## How the app decides someone owns something

- The `everything` entitlement being active unlocks the full bundle, now and for
  anything added later.
- Otherwise each owned product ID maps straight to the pack it unlocks.
- Restore pulls past purchases back from Apple through RevenueCat, so a new phone
  or a reinstall gets everything the person already paid for.

## Fees, briefly

- Apple takes 30 percent, or 15 percent on the Small Business Program.
- RevenueCat is free up to a monthly revenue threshold, then takes a small
  percentage above it. For an app at this stage it is effectively free.
