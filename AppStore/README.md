# App Store listing

Everything App Store Connect asks for, ready to paste. The text files in `metadata/en-US/` use the
[fastlane deliver](https://docs.fastlane.tools/actions/deliver/) layout, so `fastlane deliver` can upload
them as they are. `python3 scripts/check_metadata.py` (also run in CI) checks every length limit.

| Field | Value | Limit |
|---|---|---|
| Name | Yes or No: Instant Answer | 25 / 30 |
| Subtitle | One-tap decision maker, no ads | 30 / 30 |
| Keywords | see below | 98 / 100 |
| Promotional text | `metadata/en-US/promotional_text.txt` | 148 / 170 |
| Description | `metadata/en-US/description.txt` | 1,686 / 4,000 |
| Primary category | Utilities | |
| Secondary category | Lifestyle | |
| Price | Free, with one optional in-app purchase | |
| Age rating | 4+ (answer "None" to every question) | |
| Privacy policy URL | https://tomnorush.github.io/Yes-No-Generator/privacy | |
| Support URL | https://tomnorush.github.io/Yes-No-Generator/support | |
| Marketing URL | https://tomnorush.github.io/Yes-No-Generator/ | |

## Keywords

```
coin,flip,toss,random,generator,decide,choice,chooser,picker,maybe,question,undecided,oracle,watch
```

How the list was built, from the research brief:

- **"yes or no"** (primary) and **"decision maker"** (secondary) are in the name and subtitle, which carry
  the most search weight, so they are not repeated here (repeats waste characters).
- **"yes no generator"**, **"random decision"**, **"coin flip"** are covered by `generator`, `random`,
  `decide`, `coin`, `flip`, `toss`, combined with the name.
- `maybe` matches the Yes / No / Maybe mode; `watch` catches "yes no watch" searches for the Apple Watch app.
- Left out on purpose: trademarked terms (such as "Magic 8 Ball"), competitor names, and features the app
  doesn't have ("wheel", "dice"). They risk rejection under guideline 2.3.7 and attract the wrong users.

The subtitle's "no ads" is a factual feature claim. If App Review ever objects, use
"The one-tap decision maker" (26 characters) instead.

## App Privacy ("nutrition label")

Answer **"No, we do not collect data from this app."** The label then reads **Data Not Collected**.

Why that is accurate, point by point (see `docs/privacy.md` for the full policy):

- No analytics, crash-reporting, advertising or other third-party SDKs; the only dependency is the
  local `YesNoKit` package in this repository.
- The app makes no network requests of its own. The only network traffic is Apple's StoreKit for the
  optional purchase, which Apple handles.
- History and settings are stored only on the device (`Application Support/YesNo/history.json` and
  `UserDefaults`).
- `PrivacyInfo.xcprivacy` in both apps declares no tracking, no tracking domains, no collected data,
  and one required-reason API: `UserDefaults` with reason `CA92.1` (the app's own data).
- The app requests no permissions (CI fails if a `*UsageDescription` key is ever added).

Tracking: **No**. Sign-in required: **No**.

## In-app purchase

Create one **Non-Consumable** in App Store Connect → your app → Monetization → In-App Purchases.

| Field | Value |
|---|---|
| Reference name | Yes or No Pro |
| Product ID | `com.tomnorush.yesno.pro` (must equal `PRO_PRODUCT_ID` in `Config/Shared.xcconfig`) |
| Price | $1.99 (the research brief suggests $0.99–1.99) |
| Family Sharing | On (recommended) |
| Display name | Yes or No Pro |
| Description (55 max) | Color themes, custom odds and unlimited history. |
| Review screenshot | Settings, scrolled to the "Yes or No Pro" section |

Submit the in-app purchase together with the first app version.

## Notes for App Review

Paste into App Review Information → Notes:

> Yes or No shows a random yes/no answer the moment it opens; tap anywhere for a new one. There is no
> login and no network content.
>
> The optional one-time purchase "Yes or No Pro" is deliberately not shown until the app has given
> three answers. To find it: tap the big answer twice, then tap the gear icon (bottom right) and scroll to
> "Yes or No Pro". "Restore Purchases" is always visible in Settings under "Purchases".
>
> Siri: say "Ask Yes or No". Apple Watch: the watch app is included and runs independently.

## Export compliance

The app uses no encryption beyond what iOS provides. `ITSAppUsesNonExemptEncryption` is set to `NO`
in `YesNo/Info.plist`, so App Store Connect won't ask on every upload.

## Screenshots

Required: 6.9" iPhone (1320 × 2868), 13" iPad (2064 × 2752, because the app runs on iPad) and, because
the Apple Watch app is included, Apple Watch screenshots at the size App Store Connect lists for the
current largest watch.

Suggested set and captions, in order (the first two appear in search results):

1. Big **YES** on the Classic green: "Your answer, the moment you open it."
2. Question typed ("Pizza tonight?") with **NO**: "Type a question, or don't."
3. Yes / No / Maybe selected with **MAYBE**: "Not every question is yes or no."
4. Apple Watch showing **YES**: "Decide from your wrist."
5. History list: "What did you decide last time?"
6. Settings with theme swatches: "No ads. No subscription. No tracking."

Take them in the Simulator with the `YesNo` scheme (File → Save Screen, or `xcrun simctl io booted screenshot`).
