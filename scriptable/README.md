# Yes or No for Scriptable

The Yes or No app as a single [Scriptable](https://apps.apple.com/app/scriptable/id1405459188) script.
Run it, and the answer is already on screen. Tap the answer for another.
Nothing to build, no Xcode, no App Store account: install Scriptable (free) and add one script.

- **Instant**: the answer is picked before the screen appears. Tap anywhere on it for a new one.
- **Yes / No / Maybe** switch at the top.
- **Optional question**, kept with the answer. **Copy** and **Share** in one tap.
- **History** of your last 200 answers, kept only on this iPhone. Delete one, or clear them all.
- **Settings**: 7 color themes (Classic follows light/dark mode), odds from 10/90 to 90/10, history on/off.
  When the odds aren't 50/50, the screen and anything you share say so.
- **Widgets** for the Home Screen and Lock Screen. Tap one for a fresh answer.
- **Siri, Shortcuts, the Action button and the share sheet** (shared text becomes the question).
- **Offline and private**: no network, no permissions, no tracking. Everything is free; there are no purchases.

## Install

You need an iPhone or iPad with [Scriptable](https://apps.apple.com/app/scriptable/id1405459188) (free, by Simon B. Støvring).
Open Scriptable once after installing it.

### Option 1: the installer (recommended, also updates)

1. On your iPhone, open
   [**Install Yes or No.js**](https://github.com/tomnorush/Yes-No-Generator/blob/main/scriptable/Install%20Yes%20or%20No.js)
   and tap the **copy** button above the code (**Copy raw file**).
   If you don't see it, tap **Raw**, then touch and hold the text → **Select All** → **Copy**.
2. In Scriptable, tap **+** (top right) to start a new script, then paste.
3. Tap the title at the top ("Untitled Script"), rename it to `Install Yes or No`, and tap **Done**.
4. Tap the **▶︎** button (bottom right). It downloads **Yes or No** into your scripts.
   Tap **Open Yes or No** to try it.

To update later, run **Install Yes or No** again. Your history and settings are kept.
The installer is the only part that uses the internet, and only when you run it.

### Option 2: copy and paste the script

1. Open [**Yes or No.js**](https://github.com/tomnorush/Yes-No-Generator/blob/main/scriptable/Yes%20or%20No.js)
   and copy it the same way (**Copy raw file**, or **Raw** → **Select All** → **Copy**).
2. In Scriptable tap **+**, paste, and rename the script to exactly `Yes or No`. Tap **Done**.

To update, replace its contents with the latest version the same way.

### Option 3: the Files app

If Scriptable keeps scripts in iCloud Drive (Scriptable → Settings), you can download
[the raw file](https://raw.githubusercontent.com/tomnorush/Yes-No-Generator/main/scriptable/Yes%20or%20No.js)
in Safari, then Share → **Save to Files** → iCloud Drive → **Scriptable**. Name it `Yes or No.js`.

## Use it

### 1. In Scriptable

Tap **Yes or No** in your scripts. The answer is already there; tap it for another.

### 2. Siri, the Action button and a Home Screen icon

These all use one shortcut:

1. Open the **Shortcuts** app → **+** → **Add Action** → search for **Run Script** (Scriptable).
2. In the action, choose the script **Yes or No**. Leave **Run In App** off for a quick pop-up with **Again** and
   **Copy**, or turn it on to open the full screen.
3. Name the shortcut `Yes or No` (tap its name at the top) and tap **Done**.

Then:

- **Siri**: say "Hey Siri, Yes or No". Siri says and shows the answer.
- **Action button** (iPhone 15 Pro and later): Settings → **Action Button** → **Shortcut** → **Yes or No**.
- **Home Screen icon**: in Shortcuts, touch and hold the shortcut → **Share** → **Add to Home Screen**.
  One tap from your Home Screen gives an answer.
- **Other shortcuts**: the action's input becomes the question, and its output is `YES`, `NO` or `MAYBE`.

### 3. Widgets

- **Home Screen**: touch and hold the Home Screen → **Edit** → **Add Widget** → **Scriptable** → pick a size →
  **Add Widget**. Touch and hold the new widget → **Edit Widget** → set **Script** to **Yes or No** and
  **When Interacting** to **Run Script**.
- **Lock Screen**: touch and hold the Lock Screen → **Customize** → **Lock Screen** → tap the widget area →
  **Scriptable** → pick a round, rectangular or inline widget, then tap it and choose **Yes or No**.

The widgets show your **last** answer and when you got it, never a new one, so an old answer is never mistaken
for a fresh one. Tap the widget for a new answer. iOS decides how often widgets refresh, so a widget can lag a
little behind the app.

### 4. Share sheet

Select text anywhere (a message, a note), tap **Share** → **Run Script** → **Yes or No**. The text becomes the
question. If the script isn't listed, open it in Scriptable, tap the settings button, and turn on **Text** under
**Share Sheet Inputs**.

### 5. Link

`scriptable:///run/Yes%20or%20No?question=Pizza%20tonight%3F` runs it with a question, from any app that opens links.

## Privacy

- No network access, no ads, no analytics, no tracking, and no permissions to grant.
- History and settings are saved in one file, `yes-or-no/state.json`, in Scriptable's **local** Library folder on
  this device. It isn't synced to iCloud, even if your scripts are.
- Turn history off or clear it in **Settings**. Deleting the script and that folder (or Scriptable itself) removes everything.
- Siri, Shortcuts and the share sheet are handled by Apple under Apple's privacy policy. Copy and Share only send what you choose.
- The only times anything goes online: when you run **Install Yes or No**, and when you tap **Help and updates**
  in Settings, which opens this page in Safari.

## Compared with the App Store app

| | Scriptable script | iPhone app |
|---|---|---|
| Install | Scriptable + one script | Xcode, sideloading or the App Store |
| Answer at launch, tap for another, Yes/No/Maybe, question, Copy/Share | ✓ | ✓ |
| History | Last 200 | Last 50, or unlimited with Pro |
| Themes and custom odds | ✓ free | With Pro |
| Widgets | Home and Lock Screen | Apple Watch complication |
| Siri / Action button / share sheet | ✓ via Shortcuts | ✓ |
| Apple Watch app, haptics | — | ✓ |

## Troubleshooting

- **"Couldn't download Yes or No"**: check your internet connection and run the installer again.
- **Tapping the widget opens the editor instead of answering**: edit the widget and set When Interacting to **Run Script**.
- **Siri, the shortcut or the installer's Open button can't find the script**: the script must be named exactly `Yes or No`.
- **The colors look wrong in dark mode**: the Classic theme follows the system appearance; the other themes look the same in both.

## For developers

The script is plain JavaScript checked against Scriptable's API definitions
([`@types/scriptable-ios`](https://www.npmjs.com/package/@types/scriptable-ios)) and tested in Node with a
mocked Scriptable runtime. Nothing in this folder except the two `.js` scripts is needed on the phone.

```sh
cd scriptable
npm ci
npm run typecheck   # every Scriptable call must exist with the right types
npm test            # core logic, plus the app, widgets, Siri, Shortcuts, share sheet and installer with simulated taps
```

The core logic (odds, answers, share text, history) matches the iPhone app's `YesNoKit`, and the tests check the
same cases. CI runs both on every push.
