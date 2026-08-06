import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { createSeedSession } from "./seed-session.mjs";
import { loadWolf3d, wolf3dModules, wolf3dSources } from "./wolf3d-source.mjs";

const LIMIT = 130048;

test("Wolf3D declares its original-tic rate and deterministic advance size", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);

  assert.equal(session.evaluate("(app.timing)"), "(timing 70 6)");
  assert.equal(session.evaluate("wl.tics"), "6");
});

test("the generic Canvas host schedules the application-declared cadence", async () => {
  const source = await readFile(new URL("../src/examples/runtime/lisp-application.ts", import.meta.url), "utf8");

  assert.match(source, /frameIntervalMs = \(1000 \* timing\.ticksPerAdvance\) \/ timing\.tickRateHz/);
  assert.match(source, /legacyTickRateHz = 10/);
  assert.doesNotMatch(source, /1000 \/ 70|Wolf3D's original simulation/);
});

test("Wolf3D browser and test loading share an ordered, input-bounded module list", async () => {
  assert.deepEqual(wolf3dModules, [
    "wl-def", "wl-fixed", "id-ca", "id-pm", "id-vl",
    "wl-main", "wl-game", "wl-agent", "wl-act2", "wl-draw", "wl-scale", "app"
  ]);
  assert.equal(wolf3dSources.length, wolf3dModules.length);
  assert.ok(wolf3dSources.every((module) => new TextEncoder().encode(module).length <= LIMIT));

  const runtime = await readFile(new URL("../src/examples/runtime/lisp-application.ts", import.meta.url), "utf8");
  assert.match(runtime, /source: string \| readonly string\[\]/);
  assert.match(runtime, /for \(const module of typeof source === "string" \? \[source\] : source\)/);

  const examples = await readFile(new URL("../src/examples.ts", import.meta.url), "utf8");
  const moduleBlock = examples.match(/const wolf3dApplicationModules = \[([\s\S]*?)\];/)?.[1] ?? "";
  assert.deepEqual(moduleBlock.match(/wolf3d[A-Za-z]+Source/g), [
    "wolf3dDefSource", "wolf3dFixedSource", "wolf3dMapSource", "wolf3dPageSource",
    "wolf3dPaletteSource", "wolf3dTablesSource", "wolf3dGameSource", "wolf3dAgentSource",
    "wolf3dActorsSource", "wolf3dDrawSource", "wolf3dScaleSource", "wolf3dAppSource"
  ]);
  assert.match(examples, /runApplication\(root, wolf3dApplicationModules\)/);
  assert.match(examples, /wolf3dApplicationModules\.join\("\\n"\)/);
});
