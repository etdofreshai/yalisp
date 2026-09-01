import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import { createSeedSession } from "./seed-session.mjs";

const FIXTURES = Object.freeze([
  Object.freeze({
    id: "when-body-splice",
    source: "(when flag (+ 1 2) (+ 3 4))",
    expansion: "(if flag (begin (+ 1 2) (+ 3 4)) nil)",
  }),
  Object.freeze({
    id: "unless-body-splice",
    source: "(unless flag first second)",
    expansion: "(if flag nil (begin first second))",
  }),
  Object.freeze({
    id: "and-recursive-boundary",
    source: "(and a b c)",
    expansion: "(if a (and b c) false)",
  }),
  Object.freeze({
    id: "or-single-evaluation-hygiene",
    source: "(or a b c)",
    expansion: "((lambda (or--once-value or--rest-thunk) (if or--once-value or--once-value (or--rest-thunk))) a (lambda nil (or b c)))",
  }),
  Object.freeze({
    id: "defn-lowering",
    source: "(defn increment (x) (+ x 1))",
    expansion: "(define increment (lambda (x) (+ x 1)))",
  }),
  Object.freeze({
    id: "do-lowering",
    source: "(do first second third)",
    expansion: "(begin first second third)",
  }),
  Object.freeze({
    id: "let-parallel-bindings",
    source: "(let ((a 1) (b 2)) (+ a b))",
    expansion: "((lambda (a b) (+ a b)) 1 2)",
  }),
  Object.freeze({
    id: "cond-outer-step",
    source: "(cond ((= x 0) zero) (true other))",
    expansion: "(if (= x 0) (begin zero) (cond (true other)))",
  }),
]);

function expansionHash(expansions) {
  const hash = createHash("sha256");
  for (const [index, expansion] of expansions.entries()) {
    const bytes = Buffer.from(expansion, "utf8");
    const length = Buffer.alloc(4);
    length.writeUInt32BE(bytes.length);
    hash.update(String(index));
    hash.update(Buffer.from([0]));
    hash.update(length);
    hash.update(bytes);
  }
  return hash.digest("hex");
}

const EXPECTED_HASH = expansionHash(FIXTURES.map(({ expansion }) => expansion));
const PINNED_EXPECTED_HASH = "34214d55363aa0dc4a219434fffab85ab00cc10a9cc5e4b6842ddcbc61df6818";
const PINNED_LONG_LIVED_HASH = "457871727fca5559890b2a55b91fce9ea8d1107b3e66a7b92375dda0e3d83064";

async function observeFresh() {
  const session = await createSeedSession();
  assert.equal(typeof session.expandCanonical, "function",
    "the seed session must expose expansion independently from evaluation");
  return FIXTURES.map(({ source }) => session.expandCanonical(source));
}

test("authored boot macro expansions match in repeated fresh sessions", async (t) => {
  assert.equal(EXPECTED_HASH, PINNED_EXPECTED_HASH, "authored expansion fixture identity");
  const observations = [];
  for (let run = 0; run < 4; run += 1) observations.push(await observeFresh());
  for (const [run, expansions] of observations.entries()) {
    assert.deepEqual(expansions, FIXTURES.map(({ expansion }) => expansion), `fresh run ${run}`);
    assert.equal(expansionHash(expansions), EXPECTED_HASH, `fresh run ${run} hash`);
  }
  t.diagnostic(JSON.stringify({ fixtureVersion: "yalisp-macro-expansion-v1", cases: FIXTURES.length, freshRuns: observations.length, expectedHash: EXPECTED_HASH }));
});

test("a long-lived session repeats expansion without evaluating user forms", async (t) => {
  const session = await createSeedSession();
  assert.equal(typeof session.expandCanonical, "function",
    "the seed session must expose expansion independently from evaluation");
  session.evaluateQuietly("(define expansion.counter 0)");
  session.evaluateQuietly("(define repeat-form (macro (form) `(begin ,form ,form)))");
  session.evaluateQuietly("(define forward-form (macro (form) `(repeat-form ,form)))");

  for (let run = 0; run < 16; run += 1) {
    const expansions = FIXTURES.map(({ source }) => session.expandCanonical(source));
    assert.deepEqual(expansions, FIXTURES.map(({ expansion }) => expansion), `long-lived corpus run ${run}`);
    assert.equal(expansionHash(expansions), PINNED_EXPECTED_HASH, `long-lived corpus run ${run} hash`);
  }

  const expected = "(begin (set! expansion.counter (+ expansion.counter 1)) (set! expansion.counter (+ expansion.counter 1)))";
  const observations = [];
  for (let run = 0; run < 16; run += 1) {
    observations.push(session.expandCanonical("(forward-form (set! expansion.counter (+ expansion.counter 1)))"));
  }

  assert.deepEqual(observations, Array.from({ length: observations.length }, () => expected));
  assert.equal(expansionHash(observations), PINNED_LONG_LIVED_HASH, "long-lived custom macro hash");
  assert.equal(session.evaluateCanonical("expansion.counter"), "0",
    "expansion must not evaluate the user form produced by the macro");
  t.diagnostic(JSON.stringify({ fixtureVersion: "yalisp-macro-expansion-v1", longLivedRuns: observations.length, expansionHash: expansionHash(observations) }));
});

test("non-macro data and special forms remain unchanged by outer expansion", async () => {
  const session = await createSeedSession();
  assert.equal(typeof session.expandCanonical, "function",
    "the seed session must expose expansion independently from evaluation");
  for (const source of ["42", "symbol", "(unknown 1)", "((lambda (x) x) 1)", "(quote (when x y))", "(if flag yes no)", "(lambda (x) (when x x))"]) {
    assert.equal(session.expandCanonical(source), source);
  }
});
