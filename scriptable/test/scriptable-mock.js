"use strict"
// A small stand-in for Scriptable's runtime, enough to run the scripts in Node.
// API names and signatures are checked separately by `npm run typecheck` against
// Scriptable's type definitions; these mocks only need to behave plausibly.

const fs = require("node:fs")
const path = require("node:path")

const SCRIPTS_DIR = path.join(__dirname, "..")
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor

/** Runs a script file the way Scriptable does: as the body of an async function, with the given globals. */
function runScript(fileName, globals) {
  const source = fs.readFileSync(path.join(SCRIPTS_DIR, fileName), "utf8")
  const names = Object.keys(globals)
  return new AsyncFunction(...names, source)(...names.map((name) => globals[name]))
}

/** The core logic of "Yes or No", loaded without Scriptable globals. */
async function loadCore() {
  const module = { exports: {} }
  await runScript("Yes or No.js", { module })
  return module.exports
}

/**
 * Builds Scriptable globals.
 * - context: "app" | "widget" | "siri" | "shortcuts" | "share"
 * - interactions: functions called in order each time a UITable is presented,
 *   receiving the table, to simulate taps while it is on screen.
 * - alertChoices: indexes returned by successive alerts (-1 = cancel), or
 *   { choice, text } to also fill the first text field.
 */
