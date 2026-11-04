const test = require("node:test");
const assert = require("node:assert");
const { _jdtInternals: j } = require("./index.js");

// 6:00 PM in Malaysia on 3 Nov 2026, and the job's run times (a few seconds
// past the hour, as the real runs are).
const kickoff = new Date("2026-11-03T10:00:00Z");
const run = (utc) => new Date(`${utc}:04Z`);

test("an on-the-hour fixture gets its kick-off reminder an hour ahead", () => {
  assert.equal(j.reminderKind(run("2026-11-03T08:00"), kickoff), null); // 4 PM
  assert.equal(j.reminderKind(run("2026-11-03T09:00"), kickoff), "kickoff"); // 5 PM
  assert.equal(j.reminderKind(run("2026-11-03T10:00"), kickoff), null); // 6 PM
});

test("match-day goes out at 9 AM Malaysia time", () => {
  assert.equal(j.reminderKind(run("2026-11-03T01:00"), kickoff), "matchday");
  assert.equal(j.reminderKind(run("2026-11-02T01:00"), kickoff), null);
});

test("every kick-off minute gets exactly one kick-off reminder", () => {
  for (const minute of [0, 1, 15, 30, 45, 59]) {
    const at = new Date(Date.UTC(2026, 10, 3, 10, minute));
    let count = 0;
    for (let h = 0; h < 12; h++) {
      const now = new Date(Date.UTC(2026, 10, 3, h, 0, 4));
      if (j.reminderKind(now, at) === "kickoff") count++;
    }
    assert.equal(count, 1, `kick-off at :${minute}`);
  }
});

test("an early fixture is not reminded twice around 9 AM", () => {
  // 9:45 AM Malaysia: kick-off reminder at 8 AM, nothing at 9 AM.
  const early = new Date("2026-11-03T01:45:00Z");
  assert.equal(j.reminderKind(run("2026-11-03T00:00"), early), "kickoff");
  assert.equal(j.reminderKind(run("2026-11-03T01:00"), early), null);
});

test("kick-off copy names the time, not a countdown", () => {
  const message = j.reminderMessage(
    {
      idHomeTeam: "1",
      strHomeTeam: "Jeonbuk",
      idAwayTeam: "139018",
      strAwayTeam: "Johor Darul Ta'zim",
      strLeague: "ACL",
      strVenue: "Jeonju",
    },
    kickoff,
    "kickoff",
    { id: "139018", label: "JDT" }
  );
  assert.equal(message.title, "⏱️ JDT kick off soon · 6:00 PM");
  assert.equal(message.body, "Jeonbuk vs JDT · ACL · Jeonju");
});

test("tokensOf merges devices with the legacy field, once each", () => {
  assert.deepEqual(j.tokensOf({ fcmTokens: ["a", "b"], fcmToken: "b" }), ["a", "b"]);
  assert.deepEqual(j.tokensOf({ fcmToken: "old" }), ["old"]);
  assert.deepEqual(j.tokensOf({ fcmToken: null, fcmTokens: [] }), []);
  assert.deepEqual(j.tokensOf(null), []);
});
