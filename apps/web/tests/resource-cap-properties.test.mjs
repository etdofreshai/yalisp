import assert from "node:assert/strict";
import test from "node:test";

import { createSeedSession } from "./seed-session.mjs";

const CAPS = Object.freeze({
  inputBytes: 131_072 - 1_024,
  readerFrames: 1_024,
  readerWork: 65_536,
  expansionSteps: 1_024,
});

function quotedNestedLists(depth) {
  return `'${"(".repeat(depth)}nil${")".repeat(depth)}`;
}

function diagnostic(error) {
  return error && typeof error === "object" && "diagnostic" in error ? error.diagnostic : undefined;
}

async function depthDiagnostic(depth) {
  const session = await createSeedSession({ boot: false });
  try {
    session.evaluateQuietly(quotedNestedLists(depth));
    return null;
  } catch (error) {
    return diagnostic(error) ?? `${error.name}: ${error.message}`;
  }
}

test("the fixed host input region accepts its boundary and rejects one byte beyond it", async () => {
  const exact = await createSeedSession({ boot: false });
  assert.doesNotThrow(() => exact.evaluateQuietly(" ".repeat(CAPS.inputBytes)));

  const over = await createSeedSession({ boot: false });
  assert.throws(() => over.evaluateQuietly(" ".repeat(CAPS.inputBytes + 1)), (error) => {
    assert.match(error.message, /source exceeds the seed's 130048-byte input region/);
    return true;
  });
});

test("reader frame cap has a persisted minimal nested-list witness", async (t) => {
  let passing = 0;
  let failing = 1_024;
  assert.equal(await depthDiagnostic(failing), "depth cap", "the shrink upper bound must hit the named depth cap");
  while (passing + 1 < failing) {
    const candidate = Math.floor((passing + failing) / 2);
    const observed = await depthDiagnostic(candidate);
    if (observed === null) passing = candidate;
    else {
      assert.equal(observed, "depth cap", `depth ${candidate} must not fail through an incidental host trap`);
      failing = candidate;
    }
  }

  assert.equal(passing, 511);
  assert.equal(failing, 512);
  assert.equal(await depthDiagnostic(passing), null);
  assert.equal(await depthDiagnostic(failing), "depth cap");
  t.diagnostic(JSON.stringify({ shrinker: "binary-min-depth-v1", passingDepth: passing, minimalFailingDepth: failing, diagnostic: "depth cap" }));
});

test("reader work cap accepts 32768 empty forms and rejects the next", async (t) => {
  const passingForms = CAPS.readerWork / 2;
  const exact = await createSeedSession({ boot: false });
  assert.doesNotThrow(() => exact.evaluateQuietly("()".repeat(passingForms)));

  const over = await createSeedSession({ boot: false });
  assert.throws(() => over.evaluateQuietly("()".repeat(passingForms + 1)), (error) => {
    assert.equal(diagnostic(error), "work cap");
    return true;
  });
  t.diagnostic(JSON.stringify({ workAccounting: "read-form-plus-list-spine-v1", passingForms, minimalFailingForms: passingForms + 1, diagnostic: "work cap" }));
});

test("named macro expansion accepts 1024 steps and stops a self-reproducing step 1025", async (t) => {
  const exact = await createSeedSession();
  exact.evaluateQuietly("(define expand.remaining 1023)");
  exact.evaluateQuietly(`(define expand.counted
    (macro args
      (if (= expand.remaining 0)
          'complete
          (begin
            (set! expand.remaining (- expand.remaining 1))
            '(expand.counted)))))`);
  assert.equal(exact.expandCanonical("(expand.counted)"), "complete");
  assert.equal(exact.evaluateCanonical("expand.remaining"), "0");

  const over = await createSeedSession();
  over.evaluateQuietly("(define expand.forever (macro args '(expand.forever)))");
  assert.throws(() => over.expandCanonical("(expand.forever)"), (error) => {
    assert.equal(diagnostic(error), "macro expansion cap");
    return true;
  });
  t.diagnostic(JSON.stringify({ expansionAccounting: "outer-named-macro-step-v1", maxSteps: CAPS.expansionSteps, minimalWitness: "(expand.forever)", diagnostic: "macro expansion cap" }));
});
