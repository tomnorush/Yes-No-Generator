# Yes or No: Instant Answer

A native iPhone and Apple Watch app that does one thing: gives you a yes-or-no answer **the moment you open it**.
Tap anywhere for another. No ads, no subscription, no account, no permissions, and it works offline.

It's built from the research brief in this repo's history ("Yes or No Random Generator / Decision Maker"): the
incumbents are 135–145 MB Unity apps with ads that don't go away after you pay, no Restore Purchases, and
review pop-ups after every use. This app is the opposite: native SwiftUI, a few megabytes, and nothing
between you and the answer.

## How it meets the requirements

| Requirement | How |
|---|---|
| **Core job in under three taps** | Opening the app *is* the answer: it's chosen before the first frame is drawn, so it's on screen at launch with zero taps inside the app. One tap anywhere gives a new one. Siri ("Ask Yes or No") and the Action button give an answer with no taps at all. With a question: tap the field, type, press Go (two taps). |
| **Works offline** | Everything except buying or restoring Pro works with no connection. The app makes no network requests of its own; history is a local file; the privacy policy is bundled so it reads offline too. |
| **No unneeded permissions** | None requested: no location, contacts, photos, notifications, tracking (ATT), microphone or camera. Copy writes to the clipboard but never reads it (no paste prompt). Share sends text only, so no photo-library access is needed. CI fails if a `*UsageDescription` key is ever added. |
| **No ads** | None, and no ad or analytics SDKs; there are no third-party dependencies at all. |
| **No upsell before value** | Pro is never shown as a pop-up, banner, badge or launch screen. It appears only inside Settings, and only after the app has already given 3 answers (`ValueGate` in `YesNoKit`). A UI test checks both sides of that rule. Restore Purchases is always visible, since it's a safety net, not an upsell. |
| **App Store description & keywords** | [`AppStore/`](AppStore/): name, subtitle, keywords, description, promo text, review notes, IAP setup, privacy-label answers, screenshot plan. |
| **Privacy policy that matches the app** | [`docs/privacy.md`](docs/privacy.md). The app collects nothing; the policy says exactly what stays on the device and why. The same file ships inside the app. |

## Features

- **Instant answer** at launch; tap anywhere for a new one, with a light haptic and a quick bounce (no forced animation, and it respects Reduce Motion).
- **Yes / No / Maybe**, one tap away on the main screen.
- **Optional question** ("Pizza tonight?"), kept with the answer for sharing and history.
- **Copy and Share** in one tap: `"Pizza tonight?" Yes or No says: YES`.
- **History** of answers and questions, on-device only, with swipe-to-delete and Clear All (last 50 free, unlimited with Pro).
- **Siri, Shortcuts and the Action button** via App Intents ("Ask Yes or No").
- **Apple Watch app** (independent, watchOS 10+): tap, turn the Digital Crown, or double-tap your fingers for a new answer, plus a complication that opens straight to a fresh answer.
- **Fresh answer after a break**: come back after 5+ minutes and you get a new answer, so an old one is never mistaken for a new one.
- **Light / Dark / System** appearance; VoiceOver labels and announcements; Dynamic Type for all text except the giant answer, which scales to fit.
- **Pro (optional, one-time, StoreKit 2)**: six more color themes, custom odds from 10/90 to 90/10, unlimited history. When odds aren't 50/50, the main screen, history and shared text always say so.

No review prompts, ever.

## Project layout

```
YesNo.xcodeproj           Xcode project (iPhone app, Watch app, complication, UI tests)
Config/Shared.xcconfig    Bundle ID, IAP product ID, team, version: the only file to edit before shipping
YesNoKit/                 Swift package with all app logic (Foundation only, unit tested)
  Sources/YesNoKit/         Answer, Odds, Decider, History, Preferences, ValueGate, ShareText, ...
  Tests/YesNoKitTests/      swift test --package-path YesNoKit
YesNo/                    iPhone app (SwiftUI)
  Model/                    AppModel (state), Theme (colors)
  Store/                    ProStore (StoreKit 2: purchase, restore, entitlements)
  Views/                    DecisionView (main screen), History, Settings, Privacy Policy
  Intents/                  Siri / Shortcuts / Action button
YesNoWatch/               Apple Watch app
YesNoWatchWidget/         Watch complication (WidgetKit)
YesNoUITests/             UI tests for the core promises
YesNo.storekit            Local StoreKit config: test purchases in the Simulator without App Store Connect
docs/                     GitHub Pages site: privacy policy, support page
AppStore/                 Listing text (fastlane deliver layout) and submission notes
scripts/                  Project generator, icon generator, metadata checker
```

Targets: iOS 17+, watchOS 10+. Built and tested in CI with Xcode 26.

## Run it

1. Open `YesNo.xcodeproj` in Xcode 16 or later.
2. Pick the **YesNo** scheme and an iPhone simulator, then Run. Purchases in the Simulator use `YesNo.storekit`
   automatically; if Xcode shows no StoreKit configuration, select it under Product → Scheme → Edit Scheme → Run → Options.
3. For the watch app, pick the **YesNoWatch** scheme and a watch simulator.

Tests:

```sh
swift test --package-path YesNoKit                                                  # logic
xcodebuild test -project YesNo.xcodeproj -scheme YesNo \
  -destination 'platform=iOS Simulator,name=iPhone 17'                             # UI
```

## Before submitting to the App Store

1. **Identifiers**: in `Config/Shared.xcconfig`, set `BUNDLE_ID_BASE` to your own reverse-DNS ID and `DEVELOPMENT_TEAM`
   to your Team ID (or pick the team in Signing & Capabilities). The watch app, complication and the Pro product ID derive
   from `BUNDLE_ID_BASE`. If you change it, update `productID` in `YesNo.storekit` to match.
2. **In-app purchase**: create the Non-Consumable described in [`AppStore/README.md`](AppStore/README.md).
3. **Privacy policy and support pages**: in the GitHub repo settings, enable Pages from the `main` branch, `/docs` folder.
   The URLs in `AppStore/metadata/en-US/*_url.txt` and `AppInfo.supportURL` then work as written. The policy's contact
   is GitHub Issues, which is public; consider adding a private email address to `docs/privacy.md`.
4. **App Store Connect**: paste the listing from `AppStore/`, answer the privacy questions with "Data Not Collected",
   add the review notes, and upload screenshots.
5. **Icon**: `scripts/make_icons.py` draws the included icon; replace `AppIcon.png` in both asset catalogs if you have your own.

If you add or remove source files outside Xcode, regenerate the project with `ruby scripts/generate_project.rb`
(`gem install xcodeproj` first). Files added inside Xcode need nothing extra.
