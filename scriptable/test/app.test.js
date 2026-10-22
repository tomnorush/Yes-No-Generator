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

/** The big answer row on the main screen (only present once an answer is showing). */
function answerRow(table) {
  return table.rows.find((row) => row.cells.length === 1 && WORDS.test(row.cells[0].title))
}

/** A tap on the screen. Any row except the Settings button asks for a new answer. */
function tap(table, index = 0) {
  table.rows[index].onSelect(0)
}

async function run(options) {
  const env = createScriptable(options)
  await runScript("Yes or No.js", env.globals)
  return env
}

test("app: the screen starts blank, with nothing shown, saved or counted", async () => {
  const { log, files } = await run({ context: "app" })
  assert.equal(log.tables.length, 1)
  const main = log.tables[0]
  assert.equal(main.fullscreen, true)
  assert.equal(answerRow(main), undefined, "no answer at start")
  const texts = main.rows.flatMap((row) => row.cells.map((cell) => cell.title)).filter((t) => t.trim())
  assert.deepEqual(texts, ["Settings"], "only the Settings button is on screen")
  assert.equal(files.has(STATE_PATH), false, "nothing is saved before the first answer")
  assert.equal(log.output, undefined)
  assert.equal(log.completed, 1)
})

test("app: the first tap anywhere gives an answer, and every tap gives a new one", async () => {
  const { files } = await run({
    context: "app",
    interactions: [
      async (main) => {
        tap(main, 0) // top of the screen
        assert.match(answerRow(main).cells[0].title, /^(YES|NO)$/)
        assert.match(answerRow(main).cells[0].subtitle, /#1$/)
        tap(main, main.rows.indexOf(answerRow(main)))
        assert.match(answerRow(main).cells[0].subtitle, /#2$/)
        tap(main, main.rows.length - 1) // empty bottom of the screen
        assert.match(answerRow(main).cells[0].subtitle, /#3$/)
      },
    ],
  })
  assert.equal(savedState(files).history.length, 3)
})

test("app: the default answer type is Yes / No, never Maybe", async () => {
  await run({
    context: "app",
    interactions: [
      async (main) => {
        for (let i = 0; i < 200; i += 1) {
          tap(main)
          assert.match(answerRow(main).cells[0].title, /^(YES|NO)$/)
        }
      },
    ],
  })
})

test("app: the answer font is small enough for MAYBE to fit on one line", async () => {
  const { answerFontSize } = await require("./scriptable-mock").loadCore()
  // iPhone widths from small to Pro Max. MAYBE is about 2.85 em wide in the rounded black font.
  for (const width of [320, 375, 390, 430]) {
    const size = answerFontSize("MAYBE", width)
    assert.ok(size * 2.9 <= width - 48, `MAYBE at ${size}pt is too wide for ${width}pt`)
    assert.ok(answerFontSize("YES", width) * 1.8 <= width - 48)
    assert.ok(answerFontSize("NO", width) * 1.5 <= width - 48)
  }
})

test("app: nothing but Settings is on the main screen (no mode switch, question, Copy, Share, History)", async () => {
  await run({
    context: "app",
    interactions: [
      async (main) => {
        tap(main)
        const buttons = main.rows.flatMap((row) => row.cells.filter((c) => c.kind === "button").map((c) => c.title))
        assert.deepEqual(buttons, ["Settings"])
        const titles = main.rows.flatMap((row) => row.cells.map((cell) => cell.title))
        for (const gone of [/Maybe/, /question/i, /Copy/, /Share/, /History/]) {
          assert.equal(titles.some((t) => gone.test(t)), false, String(gone))
        }
      },
    ],
  })
})

test("app: every tappable row keeps the screen open", async () => {
  await run({
    context: "app",
    interactions: [
      async (main) => {
        tap(main)
        for (const row of main.rows) {
          if (row.onSelect) assert.equal(row.dismissOnSelect, false)
          for (const cell of row.cells) {
            if (cell.kind === "button") assert.equal(cell.dismissOnTap, false)
          }
        }
      },
    ],
  })
})

test("settings: Yes / No / Maybe is chosen in Settings, remembered, and blanks the screen", async () => {
  const { files } = await run({
    context: "app",
    interactions: [
      async (main) => {
        tap(main)
        assert.ok(answerRow(main))
        await main.button("Settings").onTap()
        assert.equal(answerRow(main), undefined, "an answer from the other type never lingers")
      },
      async (settings) => {
        assert.ok(settings.row("\u2713  Yes / No"), "Yes / No is the default")
        await settings.row(/Yes \/ No \/ Maybe/).onSelect(0)
        assert.ok(settings.row("\u2713  Yes / No / Maybe"))
      },
    ],
  })
  assert.equal(savedState(files).mode, "yesNoMaybe")
})

test("a Yes / No / Maybe session can give Maybe", async () => {
  const saved = { mode: "yesNoMaybe", history: [] }
  await run({
    context: "app",
    files: { [STATE_PATH]: JSON.stringify(saved) },
    interactions: [
      async (main) => {
        const seen = new Set()
        for (let i = 0; i < 300; i += 1) {
          tap(main)
          seen.add(answerRow(main).cells[0].title)
        }
        assert.deepEqual([...seen].sort(), ["MAYBE", "NO", "YES"])
      },
    ],
  })
})

test("a shared question or run-URL question is answered straight away", async () => {
  const { files, log } = await run({
    context: "share",
    args: { plainTexts: ["Should we go hiking\nthis weekend?"] },
  })
  assert.ok(answerRow(log.tables[0]))
  assert.equal(savedState(files).history[0].question, "Should we go hiking this weekend?")
  const url = await run({ context: "app", args: { queryParameters: { question: "Coffee?" } } })
  assert.equal(savedState(url.files).history[0].question, "Coffee?")
})

test("history: lists answers by day, deletes one, clears all", async () => {
  // Built before running so the simulated taps can read the saved file while the script runs.
  const env = createScriptable({
    context: "app",
    // History entry sheet: Delete (index 2). Clear All: confirm (index 0).
    alertChoices: [2, 0],
    interactions: [
      async (main) => {
        tap(main)
        tap(main)
        tap(main)
        await main.button("Settings").onTap()
      },
      async (settings) => {
        assert.ok(settings.row("View history"))
        assert.match(settings.row("View history").cells[0].subtitle, /^3 saved answers$/)
        await settings.row("View history").onSelect(0)
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
  assert.equal(env.log.tables.length, 3)
})

test("settings: theme, odds and history switch are saved, and tilted odds are disclosed", async () => {
  const { files } = await run({
    context: "app",
    // Odds sheet: index 6 is 70% Yes.
    alertChoices: [6],
    interactions: [
      async (main) => {
        tap(main)
        await main.button("Settings").onTap()
        tap(main)
        assert.match(answerRow(main).cells[0].subtitle, /Odds: 70% Yes · 30% No/)
        // history is off now: not saved
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
  assert.equal(state.history.length, 1, "only the first answer, before history was turned off")
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

test("a damaged saved file never blocks an answer", async () => {
  const { files } = await run({
    context: "app",
    files: { [STATE_PATH]: "{not json" },
    interactions: [async (main) => { tap(main); assert.ok(answerRow(main)) }],
  })
  assert.equal(savedState(files).history.length, 1)
})

test("saved settings are used on the next run", async () => {
  const saved = { mode: "yesNoMaybe", yesShare: 0.8, themeID: "mono", historyEnabled: true, history: [] }
  await run({
    context: "app",
    files: { [STATE_PATH]: JSON.stringify(saved) },
    interactions: [
      async (main) => {
        tap(main)
        assert.match(answerRow(main).cells[0].subtitle, /Odds: 53% Yes · 13% No · 34% Maybe/)
      },
    ],
  })
})
