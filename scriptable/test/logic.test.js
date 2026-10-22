"use strict"
// Core logic of the Scriptable version. Mirrors the Swift YesNoKit tests so both versions
// give the same answers, odds and shared text.

const test = require("node:test")
const assert = require("node:assert/strict")
const { loadCore } = require("./scriptable-mock")

/** Deterministic random numbers in [0, 1) so distribution checks are repeatable. */
function seeded(seed) {
  let state = seed >>> 0
  return () => {
    state = (state + 0x6d2b79f5) >>> 0
    let t = state
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function tally(core, mode, yesShare, samples = 60000) {
  const random = seeded(42)
  const counts = { yes: 0, no: 0, maybe: 0 }
  for (let i = 0; i < samples; i += 1) counts[core.decide(mode, yesShare, random)] += 1
  return { yes: counts.yes / samples, no: counts.no / samples, maybe: counts.maybe / samples }
}

function near(actual, expected, tolerance = 0.01) {
  assert.ok(Math.abs(actual - expected) <= tolerance, `${actual} is not within ${tolerance} of ${expected}`)
}

test("core logic", async (t) => {
  const core = await loadCore()

  await t.test("two-way mode never says maybe and is roughly 50/50", () => {
    const shares = tally(core, "yesNo", 0.5)
    assert.equal(shares.maybe, 0)
    near(shares.yes, 0.5)
    near(shares.no, 0.5)
  })

  await t.test("three-way mode gives each answer a third", () => {
    const shares = tally(core, "yesNoMaybe", 0.5)
    for (const answer of ["yes", "no", "maybe"]) near(shares[answer], 1 / 3)
  })

  await t.test("tilted odds are respected and Maybe keeps its third", () => {
    near(tally(core, "yesNo", 0.7).yes, 0.7)
    near(tally(core, "yesNo", 0.1).no, 0.9)
    const threeWay = tally(core, "yesNoMaybe", 0.9)
    near(threeWay.maybe, 1 / 3)
    near(threeWay.yes, 0.6)
  })

  await t.test("Math.random gives both answers", () => {
    const seen = new Set(Array.from({ length: 200 }, () => core.decide("yesNo", 0.5)))
    assert.deepEqual([...seen].sort(), ["no", "yes"])
  })

  await t.test("odds are clamped to 10..90% in whole percents", () => {
    assert.equal(core.clampYesShare(0), 0.1)
    assert.equal(core.clampYesShare(1), 0.9)
    assert.equal(core.clampYesShare(-5), 0.1)
    assert.equal(core.clampYesShare(NaN), 0.5)
    assert.equal(core.clampYesShare(Infinity), 0.5)
    assert.equal(core.clampYesShare("0.7"), 0.5)
    assert.equal(core.clampYesShare(undefined), 0.5)
    assert.equal(core.clampYesShare(0.69999), 0.7)
    assert.ok(core.isFair(0.5000001))
  })

  await t.test("probabilities sum to 1 and percentages to exactly 100", () => {
    for (let share = 0.1; share <= 0.9001; share += 0.01) {
      for (const mode of Object.keys(core.MODES)) {
        const probs = core.probabilities(mode, share)
        near(Object.values(probs).reduce((a, b) => a + b, 0), 1, 1e-9)
        const pct = core.percentages(mode, share)
        assert.equal(Object.values(pct).reduce((a, b) => a + b, 0), 100, `share ${share} mode ${mode}`)
      }
    }
  })

  await t.test("odds summaries match the iPhone app", () => {
    assert.equal(core.oddsSummary("yesNo", 0.7), "70% Yes · 30% No")
    assert.equal(core.oddsSummary("yesNoMaybe", 0.5), "33% Yes · 33% No · 34% Maybe")
  })

  await t.test("questions are trimmed, made one line, capped and blank becomes null", () => {
    assert.equal(core.normalizeQuestion("  Pizza?\n"), "Pizza?")
    assert.equal(core.normalizeQuestion("Should I\ngo?"), "Should I go?")
    assert.equal(core.normalizeQuestion("Line break"), "Line break")
    assert.equal(core.normalizeQuestion("   \n "), null)
    assert.equal(core.normalizeQuestion(undefined), null)
    assert.equal(core.normalizeQuestion("a".repeat(500)).length, core.QUESTION_MAX)
    // Emoji are never cut in half.
    const emoji = core.normalizeQuestion("\u{1F355}".repeat(200))
    assert.equal(Array.from(emoji).length, core.QUESTION_MAX)
    assert.ok(emoji.endsWith("\u{1F355}"))
  })

  await t.test("share text matches the iPhone app", () => {
    assert.equal(core.shareText("yes", null), "Yes or No says: YES")
    assert.equal(core.shareText("no", "  "), "Yes or No says: NO")
    assert.equal(
      core.shareText("maybe", "Pizza tonight?", "yesNoMaybe"),
      "“Pizza tonight?”\nYes or No says: MAYBE"
    )
    assert.equal(
      core.shareText("yes", null, "yesNo", 0.7),
      "Yes or No says: YES (odds: 70% Yes · 30% No)"
    )
  })

  await t.test("history entries keep tilted odds only, and the newest come first within the limit", () => {
    const fair = core.makeEntry({ answer: "yes", mode: "yesNo", question: " ", yesShare: 0.5 })
    assert.equal(fair.yesShare, undefined)
    assert.equal(fair.question, undefined)
    const tilted = core.makeEntry({ answer: "no", mode: "yesNo", question: "Go?", yesShare: 0.8 })
    assert.equal(tilted.yesShare, 0.8)
    assert.equal(tilted.question, "Go?")

    let history = []
    for (let i = 0; i < 260; i += 1) {
      history = core.recordEntry(history, core.makeEntry({ answer: "yes", mode: "yesNo", date: new Date(i * 1000) }))
    }
    assert.equal(history.length, core.HISTORY_LIMIT)
    assert.equal(history[0].date, new Date(259 * 1000).toISOString())
  })

  await t.test("damaged or unknown saved data falls back to safe defaults", () => {
    const defaults = core.parseState("not json")
    assert.deepEqual(defaults, {
      version: 1, mode: "yesNo", yesShare: 0.5, themeID: "classic", historyEnabled: true, history: [],
    })
    const odd = core.sanitizeState({
      mode: "sometimes",
      yesShare: 3,
      themeID: "neon",
      historyEnabled: false,
      history: [
        { answer: "yes", date: "2026-10-01T10:00:00.000Z", mode: "yesNo" },
        { answer: "perhaps", date: "2026-10-01T10:00:00.000Z" },
        { answer: "no", date: "yesterday-ish" },
        null,
      ],
    })
    assert.equal(odd.mode, "yesNo")
    assert.equal(odd.yesShare, 0.9)
    assert.equal(odd.themeID, "classic")
    assert.equal(odd.historyEnabled, false)
    assert.equal(odd.history.length, 1)
  })

  await t.test("history groups by local day, newest day first", () => {
    const day1 = new Date(2026, 9, 1, 9, 0)
    const day1Later = new Date(2026, 9, 1, 18, 0)
    const day2 = new Date(2026, 9, 2, 8, 0)
    const entries = [day2, day1Later, day1].map((date) => core.makeEntry({ answer: "yes", mode: "yesNo", date }))
    const groups = core.groupByDay(entries)
    assert.deepEqual(groups.map((g) => g.entries.length), [1, 2])
    assert.equal(groups[0].key, "2026-10-02")
  })

  await t.test("a session saves every answer, with the question, unless history is off", () => {
    const saves = []
    const state = core.sanitizeState({})
    const session = core.createSession(state, { save: (s) => saves.push(JSON.stringify(s)) }, seeded(7))
    session.question = "Pizza?"
    session.ask()
    session.ask()
    assert.equal(session.count, 2)
    assert.equal(state.history.length, 2)
    assert.equal(state.history[0].question, "Pizza?")
    assert.equal(saves.length, 2)

    state.historyEnabled = false
    session.ask()
    assert.equal(state.history.length, 2)
    assert.equal(saves.length, 3)
  })

  await t.test("every theme has colors for every answer", () => {
    for (const [id, theme] of Object.entries(core.THEMES)) {
      for (const variant of [theme.light, theme.dark || theme.light]) {
        for (const answer of Object.keys(core.ANSWERS)) {
          const colors = variant[answer]
          assert.ok(Array.isArray(colors) && colors.length === 2, `${id} ${answer}`)
          for (const hex of colors) assert.match(hex, /^#[0-9A-F]{6}$/, `${id} ${answer} ${hex}`)
        }
      }
    }
  })
})
