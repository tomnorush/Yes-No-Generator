# Install on your own iPhone (no App Store Connect)

Use the **Offline** build to try the app on your own devices before anything goes near the App Store:

- Every feature is unlocked (all color themes, custom odds, unlimited history).
- Purchases are switched off and StoreKit is never used, so no App Store Connect setup is needed.
- The app makes no network requests at all. Settings shows an **Offline Build** section so you can tell it apart.

There are two ways to get it onto your iPhone. Both work with a free Apple ID.

| | You need | Watch app | Re-install |
|---|---|---|---|
| **A. Xcode** (recommended) | A Mac with Xcode 26, a USB cable | Yes | Every 7 days with a free Apple ID, yearly with a paid developer account |
| **B. Download the .ipa and sideload** | Any Mac or Windows PC, a USB cable | Usually | Every 7 days with a free Apple ID |

## A. With a Mac and Xcode

1. **Install Xcode 26** from the Mac App Store and open it once to finish setup.
2. **Add your Apple ID**: Xcode → Settings → Accounts → **+** → Apple ID. A free account creates a "Personal Team".
3. **Get the code**: `git clone https://github.com/tomnorush/Yes-No-Generator.git`, then open `YesNo.xcodeproj`.
4. **Choose your team** for the three app targets. Click the blue **YesNo** project at the top of the file list, then for each of
   **YesNo**, **YesNoWatch** and **YesNoWatchWidget**: Signing & Capabilities → Team → your Personal Team.
   (Or put your Team ID once in `Config/Shared.xcconfig` as `DEVELOPMENT_TEAM = ABCDE12345`.)
5. **If Xcode says the bundle identifier isn't available**, open `Config/Shared.xcconfig` and change
   `BUNDLE_ID_BASE` to something unique to you, like `com.yourname.yesno`.
6. **Prepare the iPhone**: connect it with a cable and tap **Trust** on the phone. Then on the iPhone:
   Settings → Privacy & Security → **Developer Mode** → On, and restart when asked.
   (The Developer Mode switch appears after the phone has been connected to Xcode once.)
7. **Run it**: in Xcode's toolbar pick the **YesNo Offline** scheme and your iPhone as the destination, then press **Run** (⌘R).
8. **First launch only**: if the iPhone says "Untrusted Developer", go to Settings → General →
   VPN & Device Management → your Apple ID → **Trust**, then open the app again.

**Apple Watch**: the watch app is inside the iPhone app. If your watch is paired, open the Watch app on the
iPhone → My Watch → scroll to **Yes or No** → Install. To run it straight from Xcode instead, choose the
**YesNoWatch** scheme and your watch (turn on Developer Mode on the watch first: Settings → Privacy & Security).

**Siri**: after the first launch, say "Ask Yes or No". You can also add "Get a Yes or No" to the Action button
(Settings → Action Button → Shortcut).

With a free Apple ID the install expires after 7 days; run it from Xcode again to renew it. Your history and
settings are kept.

## B. Without a Mac: download the .ipa and sideload

1. **Download the build.** On GitHub open **Actions** → **Offline build (.ipa)** → the latest green run →
   **Artifacts** → **YesNo-Offline-ipa**, then unzip it. It contains:
   - `YesNo-Offline.ipa`: the iPhone app with the Apple Watch app inside
   - `YesNo-Offline-iPhoneOnly.ipa`: the iPhone app alone. Use this one if the sideloading tool rejects the watch app or complains about the App ID limit.

   Pushing a version tag (for example `git tag v0.1.0 && git push origin v0.1.0`) also attaches both files to a
   GitHub Release, which is easier to find later.
2. **Install a sideloading tool** on your computer, for example [Sideloadly](https://sideloadly.io) (Windows and Mac) or
   [AltStore](https://altstore.io). These tools sign the .ipa with your Apple ID so the iPhone accepts it.
   Both ask for your Apple ID password, which they send to Apple to create the signing certificate. If you're not
   comfortable with that, use a secondary Apple ID or route A.
3. **Connect the iPhone** with a cable, drop the .ipa into the tool, enter your Apple ID and start.
4. **On the iPhone**: turn on Developer Mode (Settings → Privacy & Security → Developer Mode) and trust your
   Apple ID under Settings → General → VPN & Device Management, as in steps 6 and 8 above.

With a free Apple ID the app stops opening after 7 days; sideload it again to renew it.

## Build the .ipa yourself

On a Mac with Xcode 26:

```sh
scripts/build_offline_ipa.sh        # writes build/YesNo-Offline.ipa and build/YesNo-Offline-iPhoneOnly.ipa
```

The files are unsigned on purpose: the sideloading tool (or Xcode) signs them with your own Apple ID.

## What to try

- Open the app: the answer is already there. Tap anywhere for another.
- Switch to **Yes / No / Maybe** at the top.
- Type a question, press **Go**, then Copy or Share the result.
- Open **History**, swipe to delete an entry, try **Clear All**.
- In **Settings**: every color theme, the odds slider (the main screen shows the odds when they aren't 50/50), light/dark mode, haptics.
- Turn on Airplane Mode: everything keeps working.
- Leave the app for 5+ minutes and come back: you get a fresh answer.
- Siri: "Ask Yes or No".
- Apple Watch: tap, turn the crown, or double-tap your fingers (Series 9 and later) for another answer. Add the complication to a watch face.

## Going to the App Store later

The regular **YesNo** scheme (Debug and Release configurations) is the App Store version with the optional Pro
purchase. The README has the checklist for that. The Offline configuration never needs to be uploaded.
