import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { createSeedSession } from "./seed-session.mjs";
import { wolf3dSource } from "./wolf3d-source.mjs";

test("Wolf3D declares its original-tic rate and deterministic advance size", async () => {
  const session = await createSeedSession();
  session.evaluateQuietly(wolf3dSource);

  assert.equal(session.evaluate("(app.timing)"), "(timing 70 6)");
  assert.equal(session.evaluate("wl.tics"), "6");
});

test("the generic Canvas host schedules the application-declared cadence", async () => {
  const source = await readFile(new URL("../src/examples/runtime/lisp-application.ts", import.meta.url), "utf8");

  assert.match(source, /frameIntervalMs = \(1000 \* timing\.ticksPerAdvance\) \/ timing\.tickRateHz/);
  assert.match(source, /legacyTickRateHz = 10/);
  assert.doesNotMatch(source, /1000 \/ 70|Wolf3D's original simulation/);
});
