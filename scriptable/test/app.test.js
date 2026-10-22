"use strict"
// Runs the real "Yes or No" script in each place Scriptable can run it, with simulated taps.

const test = require("node:test")
const assert = require("node:assert/strict")
const { runScript, createScriptable } = require("./scriptable-mock")

const STATE_PATH = "/local/Library/yes-or-no/state.json"
const WORDS = /^(YES|NO|MAYBE)$/

function savedState(files) {
  return JSON.parse(files.get(STATE_PATH))
}

/** The big answer row on the main screen. */
function answerRow(table) {
  return table.rows.find((row) => row.cells.length === 1 && WORDS.test(row.cells[0].title))
}

async function run(options) {
  const env = createScriptable(options)
  await runScript("Yes or No.js", env.globals)
  return env
}

test("app: the answer is on screen at launch, with no taps", async () => {
  const { log, files } = await run({ context: "app" })
  assert.equal(log.tables.length, 1)
  const main = log.tables[0]
  assert.equal(main.fullscreen, true)
  const row = answerRow(main)
  assert.ok(row, "answer row is shown")
  assert.match(row.cells[0].title, /^(YES|NO)$/)
  assert.equal(row.dismissOnSelect, false, "tapping the answer must not close the screen")
  assert.equal(savedState(files).history.length, 1, "the launch answer is saved")
  assert.equal(log.completed, 1)
  assert.match(log.output, WORDS)
})

test("app: one tap on the answer gives a new one and saves it", async () => {
  const { files } = await run({
    context: "app",
    interactions: [
      async (main) => {
        answerRow(main).onSelect(0)
        answerRow(main).onSelect(0)
        assert.ok(main.reloads >= 2)
      },
    ],
  })
  assert.equal(savedState(files).history.length, 3)
})

test("app: every tappable row keeps the screen open", async () => {
  await run({
    context: "app",
    interactions: [
      async (main) => {
        for (const row of main.rows) {
          if (row.onSelect) assert.equal(row.dismissOnSelect, false)
        }
        for (const row of main.rows) {
          for (const cell of row.cells) {
            if (cell.kind === "button") assert.equal(cell.dismissOnTap, false)
          }
        }
      },
    ],
  })
})

test("app: Maybe is one tap away and is remembered", async () => {
  const { files } = await run({
    context: "app",
    interactions: [
      async (main) => {
        main.button(/Yes \/ No \/ Maybe/).onTap()
        assert.match(answerRow(main).cells[0].title, WORDS)
        assert.match(main.button(/Yes \/ No \/ Maybe/).title, /^●/)
      },
    ],
  })
  const state = savedState(files)
  assert.equal(state.mode, "yesNoMaybe")
  assert.equal(state.history[0].mode, "yesNoMaybe")
})

test("app: a typed question is kept with the answer, and Copy includes it", async () => {
  const { files, log } = await run({
    context: "app",
    alertChoices: [{ choice: 0, text: "  Pizza tonight?\n" }],
    interactions: [
      async (main) => {
        await main.row(/Ask a question/).onSelect(0)
        assert.ok(main.row("“Pizza tonight?”"), "question is shown")
        main.button("Copy").onTap()
        assert.match(answerRow(main).cells[0].subtitle, /Copied/)
      },
    ],
  })
  assert.equal(savedState(files).history[0].question, "Pizza tonight?")
  assert.match(log.copied[0], /^“Pizza tonight\?”\nYes or No says: (YES|NO)$/)
})

test("app: cancelling the question prompt changes nothing", async () => {
  const { files } = await run({
    context: "app",
    alertChoices: [-1],
    interactions: [async (main) => { await main.row(/Ask a question/).onSelect(0) }],
  })
  assert.equal(savedState(files).history.length, 1)
})

test("app: Share sends the answer text", async () => {
  const { log } = await run({
    context: "app",
    interactions: [async (main) => { await main.button("Share").onTap() }],
  })
  assert.equal(log.shared.length, 1)
  assert.match(log.shared[0][0], /^Yes or No says: (YES|NO)$/)
})

test("history: lists answers by day, deletes one, clears all", async () => {
  // Built before running so the simulated taps can read the saved file while the script runs.
  const env = createScriptable({
    context: "app",
    // History entry sheet: Delete (index 2). Clear All: confirm (index 0).
    alertChoices: [2, 0],
    interactions: [
      async (main) => {
        answerRow(main).onSelect(0)
        answerRow(main).onSelect(0)
        await main.button("History").onTap()
      },
      async (history) => {
        assert.ok(history.row("Today"), "grouped under Today")
        const entries = history.rows.filter((row) => row.cells.length === 2 && WORDS.test(row.cells[0].title))
        assert.equal(entries.length, 3)
        await entries[0].onSelect(0)
        assert.equal(savedState(env.files).history.length, 2)
        await history.row("Clear All").onSelect(0)
        assert.equal(savedState(env.files).history.length, 0)
        assert.ok(history.row("No answers yet"))
      },
    ],
  })
  await runScript("Yes or No.js", env.globals)
  assert.equal(env.log.tables.length, 2)
})

