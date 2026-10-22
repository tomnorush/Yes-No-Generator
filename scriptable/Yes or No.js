// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: deep-green; icon-glyph: question-circle; share-sheet-inputs: plain-text;

/*
 * Yes or No: an instant answer to any yes-or-no question.
 * Scriptable version of https://github.com/tomnorush/Yes-No-Generator
 *
 * Run it and the answer is already on screen. Tap the answer for another.
 * Also works as a Home Screen or Lock Screen widget, with Siri ("Yes or No"),
 * from Shortcuts or the Action button, and from the share sheet (shared text
 * becomes the question).
 *
 * Works offline, asks for no permissions, and keeps its history only on this
 * device, in Scriptable's local Library folder (never iCloud).
 */

const VERSION = "1.0.0"
const HISTORY_LIMIT = 200
const QUESTION_MAX = 140
const MAYBE_SHARE = 1 / 3
const HELP_URL = "https://github.com/tomnorush/Yes-No-Generator/tree/main/scriptable"

// MARK: - Core logic
// Plain JavaScript with no Scriptable APIs, so it is unit tested in Node (scriptable/test).

const ANSWERS = {
  yes: { word: "YES", spoken: "Yes" },
  no: { word: "NO", spoken: "No" },
  maybe: { word: "MAYBE", spoken: "Maybe" },
}

const MODES = {
  yesNo: { title: "Yes / No", answers: ["yes", "no"] },
  yesNoMaybe: { title: "Yes / No / Maybe", answers: ["yes", "no", "maybe"] },
}

// [background, text] per answer. Classic follows light/dark mode; the others look the same in both.
const THEMES = {
  classic: {
    name: "Classic",
    light: { yes: ["#E3F5E8", "#0E5A2B"], no: ["#FCE6E4", "#8C1D14"], maybe: ["#FFF3D6", "#6B4A00"] },
    dark: { yes: ["#0C2616", "#7BE3A0"], no: ["#2E0F0C", "#FF9A8F"], maybe: ["#2B2106", "#FFD166"] },
  },
  bold: {
    name: "Bold",
    light: { yes: ["#16723A", "#FFFFFF"], no: ["#B3261E", "#FFFFFF"], maybe: ["#8A5A00", "#FFFFFF"] },
  },
  ocean: {
    name: "Ocean",
    light: { yes: ["#00695C", "#FFFFFF"], no: ["#1A237E", "#FFFFFF"], maybe: ["#37474F", "#FFFFFF"] },
  },
  sunset: {
    name: "Sunset",
    light: { yes: ["#B33F00", "#FFFFFF"], no: ["#5B1A7A", "#FFFFFF"], maybe: ["#9C1D55", "#FFFFFF"] },
  },
  forest: {
    name: "Forest",
    light: { yes: ["#2F5D2F", "#F1F8E9"], no: ["#4E342E", "#FBE9E7"], maybe: ["#5D5A1A", "#FFFDE7"] },
  },
  candy: {
    name: "Candy",
    light: { yes: ["#B8F2CC", "#0B3D1E"], no: ["#FFD1DC", "#6A0F2A"], maybe: ["#FFF1A8", "#4A3B00"] },
  },
  mono: {
    name: "Mono",
    light: { yes: ["#111111", "#FFFFFF"], no: ["#F4F4F4", "#111111"], maybe: ["#5E5E5E", "#FFFFFF"] },
    dark: { yes: ["#F4F4F4", "#111111"], no: ["#111111", "#FFFFFF"], maybe: ["#5E5E5E", "#FFFFFF"] },
  },
}

/** Chance of YES among the yes/no outcomes, kept between 10% and 90% in whole percents. */
function clampYesShare(value) {
  const number = typeof value === "number" && Number.isFinite(value) ? value : 0.5
  const clamped = Math.min(Math.max(number, 0.1), 0.9)
  return Math.round(clamped * 100) / 100
}

function isFair(yesShare) {
  return clampYesShare(yesShare) === 0.5
}

function validMode(mode) {
  return Object.prototype.hasOwnProperty.call(MODES, mode) ? mode : "yesNo"
}

