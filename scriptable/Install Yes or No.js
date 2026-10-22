// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: deep-green; icon-glyph: download;

/*
 * Installs or updates the "Yes or No" script from GitHub.
 * https://github.com/tomnorush/Yes-No-Generator/tree/main/scriptable
 *
 * Run it once to install, and again whenever you want the latest version.
 * This installer is the only part of the project that uses the network, and only when you run it.
 */

const SCRIPT_NAME = "Yes or No"
const SOURCE_URL = "https://raw.githubusercontent.com/tomnorush/Yes-No-Generator/main/scriptable/Yes%20or%20No.js"

/** The version written in a copy of the script, e.g. "1.0.0", or null. */
function versionOf(code) {
  const match = /const VERSION = "([^"]+)"/.exec(code || "")
  return match ? match[1] : null
}

async function showMessage(title, message, actions = []) {
  const alert = new Alert()
  alert.title = title
  alert.message = message
  for (const action of actions) alert.addAction(action)
  alert.addCancelAction("Done")
  return alert.presentAlert()
}

async function install() {
  // Save next to this installer: in iCloud Drive if Scriptable uses iCloud, otherwise on this device.
  const fm = module.filename.includes("Documents/iCloud~") ? FileManager.iCloud() : FileManager.local()
  const target = fm.joinPath(fm.documentsDirectory(), `${SCRIPT_NAME}.js`)

  let code
  try {
    const request = new Request(SOURCE_URL)
    request.timeoutInterval = 30
    code = await request.loadString()
    const status = request.response && request.response.statusCode
    if (status !== 200) throw new Error(`GitHub answered with status ${status}.`)
  } catch (error) {
    await showMessage("Couldn't download Yes or No", `${error.message || error}\n\nCheck your connection and try again.`)
    return
  }

  const newVersion = versionOf(code)
  if (!newVersion || !code.includes("icon-glyph")) {
    await showMessage("Download looks wrong", "The file from GitHub isn't the Yes or No script, so nothing was changed.")
    return
  }

  let oldVersion = null
  if (fm.fileExists(target)) {
    if (fm.isFileStoredIniCloud(target) && !fm.isFileDownloaded(target)) await fm.downloadFileFromiCloud(target)
    oldVersion = versionOf(fm.readString(target))
  }

  fm.writeString(target, code)

  const title = oldVersion === null
    ? `Installed Yes or No ${newVersion}`
    : oldVersion === newVersion
      ? `Yes or No ${newVersion} is up to date`
      : `Updated Yes or No to ${newVersion}`
  const choice = await showMessage(
    title,
    "Find it in your Scriptable scripts. Your history and settings are kept.",
    ["Open Yes or No"]
  )
  if (choice === 0) {
    Safari.open(`scriptable:///run/${encodeURIComponent(SCRIPT_NAME)}`)
  }
}

// @ts-ignore: Scriptable runs scripts inside an async function, so top-level await is allowed.
await install()
Script.complete()