test("settings: theme, odds and history switch are saved, and tilted odds are disclosed", async () => {
  const { files } = await run({
    context: "app",
    // Odds sheet: index 6 is 70% Yes.
    alertChoices: [6],
    interactions: [
      async (main) => {
        await main.button("Settings").onTap()
        assert.match(answerRow(main).cells[0].subtitle, /Odds: 70% Yes · 30% No/)
        answerRow(main).onSelect(0) // history is off now: not saved
      },
      async (settings) => {
        await settings.row("Ocean").onSelect(0)
        await settings.row(/Chance of Yes/).onSelect(0)
        await settings.row(/Save history: On/).onSelect(0)
        assert.ok(settings.row("✓  Ocean"))
        assert.ok(settings.row(/Save history: Off/))
      },
    ],
  })
  const state = savedState(files)
  assert.equal(state.themeID, "ocean")
  assert.equal(state.yesShare, 0.7)
  assert.equal(state.historyEnabled, false)
  assert.equal(state.history.length, 1, "only the launch answer, before history was turned off")
})

test("settings: the widget preview works", async () => {
  const { log } = await run({
    context: "app",
    interactions: [
      async (main) => { await main.button("Settings").onTap() },
      async (settings) => { await settings.row("Preview the widget").onSelect(0) },
    ],
  })
  assert.equal(log.previews.length, 1)
})

for (const family of ["small", "medium", "large", "extraLarge", "accessoryCircular", "accessoryRectangular", "accessoryInline"]) {
  test(`widget (${family}): shows the last answer, never makes a new one, and taps run the script`, async () => {
    const previous = {
      history: [{ answer: "no", mode: "yesNo", date: new Date().toISOString(), question: "Go out?" }],
    }
    const { log, files } = await run({
      context: "widget",
      widgetFamily: family,
      files: { [STATE_PATH]: JSON.stringify(previous) },
    })
    assert.equal(log.widgets.length, 1)
    assert.equal(log.tables.length, 0)
    assert.equal(log.completed, 1)
    const widget = log.widgets[0]
    assert.equal(widget.url, "scriptable:///run/Yes%20or%20No")
    assert.equal(files.get(STATE_PATH), JSON.stringify(previous), "a widget never adds an answer")
    if (family !== "accessoryCircular" && family !== "accessoryInline") {
      assert.ok(widget.texts().some((text) => /NO/.test(text)), widget.texts().join(" | "))
    }
  })
}

test("widget: with no answers yet it invites a tap", async () => {
  const { log } = await run({ context: "widget", widgetFamily: "small" })
  assert.ok(log.widgets[0].texts().includes("Tap for a new answer"))
})

test("Siri: speaks the answer, shows it, and returns it to Shortcuts", async () => {
  const { log, files } = await run({ context: "siri" })
  assert.equal(log.spoken.length, 1)
  assert.match(log.spoken[0], /^(Yes|No)$/)
  assert.equal(log.output, log.spoken[0].toUpperCase())
  assert.equal(log.tables.length, 1)
  assert.equal(savedState(files).history.length, 1)
})

test("Shortcuts / Action button: an alert you can repeat, with Copy", async () => {
  const { log, files } = await run({
    context: "shortcuts",
    args: { shortcutParameter: "Take the job?" },
    alertChoices: [0, 1], // Again, then Copy
  })
  assert.equal(log.alerts.length, 2)
  assert.match(log.alerts[0].title, WORDS)
  assert.match(log.alerts[0].message, /Take the job\?/)
  assert.equal(log.copied.length, 1)
  assert.match(log.output, WORDS)
  const state = savedState(files)
  assert.equal(state.history.length, 2)
  assert.equal(state.history[0].question, "Take the job?")
})

test("share sheet: shared text becomes the question", async () => {
  const { files, log } = await run({
    context: "share",
    args: { plainTexts: ["Should we go hiking\nthis weekend?"] },
  })
  assert.equal(log.tables.length, 1)
  assert.equal(savedState(files).history[0].question, "Should we go hiking this weekend?")
})

test("run URL: ?question= becomes the question", async () => {
  const { files } = await run({ context: "app", args: { queryParameters: { question: "Coffee?" } } })
  assert.equal(savedState(files).history[0].question, "Coffee?")
})

test("a damaged saved file never blocks an answer", async () => {
  const { log, files } = await run({ context: "app", files: { [STATE_PATH]: "{not json" } })
  assert.ok(answerRow(log.tables[0]))
  assert.equal(savedState(files).history.length, 1)
})

test("saved settings are used on the next run", async () => {
  const saved = { mode: "yesNoMaybe", yesShare: 0.8, themeID: "mono", historyEnabled: true, history: [] }
  const { log } = await run({ context: "app", files: { [STATE_PATH]: JSON.stringify(saved) } })
  const main = log.tables[0]
  assert.match(main.button(/Yes \/ No \/ Maybe/).title, /^●/)
  assert.match(answerRow(main).cells[0].subtitle, /Odds: 53% Yes · 13% No · 34% Maybe/)
})