/** Probability of each answer. MAYBE always keeps a third, so leaning never removes it. */
function probabilities(mode, yesShare) {
  const share = clampYesShare(yesShare)
  if (validMode(mode) === "yesNoMaybe") {
    const binary = 1 - MAYBE_SHARE
    return { yes: binary * share, no: binary * (1 - share), maybe: MAYBE_SHARE }
  }
  return { yes: share, no: 1 - share }
}

/** Whole percentages that always add up to exactly 100. */
function percentages(mode, yesShare) {
  const answers = MODES[validMode(mode)].answers
  const probs = probabilities(mode, yesShare)
  const result = {}
  for (const answer of answers) {
    result[answer] = Math.round(probs[answer] * 100)
  }
  const drift = 100 - answers.reduce((sum, answer) => sum + result[answer], 0)
  if (drift !== 0) {
    // MAYBE's share is fixed, so giving it the rounding difference never makes a fair split look tilted.
    const target = answers.includes("maybe")
      ? "maybe"
      : answers.reduce((best, answer) => (result[answer] > result[best] ? answer : best), answers[0])
    result[target] += drift
  }
  return result
}

/** For example "70% Yes · 30% No". */
function oddsSummary(mode, yesShare) {
  const result = percentages(mode, yesShare)
  return MODES[validMode(mode)].answers
    .map((answer) => `${result[answer]}% ${ANSWERS[answer].spoken}`)
    .join(" · ")
}

/** Picks an answer. `random` returns a number in [0, 1); tests pass a seeded one. */
function decide(mode, yesShare, random = Math.random) {
  const answers = MODES[validMode(mode)].answers
  const probs = probabilities(mode, yesShare)
  const roll = random()
  let cumulative = 0
  for (const answer of answers) {
    cumulative += probs[answer]
    if (roll < cumulative) return answer
  }
  return answers[answers.length - 1]
}

/** One line, trimmed, at most 140 characters; blank becomes null. */
function normalizeQuestion(raw) {
  if (typeof raw !== "string") return null
  const oneLine = raw.split(/\r\n|\r|\n|\u2028|\u2029/).join(" ").trim()
  if (oneLine === "") return null
  return Array.from(oneLine).slice(0, QUESTION_MAX).join("")
}

/** Text for Copy and Share. Tilted odds are always disclosed. */
function shareText(answer, question, mode = "yesNo", yesShare = 0.5) {
  let verdict = `Yes or No says: ${ANSWERS[answer].word}`
  if (!isFair(yesShare)) {
    verdict += ` (odds: ${oddsSummary(mode, yesShare)})`
  }
  const normalized = normalizeQuestion(question)
  return normalized ? `“${normalized}”\n${verdict}` : verdict
}

function makeEntry({ answer, mode, question, yesShare, date = new Date() }) {
  const entry = { date: date.toISOString(), answer, mode: validMode(mode) }
  const normalized = normalizeQuestion(question)
  if (normalized) entry.question = normalized
  if (!isFair(yesShare)) entry.yesShare = clampYesShare(yesShare)
  return entry
}

/** Newest first, oldest dropped past `limit`. */
function recordEntry(history, entry, limit = HISTORY_LIMIT) {
  return [entry, ...history].slice(0, Math.max(limit, 0))
}

function isValidEntry(entry) {
  return Boolean(entry) &&
    typeof entry === "object" &&
    Object.prototype.hasOwnProperty.call(ANSWERS, entry.answer) &&
    typeof entry.date === "string" &&
    !Number.isNaN(Date.parse(entry.date))
}

/** Settings and history with safe defaults, so a damaged or old file never blocks an answer. */
function sanitizeState(raw) {
  const s = raw && typeof raw === "object" ? raw : {}
  return {
    version: 1,
    mode: validMode(s.mode),
    yesShare: clampYesShare(s.yesShare),
    themeID: Object.prototype.hasOwnProperty.call(THEMES, s.themeID) ? s.themeID : "classic",
    historyEnabled: s.historyEnabled !== false,
    history: Array.isArray(s.history) ? s.history.filter(isValidEntry).slice(0, HISTORY_LIMIT) : [],
  }
}

