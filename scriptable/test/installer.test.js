"use strict"
// Runs "Install Yes or No" against a fake GitHub, using the real script as the download.

const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const { runScript, createScriptable, SCRIPTS_DIR } = require("./scriptable-mock")

const REAL_SCRIPT = fs.readFileSync(path.join(SCRIPTS_DIR, "Yes or No.js"), "utf8")
const REAL_VERSION = /const VERSION = "([^"]+)"/.exec(REAL_SCRIPT)[1]
const SOURCE_URL = "https://raw.githubusercontent.com/tomnorush/Yes-No-Generator/main/scriptable/Yes%20or%20No.js"
const LOCAL_TARGET = "/local/Documents/Yes or No.js"
const ICLOUD_DIR = "/iCloud/Documents/iCloud~dk~simonbs~Scriptable/Documents"

async function install(options) {
  const requested = []
  const env = createScriptable({
    context: "app",
    moduleFilename: "/local/Documents/Install Yes or No.js",
    request: async (url) => {
      requested.push(url)
      return { statusCode: 200, body: REAL_SCRIPT }
    },
    ...options,
  })
  await runScript("Install Yes or No.js", env.globals)
  return { ...env, requested }
}

test("installs the script from the main branch on GitHub", async () => {
  const { files, log, requested } = await install({ alertChoices: [0] })
  assert.deepEqual(requested, [SOURCE_URL])
  assert.equal(files.get(LOCAL_TARGET), REAL_SCRIPT)
  assert.equal(log.alerts[0].title, `Installed Yes or No ${REAL_VERSION}`)
  assert.deepEqual(log.safari, ["scriptable:///run/Yes%20or%20No"], "Open runs the new script")
  assert.equal(log.completed, 1)
})

test("installs into iCloud Drive when Scriptable keeps scripts there", async () => {
  const { files } = await install({
    moduleFilename: "/var/mobile/Library/Mobile Documents/iCloud~dk~simonbs~Scriptable/Documents/Install Yes or No.js",
  })
  assert.equal(files.get(`${ICLOUD_DIR}/Yes or No.js`), REAL_SCRIPT)
  assert.equal(files.has(LOCAL_TARGET), false)
})

test("updates an older copy and says so", async () => {
  const old = REAL_SCRIPT.replace(/const VERSION = "[^"]+"/, 'const VERSION = "0.0.1"')
  const { files, log } = await install({ files: { [LOCAL_TARGET]: old } })
  assert.equal(files.get(LOCAL_TARGET), REAL_SCRIPT)
  assert.equal(log.alerts[0].title, `Updated Yes or No to ${REAL_VERSION}`)
})

test("says when it's already up to date", async () => {
  const { log } = await install({ files: { [LOCAL_TARGET]: REAL_SCRIPT } })
  assert.equal(log.alerts[0].title, `Yes or No ${REAL_VERSION} is up to date`)
})

test("leaves everything alone when GitHub can't be reached", async () => {
  const { files, log } = await install({
    files: { [LOCAL_TARGET]: "previous copy" },
    request: async () => ({ error: "The Internet connection appears to be offline." }),
  })
  assert.equal(files.get(LOCAL_TARGET), "previous copy")
  assert.equal(log.alerts[0].title, "Couldn't download Yes or No")
  assert.match(log.alerts[0].message, /offline/)
})

test("leaves everything alone on an error page or a wrong file", async () => {
  for (const response of [
    { statusCode: 404, body: "404: Not Found" },
    { statusCode: 200, body: "<html>Something else</html>" },
  ]) {
    const { files } = await install({ request: async () => response })
    assert.equal(files.has(LOCAL_TARGET), false, JSON.stringify(response))
  }
})
