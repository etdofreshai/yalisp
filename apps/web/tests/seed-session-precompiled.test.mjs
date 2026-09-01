import assert from "node:assert/strict";
import { performance } from "node:perf_hooks";
import { readFile } from "node:fs/promises";
import test from "node:test";
import wabtInit from "wabt";

import {
  SEED_ARTIFACT_PINS,
  createSeedSession,
  getSeedSessionSetupMetrics,
  verifyPinnedSeedArtifacts,
} from "./seed-session.mjs";

const artifactUrls = {
  wat: new URL("../src/seed/bootstrap.wat", import.meta.url),
  wasm: new URL("../public/yalisp/seed.wasm", import.meta.url),
  boot: new URL("../public/yalisp/boot.lisp", import.meta.url),
};

async function artifacts() {
  const [wat, wasm, boot] = await Promise.all(Object.values(artifactUrls).map((url) => readFile(url)));
  return { wat, wasm, boot };
}

test("the checked-in seed is byte-identical to a fresh pinned WABT compilation", async (t) => {
  const source = await artifacts();
  assert.deepEqual(verifyPinnedSeedArtifacts(source), SEED_ARTIFACT_PINS);

  const compileStarted = performance.now();
  const wabt = await wabtInit();
  const parsed = wabt.parseWat("bootstrap.wat", source.wat.toString("utf8"), {});
  let fresh;
  try {
    parsed.validate();
    fresh = Buffer.from(parsed.toBinary({ write_debug_names: false }).buffer);
  } finally {
    parsed.destroy();
  }
  const freshCompilationMs = performance.now() - compileStarted;
  assert.deepEqual(fresh, source.wasm, "checked-in seed.wasm must exactly match fresh WABT output");

  const samples = [];
  for (let index = 0; index < 5; index += 1) {
    const started = performance.now();
    const session = await createSeedSession({ boot: false });
    samples.push(performance.now() - started);
    assert.equal(session.evaluate("(+ 20 22)"), "42");
  }
  const meanInstantiationMs = samples.reduce((sum, value) => sum + value, 0) / samples.length;
  const setup = getSeedSessionSetupMetrics();
  const coldPrecompiledMs = setup.moduleReadyMs + meanInstantiationMs;
  assert.ok(meanInstantiationMs < freshCompilationMs,
    `precompiled mean ${meanInstantiationMs.toFixed(3)} ms must beat fresh WABT ${freshCompilationMs.toFixed(3)} ms`);
  assert.ok(coldPrecompiledMs < freshCompilationMs,
    `validated cold precompiled ${coldPrecompiledMs.toFixed(3)} ms must beat fresh WABT ${freshCompilationMs.toFixed(3)} ms`);
  t.diagnostic(`fresh WABT ${freshCompilationMs.toFixed(3)} ms; validated precompiled cold ${coldPrecompiledMs.toFixed(3)} ms (${(freshCompilationMs / coldPrecompiledMs).toFixed(1)}x); cached session mean ${meanInstantiationMs.toFixed(3)} ms (${(freshCompilationMs / meanInstantiationMs).toFixed(1)}x)`);
});

test("every pinned input fails closed on length or content drift", async () => {
  const source = await artifacts();
  for (const name of ["wat", "wasm", "boot"]) {
    const changed = { ...source, [name]: new Uint8Array(source[name]) };
    changed[name][Math.floor(changed[name].length / 2)] ^= 1;
    assert.throws(() => verifyPinnedSeedArtifacts(changed), new RegExp(`seed ${name} drift`));

    const shortened = { ...source, [name]: source[name].subarray(0, source[name].length - 1) };
    assert.throws(() => verifyPinnedSeedArtifacts(shortened), new RegExp(`seed ${name} drift`));
  }
});

test("one immutable module creates independent sessions without a mutable cache", async () => {
  const before = getSeedSessionSetupMetrics();
  assert.equal(before.moduleCompilations, 1);
  assert.ok(Object.isFrozen(before));
  assert.ok(Object.isFrozen(before.artifacts));

  const first = await createSeedSession();
  const second = await createSeedSession();
  assert.notEqual(first.memoryBytes, 0);
  assert.equal(first.memoryBytes, second.memoryBytes);
  first.evaluateQuietly("(define only-in-first 73)");
  assert.equal(first.evaluate("only-in-first"), "73");
  assert.throws(() => second.evaluate("only-in-first"), (error) => {
    assert.equal(error.diagnostic, "unbound: only-in-first");
    return true;
  });

  const intact = await createSeedSession();
  assert.equal(intact.evaluate("(+ 19 23)"), "42");
  const after = getSeedSessionSetupMetrics();
  assert.equal(after.moduleCompilations, 1);
  assert.equal(after.sessionInstantiations, before.sessionInstantiations + 3);
  assert.equal(before.sessionInstantiations < after.sessionInstantiations, true,
    "an earlier metrics snapshot must not be a live mutable cache view");
  assert.deepEqual(Object.keys(intact), [
    "meter", "memoryBytes", "evaluate", "evaluateCanonical", "evaluateQuietly", "evaluateBytes", "ingestBytes",
  ]);
});