function createScriptable({
  context = "app",
  widgetFamily = null,
  args = {},
  files = {},
  interactions = [],
  alertChoices = [],
  request = async () => ({ statusCode: 200, body: "" }),
  moduleFilename = "/local/Documents/Yes or No.js",
} = {}) {
  const log = {
    tables: [],
    alerts: [],
    widgets: [],
    previews: [],
    spoken: [],
    copied: [],
    shared: [],
    safari: [],
    output: undefined,
    completed: 0,
  }
  const store = new Map(Object.entries(files))
  const directories = new Set()
  const pendingInteractions = [...interactions]
  const pendingChoices = [...alertChoices]

  class Color {
    constructor(hex, alpha = 1) {
      this.hex = hex
      this.alpha = alpha
    }
    static dynamic(light, dark) {
      const color = new Color(light.hex)
      color.dark = dark
      return color
    }
    static gray() { return new Color("#8E8E93") }
    static red() { return new Color("#FF3B30") }
    static white() { return new Color("#FFFFFF") }
    static black() { return new Color("#000000") }
  }

  const Font = new Proxy({}, { get: (_, name) => (size) => ({ name: String(name), size }) })

  class UITableCell {
    constructor(kind, title, subtitle) {
      this.kind = kind
      this.title = title
      this.subtitle = subtitle
      this.widthWeight = 1
      this.dismissOnTap = false
      this.alignment = "left"
    }
    static text(title, subtitle) { return new UITableCell("text", title, subtitle) }
    static button(title) { return new UITableCell("button", title) }
    leftAligned() { this.alignment = "left" }
    centerAligned() { this.alignment = "center" }
    rightAligned() { this.alignment = "right" }
  }

  class UITableRow {
    constructor() {
      this.cells = []
      this.height = 44
      this.isHeader = false
      this.dismissOnSelect = true
      this.cellSpacing = 0
    }
    addCell(cell) { this.cells.push(cell) }
    addText(title, subtitle) {
      const cell = UITableCell.text(title, subtitle)
      this.cells.push(cell)
      return cell
    }
    addButton(title) {
      const cell = UITableCell.button(title)
      this.cells.push(cell)
      return cell
    }
  }

  class UITable {
    constructor() {
      this.rows = []
      this.showSeparators = true
      this.reloads = 0
    }
    addRow(row) { this.rows.push(row) }
    removeRow(row) { this.rows = this.rows.filter((r) => r !== row) }
    removeAllRows() { this.rows = [] }
    reload() { this.reloads += 1 }
    async present(fullscreen = false) {
      this.fullscreen = fullscreen
      log.tables.push(this)
      const interaction = pendingInteractions.shift()
      if (interaction) await interaction(this)
    }
    /** Test helper: the first row with a cell whose title matches. */
    row(match) {
      return this.rows.find((row) => row.cells.some((cell) => matches(cell.title, match)))
    }
    /** Test helper: the first button cell whose title matches. */
    button(match) {
      for (const row of this.rows) {
        const cell = row.cells.find((c) => c.kind === "button" && matches(c.title, match))
        if (cell) return cell
      }
      return undefined
    }
  }

  function matches(title, match) {
    if (typeof title !== "string") return false
    return match instanceof RegExp ? match.test(title) : title === match
  }

  class Alert {
    constructor() {
      this.title = ""
      this.message = ""
      this.actions = []
      this.fields = []
      this.typed = []
    }
    addAction(title) { this.actions.push({ title, style: "default" }) }
    addDestructiveAction(title) { this.actions.push({ title, style: "destructive" }) }
    addCancelAction(title) { this.cancel = title }
    addTextField(placeholder, text) { this.fields.push({ placeholder, text: text || "" }) }
    addSecureTextField(placeholder, text) { this.addTextField(placeholder, text) }
    textFieldValue(index) { return this.typed[index] !== undefined ? this.typed[index] : this.fields[index].text }
    async presentAlert() { return this.respond() }
    async presentSheet() { return this.respond() }
    async present() { return this.respond() }
    respond() {
      log.alerts.push(this)
      const next = pendingChoices.length ? pendingChoices.shift() : -1
      if (typeof next === "object") {
        if (next.text !== undefined) this.typed[0] = next.text
        return next.choice
      }
      return next
    }
  }

  class WidgetText {
    constructor(text) { this.text = text }
    leftAlignText() {}
    centerAlignText() {}
    rightAlignText() {}
  }

  class WidgetDate {
    constructor(date) { this.date = date }
    applyRelativeStyle() { this.style = "relative" }
    applyTimeStyle() { this.style = "time" }
    leftAlignText() {}
    centerAlignText() {}
    rightAlignText() {}
  }

  class ListWidget {
    constructor() { this.items = [] }
    addText(text) {
      const item = new WidgetText(text)
      this.items.push(item)
      return item
    }
    addDate(date) {
      const item = new WidgetDate(date)
      this.items.push(item)
      return item
    }
    addSpacer(length) { this.items.push({ spacer: length }) }
    setPadding(top, leading, bottom, trailing) { this.padding = [top, leading, bottom, trailing] }
    async presentSmall() { log.previews.push(this) }
    /** Test helper: all text shown, in order. */
    texts() { return this.items.filter((item) => typeof item.text === "string").map((item) => item.text) }
  }

  function fileManager(documents) {
    return {
      joinPath: (a, b) => `${a.replace(/\/$/, "")}/${b}`,
      libraryDirectory: () => "/local/Library",
      documentsDirectory: () => documents,
      fileExists: (p) => store.has(p) || directories.has(p),
      readString: (p) => {
        if (!store.has(p)) throw new Error(`No such file: ${p}`)
        return store.get(p)
      },
      writeString: (p, text) => {
        const parent = p.slice(0, p.lastIndexOf("/"))
        if (!directories.has(parent) && !parent.endsWith("Documents")) throw new Error(`Missing directory: ${parent}`)
        store.set(p, text)
      },
      createDirectory: (p) => { directories.add(p) },
      isFileStoredIniCloud: () => documents.includes("iCloud~"),
      isFileDownloaded: () => true,
      downloadFileFromiCloud: async () => {},
    }
  }

  class Request {
    constructor(url) {
      this.url = url
      this.response = undefined
    }
    async loadString() {
      const { statusCode, body, error } = await request(this.url)
      if (error) throw new Error(error)
      this.response = { statusCode }
      return body
    }
  }

  const globals = {
    module: { filename: moduleFilename, exports: {} },
    config: {
      runsInApp: context === "app",
      runsInActionExtension: context === "share",
      runsWithSiri: context === "siri",
      runsInWidget: context === "widget",
      runsInAccessoryWidget: context === "widget" && String(widgetFamily).startsWith("accessory"),
      runsInNotification: false,
      runsFromHomeScreen: false,
      widgetFamily: context === "widget" ? widgetFamily : null,
    },
    args: {
      plainTexts: [],
      urls: [],
      fileURLs: [],
      images: [],
      queryParameters: {},
      shortcutParameter: null,
      widgetParameter: null,
      ...args,
    },
    Script: {
      name: () => "Yes or No",
      complete: () => { log.completed += 1 },
      setShortcutOutput: (value) => { log.output = value },
      setWidget: (widget) => { log.widgets.push(widget) },
    },
    URLScheme: {
      forRunningScript: () => "scriptable:///run/Yes%20or%20No",
      forOpeningScript: () => "scriptable:///open/Yes%20or%20No",
      forOpeningScriptSettings: () => "scriptable:///settings/Yes%20or%20No",
    },
    FileManager: {
      local: () => fileManager("/local/Documents"),
      iCloud: () => fileManager("/iCloud/Documents/iCloud~dk~simonbs~Scriptable/Documents"),
    },
    Device: { screenSize: () => ({ width: 390, height: 844 }) },
    Pasteboard: { copyString: (text) => { log.copied.push(text) } },
    ShareSheet: { present: async (items) => { log.shared.push(items); return { completed: true } } },
    Speech: { speak: (text) => { log.spoken.push(text) } },
    Safari: { open: (url) => { log.safari.push(url) } },
    Color,
    Font,
    UITable,
    UITableRow,
    UITableCell,
    Alert,
    ListWidget,
    Request,
  }

  return { globals, log, files: store }
}

module.exports = { runScript, loadCore, createScriptable, SCRIPTS_DIR }