function parseState(text) {
  try {
    return sanitizeState(JSON.parse(text))
  } catch (error) {
    return sanitizeState({})
  }
}

function dayKey(date) {
  const d = new Date(date)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`
}

/** History grouped by local calendar day, newest day first. */
function groupByDay(entries) {
  const groups = []
  for (const entry of entries) {
    const key = dayKey(entry.date)
    const last = groups[groups.length - 1]
    if (last && last.key === key) {
      last.entries.push(entry)
    } else {
      groups.push({ key, date: new Date(entry.date), entries: [entry] })
    }
  }
  return groups
}

/** The current answer, question and settings; `store.save(state)` persists them. */
function createSession(state, store, random = Math.random) {
  const session = {
    state,
    store,
    answer: "yes",
    question: null,
    count: 0,
    note: null,
    ask() {
      session.answer = decide(state.mode, state.yesShare, random)
      session.count += 1
      session.note = null
      if (state.historyEnabled) {
        const entry = makeEntry({
          answer: session.answer,
          mode: state.mode,
          question: session.question,
          yesShare: state.yesShare,
        })
        state.history = recordEntry(state.history, entry)
      }
      store.save(state)
      return session.answer
    },
    shareText() {
      return shareText(session.answer, session.question, state.mode, state.yesShare)
    },
  }
  return session
}

// MARK: - Scriptable: storage

function fileStore() {
  // Local, not iCloud: history stays on this device even if Scriptable syncs scripts with iCloud.
  const fm = FileManager.local()
  const directory = fm.joinPath(fm.libraryDirectory(), "yes-or-no")
  const path = fm.joinPath(directory, "state.json")
  return {
    load() {
      return fm.fileExists(path) ? parseState(fm.readString(path)) : sanitizeState({})
    },
    save(state) {
      if (!fm.fileExists(directory)) fm.createDirectory(directory, true)
      fm.writeString(path, JSON.stringify(state))
    },
  }
}

// MARK: - Scriptable: colors and fonts

function palette(themeID, answer) {
  const theme = THEMES[themeID] || THEMES.classic
  const light = theme.light[answer]
  const dark = (theme.dark || theme.light)[answer]
  return {
    background: Color.dynamic(new Color(light[0]), new Color(dark[0])),
    text: Color.dynamic(new Color(light[1]), new Color(dark[1])),
  }
}

function answerFontSize(word, screenWidth) {
  return Math.max(48, Math.min(150, Math.floor(screenWidth / (word.length * 0.75))))
}

function timeLabel(dateString) {
  return new Date(dateString).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
}

function dayLabel(date) {
  const today = dayKey(new Date())
  const yesterday = dayKey(new Date(Date.now() - 24 * 60 * 60 * 1000))
  const key = dayKey(date)
  if (key === today) return "Today"
  if (key === yesterday) return "Yesterday"
  return date.toLocaleDateString([], { weekday: "long", month: "short", day: "numeric" })
}

// MARK: - Scriptable: main screen

async function presentMain(session) {
  const table = new UITable()
  table.showSeparators = false
  const render = () => {
    table.removeAllRows()
    buildMainRows(table, session, render)
    table.reload()
  }
  buildMainRows(table, session, render)
  await table.present(true)
}

function buildMainRows(table, session, render) {
  const state = session.state
  const colors = palette(state.themeID, session.answer)
  const screen = Device.screenSize()
  const word = ANSWERS[session.answer].word

  const styleRow = (row, height) => {
    row.height = height
    row.backgroundColor = colors.background
    row.dismissOnSelect = false
    return row
  }

  // Two-way or three-way, right on the main screen.
  const modeRow = styleRow(new UITableRow(), 60)
  modeRow.cellSpacing = 8
  for (const id of Object.keys(MODES)) {
    const selected = state.mode === id
    const cell = UITableCell.button(`${selected ? "●" : "○"} ${MODES[id].title}`)
    cell.titleColor = colors.text
    cell.titleFont = selected ? Font.boldRoundedSystemFont(16) : Font.regularRoundedSystemFont(16)
    cell.widthWeight = id === "yesNo" ? 42 : 58
    cell.centerAligned()
    cell.onTap = () => {
      if (state.mode === id) return
      state.mode = id
      session.ask()
      render()
    }
    modeRow.addCell(cell)
  }
  table.addRow(modeRow)

  // Optional question.
  const questionRow = styleRow(new UITableRow(), 64)
  const questionCell = questionRow.addText(
    session.question ? `“${session.question}”` : "Ask a question (optional)",
    session.question ? "Tap to change or clear it" : "Tap to type it"
  )
  questionCell.titleColor = colors.text
  questionCell.subtitleColor = colors.text
  questionCell.titleFont = Font.semiboldRoundedSystemFont(17)
  questionCell.subtitleFont = Font.regularRoundedSystemFont(13)
  questionCell.centerAligned()
  questionRow.onSelect = async () => {
    const question = await askForQuestion(session.question)
    if (question === undefined) return // cancelled
    session.question = question
    session.ask()
    render()
  }
  table.addRow(questionRow)

  // The answer. Tap anywhere on it for another.
  const answerRow = styleRow(new UITableRow(), Math.max(280, screen.height - 340))
  const hints = []
  if (!isFair(state.yesShare)) hints.push(`Odds: ${oddsSummary(state.mode, state.yesShare)}`)
  hints.push(session.note || "Tap for a new answer")
  const answerCell = answerRow.addText(word, hints.join("  •  "))
  answerCell.titleFont = Font.blackRoundedSystemFont(answerFontSize(word, screen.width))
  answerCell.titleColor = colors.text
  answerCell.subtitleFont = Font.semiboldRoundedSystemFont(16)
  answerCell.subtitleColor = colors.text
  answerCell.centerAligned()
  answerRow.onSelect = () => {
    session.ask()
    render()
  }
  table.addRow(answerRow)

  // Copy, Share, History, Settings.
  const actionRow = styleRow(new UITableRow(), 60)
  actionRow.cellSpacing = 4
  const actions = [
    {
      title: "Copy",
      onTap: () => {
        Pasteboard.copyString(session.shareText())
        session.note = "Copied"
        render()
      },
    },
    {
      title: "Share",
      onTap: async () => {
        await ShareSheet.present([session.shareText()])
      },
    },
    {
      title: "History",
      onTap: async () => {
        await presentHistory(session)
        render()
      },
    },
    {
      title: "Settings",
      onTap: async () => {
        await presentSettings(session)
        render()
      },
    },
  ]
  for (const action of actions) {
    const cell = UITableCell.button(action.title)
    cell.titleColor = colors.text
    cell.titleFont = Font.semiboldRoundedSystemFont(16)
    cell.centerAligned()
    cell.onTap = action.onTap
    actionRow.addCell(cell)
  }
  table.addRow(actionRow)

  // Fill the rest of the screen with the answer color.
  table.addRow(styleRow(new UITableRow(), 240))
}

/** Returns the new question (null to clear), or undefined if cancelled. */
async function askForQuestion(current) {
  const alert = new Alert()
  alert.title = "Your question"
  alert.message = "Optional. It's kept with the answer in History and included when you share."
  alert.addTextField("Should we get pizza?", current || "")
  alert.addAction("Ask")
  if (current) alert.addDestructiveAction("Clear question")
  alert.addCancelAction("Cancel")
  const choice = await alert.presentAlert()
  if (choice === -1) return undefined
  if (choice === 1) return null
  return normalizeQuestion(alert.textFieldValue(0))
}

// MARK: - Scriptable: history

async function presentHistory(session) {
  const state = session.state
  const table = new UITable()
  const render = () => {
    table.removeAllRows()
    build()
    table.reload()
  }

  const addNote = (title, subtitle) => {
    const row = new UITableRow()
    row.height = subtitle ? 70 : 50
    const cell = row.addText(title, subtitle)
    cell.titleFont = Font.regularRoundedSystemFont(15)
    cell.subtitleFont = Font.regularRoundedSystemFont(13)
    cell.subtitleColor = Color.gray()
    table.addRow(row)
  }

  function build() {
    const header = new UITableRow()
    header.isHeader = true
    header.height = 56
    header.addText("History").titleFont = Font.boldRoundedSystemFont(22)
    table.addRow(header)

    if (!state.historyEnabled) {
      addNote("History is off", "New answers aren't being saved. Turn it on in Settings.")
    }
    if (state.history.length === 0) {
      addNote("No answers yet", "Answers you get will show up here. They stay on this device.")
      return
    }

    const clearRow = new UITableRow()
    clearRow.dismissOnSelect = false
    const clearCell = clearRow.addText("Clear All")
    clearCell.titleColor = Color.red()
    clearCell.titleFont = Font.semiboldRoundedSystemFont(16)
    clearRow.onSelect = async () => {
      if (await confirmClearHistory()) {
        state.history = []
        session.store.save(state)
        render()
      }
    }
    table.addRow(clearRow)

    for (const group of groupByDay(state.history)) {
      const dayRow = new UITableRow()
      dayRow.isHeader = true
      dayRow.addText(dayLabel(group.date)).titleFont = Font.semiboldRoundedSystemFont(15)
      table.addRow(dayRow)

      for (const entry of group.entries) {
        const colors = palette(state.themeID, entry.answer)
        const row = new UITableRow()
        row.height = 64
        row.backgroundColor = colors.background
        row.dismissOnSelect = false

        const wordCell = row.addText(ANSWERS[entry.answer].word)
        wordCell.widthWeight = 28
        wordCell.titleFont = Font.blackRoundedSystemFont(20)
        wordCell.titleColor = colors.text

        const details = [timeLabel(entry.date)]
        if (entry.yesShare !== undefined) details.push(oddsSummary(entry.mode, entry.yesShare))
        const textCell = row.addText(entry.question || "No question", details.join(" · "))
        textCell.widthWeight = 72
        textCell.titleColor = colors.text
        textCell.subtitleColor = colors.text
        textCell.titleFont = Font.mediumRoundedSystemFont(15)
        textCell.subtitleFont = Font.regularRoundedSystemFont(12)

        row.onSelect = async () => {
          const text = shareText(entry.answer, entry.question, entry.mode, entry.yesShare)
          const alert = new Alert()
          alert.title = ANSWERS[entry.answer].word
          alert.message = text
          alert.addAction("Copy")
          alert.addAction("Share")
          alert.addDestructiveAction("Delete")
          alert.addCancelAction("Cancel")
          const choice = await alert.presentSheet()
          if (choice === 0) Pasteboard.copyString(text)
          if (choice === 1) await ShareSheet.present([text])
          if (choice === 2) {
            state.history = state.history.filter((item) => item !== entry)
            session.store.save(state)
            render()
          }
        }
        table.addRow(row)
      }
    }

    addNote(`Your last ${HISTORY_LIMIT} answers are kept, only on this device.`)
  }

  build()
  await table.present(false)
}

async function confirmClearHistory() {
  const alert = new Alert()
  alert.title = "Delete all saved answers?"
  alert.message = "This can't be undone."
  alert.addDestructiveAction("Delete All")
  alert.addCancelAction("Cancel")
  return (await alert.presentAlert()) === 0
}

// MARK: - Scriptable: settings

async function presentSettings(session) {
  const state = session.state
  const table = new UITable()
  const render = () => {
    table.removeAllRows()
    build()
    table.reload()
  }
  const save = () => session.store.save(state)

  const addHeader = (title) => {
    const row = new UITableRow()
    row.isHeader = true
    row.height = 52
    row.addText(title).titleFont = Font.boldRoundedSystemFont(title === "Settings" ? 22 : 17)
    table.addRow(row)
  }
  const addRow = (title, subtitle, onSelect) => {
    const row = new UITableRow()
    row.height = subtitle ? 64 : 48
    const cell = row.addText(title, subtitle)
    cell.titleFont = Font.regularRoundedSystemFont(16)
    cell.subtitleFont = Font.regularRoundedSystemFont(13)
    cell.subtitleColor = Color.gray()
    if (onSelect) {
      row.dismissOnSelect = false
      row.onSelect = onSelect
    }
    table.addRow(row)
    return { row, cell }
  }

  function build() {
    addHeader("Settings")

    addHeader("Color theme")
    for (const [id, theme] of Object.entries(THEMES)) {
      const colors = palette(id, "yes")
      const { row, cell } = addRow(`${state.themeID === id ? "✓  " : ""}${theme.name}`, null, () => {
        state.themeID = id
        save()
        render()
      })
      row.backgroundColor = colors.background
      cell.titleColor = colors.text
      cell.titleFont = Font.semiboldRoundedSystemFont(16)
    }

    addHeader("Odds")
    addRow(`Chance of Yes: ${oddsSummary("yesNo", state.yesShare)}`, "Tap to change. Maybe always keeps a one-third chance.", async () => {
      const options = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
      const alert = new Alert()
      alert.title = "Chance of Yes"
      alert.message = "Lean toward what you're already leaning toward. When the odds aren't 50/50, the main screen and anything you share say so."
      for (const option of options) {
        alert.addAction(`${oddsSummary("yesNo", option)}${option === 0.5 ? " (fair)" : ""}`)
      }
      alert.addCancelAction("Cancel")
      const choice = await alert.presentSheet()
      if (choice >= 0) {
        state.yesShare = clampYesShare(options[choice])
        save()
        render()
      }
    })

    addHeader("History")
    addRow(`Save history: ${state.historyEnabled ? "On" : "Off"}`, "Tap to turn it " + (state.historyEnabled ? "off." : "on."), () => {
      state.historyEnabled = !state.historyEnabled
      save()
      render()
    })
    const clear = addRow("Clear history", null, async () => {
      if (await confirmClearHistory()) {
        state.history = []
        save()
        render()
      }
    })
    clear.cell.titleColor = Color.red()

    addHeader("Widget")
    addRow("Preview the widget", "Add it from the Home Screen: Edit → Add Widget → Scriptable.", async () => {
      await buildWidget(state, "small").presentSmall()
    })

    addHeader("About")
    addRow(`Yes or No ${VERSION} for Scriptable`, "No ads, no tracking, no account. Works offline; nothing leaves this device.")
    addRow("Help and updates", "Opens the GitHub page in Safari.", () => {
      Safari.open(HELP_URL)
    })
  }

  build()
  await table.present(false)
}

// MARK: - Scriptable: widget

/**
 * Shows the last saved answer and when it was given, never a new one: a widget can't
 * reroll, and an old answer must not look new. Tapping it runs the script for a fresh answer.
 */
function buildWidget(state, family) {
  const widget = new ListWidget()
  widget.url = URLScheme.forRunningScript()
  const last = state.historyEnabled ? state.history[0] : undefined

  if (family === "accessoryCircular") {
    widget.addAccessoryWidgetBackground = true
    const text = widget.addText("Y/N")
    text.font = Font.blackRoundedSystemFont(18)
    text.minimumScaleFactor = 0.5
    text.centerAlignText()
    return widget
  }
  if (family === "accessoryInline") {
    widget.addText(last ? `Yes or No · last: ${ANSWERS[last.answer].spoken}` : "Yes or No?")
    return widget
  }
  if (family === "accessoryRectangular") {
    const title = widget.addText("Yes or No")
    title.font = Font.boldRoundedSystemFont(15)
    if (last) {
      const answer = widget.addText(`Last: ${ANSWERS[last.answer].word}`)
      answer.font = Font.semiboldRoundedSystemFont(13)
      const date = widget.addDate(new Date(last.date))
      date.applyRelativeStyle()
      date.font = Font.regularRoundedSystemFont(12)
    } else {
      widget.addText("Tap for an answer").font = Font.regularRoundedSystemFont(13)
    }
    return widget
  }

  const colors = palette(state.themeID, last ? last.answer : "yes")
  widget.backgroundColor = colors.background
  widget.setPadding(14, 14, 14, 14)

  const label = widget.addText(last ? "Last answer" : "Yes or No")
  label.font = Font.semiboldRoundedSystemFont(13)
  label.textColor = colors.text
  label.textOpacity = 0.85

  const word = widget.addText(last ? ANSWERS[last.answer].word : "?")
  word.font = Font.blackRoundedSystemFont(family === "small" ? 44 : 56)
  word.textColor = colors.text
  word.minimumScaleFactor = 0.5
  word.lineLimit = 1

  if (last && last.question && family !== "small") {
    const question = widget.addText(`“${last.question}”`)
    question.font = Font.mediumRoundedSystemFont(14)
    question.textColor = colors.text
    question.lineLimit = 2
  }
  if (last) {
    const date = widget.addDate(new Date(last.date))
    date.applyRelativeStyle()
    date.font = Font.regularRoundedSystemFont(12)
    date.textColor = colors.text
  }

  widget.addSpacer()
  const hint = widget.addText("Tap for a new answer")
  hint.font = Font.semiboldRoundedSystemFont(12)
  hint.textColor = colors.text
  return widget
}

// MARK: - Scriptable: Siri and Shortcuts

async function presentForSiri(session) {
  Speech.speak(ANSWERS[session.answer].spoken)
  const colors = palette(session.state.themeID, session.answer)
  const table = new UITable()
  const row = new UITableRow()
  row.height = 160
  row.backgroundColor = colors.background
  const cell = row.addText(ANSWERS[session.answer].word, session.question || undefined)
  cell.titleFont = Font.blackRoundedSystemFont(72)
  cell.titleColor = colors.text
  cell.subtitleColor = colors.text
  cell.centerAligned()
  table.addRow(row)
  await table.present(false)
}

/** Shortcuts or the Action button without "Run In App": a simple alert you can repeat. */
async function presentAlertLoop(session) {
  for (;;) {
    const alert = new Alert()
    alert.title = ANSWERS[session.answer].word
    const lines = []
    if (session.question) lines.push(`“${session.question}”`)
    if (!isFair(session.state.yesShare)) lines.push(`Odds: ${oddsSummary(session.state.mode, session.state.yesShare)}`)
    alert.message = lines.join("\n")
    alert.addAction("Again")
    alert.addAction("Copy")
    alert.addCancelAction("Done")
    const choice = await alert.presentAlert()
    if (choice === 0) {
      session.ask()
      continue
    }
    if (choice === 1) Pasteboard.copyString(session.shareText())
    return
  }
}

/** Shared text, a Shortcuts parameter, or ?question= in the run URL. */
function questionFromInput() {
  if (args.plainTexts && args.plainTexts.length > 0) return args.plainTexts[0]
  if (typeof args.shortcutParameter === "string") return args.shortcutParameter
  if (args.queryParameters && args.queryParameters.question) return args.queryParameters.question
  return null
}

// MARK: - Entry point

async function main() {
  const store = fileStore()
  const state = store.load()

  if (config.runsInWidget || config.runsInAccessoryWidget) {
    Script.setWidget(buildWidget(state, config.widgetFamily))
    Script.complete()
    return
  }

  const session = createSession(state, store)
  session.question = normalizeQuestion(questionFromInput())
  session.ask() // The answer is ready before anything is drawn.

  if (config.runsWithSiri) {
    await presentForSiri(session)
  } else if (config.runsInApp || config.runsInActionExtension) {
    await presentMain(session)
  } else {
    await presentAlertLoop(session)
  }
  Script.setShortcutOutput(ANSWERS[session.answer].word)
  Script.complete()
}

// In Scriptable this runs the app. The Node tests load the file without the
// Scriptable globals and get the core logic instead.
if (typeof Script === "undefined") {
  module.exports = {
    VERSION, HISTORY_LIMIT, QUESTION_MAX, ANSWERS, MODES, THEMES,
    clampYesShare, isFair, validMode, probabilities, percentages, oddsSummary, decide,
    normalizeQuestion, shareText, makeEntry, recordEntry, isValidEntry, sanitizeState,
    parseState, dayKey, groupByDay, createSession, buildWidget, main,
  }
} else {
  // @ts-ignore: Scriptable runs scripts inside an async function, so top-level await is allowed.
  await main()
}
