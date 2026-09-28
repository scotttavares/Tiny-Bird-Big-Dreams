# Lull in-app purchases: setup checklist

This is the full path to turn on real purchases in Lull (orb packs, sound packs,
and the Everything bundle) using RevenueCat on top of the App Store.

The code side is already wired. The app talks to RevenueCat only on the native
iOS build, and the web version is untouched. The only value the app is still
waiting on is the RevenueCat public key. Everything below is the account setup
that produces that key and the products behind it.

## The products

Five one time purchases, all Non-Consumable. Use these exact product IDs so they
match what the app asks for.

| What it unlocks | Product ID | Type | Price |
| --- | --- | --- | --- |
| Swirls orb pack | `com.tinybirdbigdreams.lull.pack.swirls` | Non-Consumable | $0.99 |
| Cosmos orb pack | `com.tinybirdbigdreams.lull.pack.cosmos` | Non-Consumable | $0.99 |
| Aura orb pack | `com.tinybirdbigdreams.lull.pack.aura` | Non-Consumable | $0.99 |
| Nature sound pack | `com.tinybirdbigdreams.lull.pack.nature` | Non-Consumable | $0.99 |
| Everything (all packs) | `com.tinybirdbigdreams.lull.everything` | Non-Consumable | $3.99 |

The Everything bundle is what unlocks all current and future packs at once, so
anything added later is already covered for people who bought it.

## One thing to send back

Once RevenueCat is set up, copy the public SDK key for Apple. It starts with
`appl_` and is safe to share (it is a public client key, not a secret). Send that
one string back and the app gets pointed at your account, rebuilt, and pushed.

Do not send tax IDs, SSN, EIN, bank details, or any App Store Connect password.
None of that is needed here, and it should never be pasted into a chat.

## Steps

### 1. App Store Connect: agreements, tax, and banking

In App Store Connect, open Business (agreements, tax, and banking).

- [ ] Sign the Paid Applications Agreement. Paid purchases do not work until this
      shows Active. It can sit in Processing for up to about a day after you sign,
      the banking, and the tax form.
- [ ] Complete the tax form (W-9 for a US individual or sole proprietor).
- [ ] Add a bank account.
- [ ] Wait for the agreement, banking, and tax form to all read Active.
- [ ] Optional but worth it: join the Apple Small Business Program. If you make
      under one million dollars a year from the App Store, Apple's cut drops from
      30 percent to 15 percent. Enrollment is a short form in App Store Connect.

### 2. App Store Connect: create the five purchases

Go to your app, then Monetization, then In-App Purchases.

- [ ] Create each of the five products above as Non-Consumable, using the exact
      product IDs.
- [ ] For each one, set the price tier, add a display name and a short
      description (this is what people read in the store sheet), and upload a
      review screenshot. A quick capture of the store screen inside Lull works.
- [ ] A product can stay in Ready to Submit. It does not have to be approved on
      its own. The five get submitted together with the app version in the last
      step.

### 3. App Store Connect: a sandbox tester

Go to Users and Access, then Sandbox, then Testers.

- [ ] Add a sandbox tester with an email you are not already using for an Apple
      ID. This is the account you sign into on the phone to test buying without
      real money.

### 4. App Store Connect: the key RevenueCat needs

RevenueCat needs to verify purchases with Apple. Give it one of these.

- [ ] Preferred: create an App Store Connect API key (In-App Purchase role is
      enough) under Users and Access, then Integrations. Note the Issuer ID, the
      Key ID, and download the key file once (Apple only lets you download it a
      single time).
- [ ] Or simpler: copy the App-Specific Shared Secret from your app's
      information page.

### 5. RevenueCat: project and app

At app.revenuecat.com.

- [ ] Create a project.
- [ ] Add an App Store app to it, using the bundle ID
      `com.tinybirdbigdreams.lull`.
- [ ] Paste in the App Store Connect API key (Issuer ID, Key ID, and the key
      file) or the shared secret from step 4.

### 6. RevenueCat: products and the entitlement

- [ ] Add all five products to RevenueCat, using the same product IDs.
- [ ] Create an entitlement named exactly `everything`.
- [ ] Attach the `com.tinybirdbigdreams.lull.everything` product to that
      entitlement. This is how the app knows a person owns the full bundle. The
      four individual packs unlock on their own product IDs and do not need an
      entitlement.

### 7. RevenueCat: the public key

- [ ] Open Project settings, then API keys, and copy the public Apple SDK key
      (starts with `appl_`).
- [ ] Send that key back. It gets pasted into the app for both the web repo and
      the native iOS repo, the bundle is rebuilt, and both are pushed.

### 8. Build and test in sandbox

- [ ] Start a Codemagic build so a fresh iOS build carries the RevenueCat key.
- [ ] On the test phone, sign into the sandbox tester account under Settings,
      then App Store, then Sandbox Account.
- [ ] In Lull, buy a pack. Confirm it unlocks.
- [ ] Force quit and reopen, or use Restore, and confirm the unlock sticks.
- [ ] Sandbox purchases are free and reversible, so test as much as you want.

### 9. Submit the version with the purchases

- [ ] In App Store Connect, create a new app version. The live version is 1.0,
      and current builds are 2.1.1, so create version 2.1.1.
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
