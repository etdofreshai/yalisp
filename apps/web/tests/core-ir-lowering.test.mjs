import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import {
  CoreIrLoweringError,
  lowerSourceToCoreIr,
  parseYalispSource,
} from "../../../scripts/hardening/core-ir-lowering.mjs";
import {
  hashCoreIr,
  serializeYalispData,
  validateCoreIr,
} from "../../../scripts/hardening/core-ir-v1.mjs";
import { createSeedSession } from "./seed-session.mjs";

const unit = "m4/lowering.lisp";

function random(seed) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return state >>> 0;
  };
}

function generatedCoreSource(next, coverage) {
  const state = { nextName: 0 };
  const atom = (scope) => {
    const kind = next() % 5;
    coverage.const += 1;
    if (kind === 0) return String((next() % 2_000_001) - 1_000_000);
    if (kind === 1) return next() & 1 ? "true" : "false";
    if (kind === 2) return `\"text-${next() % 97}\"`;
    if (kind === 3) return `'(${next() % 11} . generated)`;
    coverage.ref += 1;
    return scope.length && next() & 1 ? scope[next() % scope.length] : `global-${next() % 13}`;
  };
  const form = (scope, depth = 0, top = false) => {
    if (depth >= 5) return atom(scope);
    const kind = next() % (top ? 8 : 7);
    if (kind === 0) return atom(scope);
    if (kind === 1) {
      coverage.if += 1;
      return `(if ${form(scope, depth + 1)} ${form(scope, depth + 1)} ${form(scope, depth + 1)})`;
    }
    if (kind === 2) {
      coverage.lambda += 1;
      const count = next() % 3;
      const names = Array.from({ length: count }, () => `local-${state.nextName++}`);
      let parameters = `(${names.join(" ")})`;
      if (next() & 1) {
        const rest = `rest-${state.nextName++}`;
        parameters = names.length ? `(${names.join(" ")} . ${rest})` : rest;
        names.push(rest);
      }
      return `(lambda ${parameters} ${form([...scope, ...names], depth + 1)})`;
    }
    if (kind === 3) {
      coverage.call += 1;
      const count = next() % 4;
      const args = Array.from({ length: count }, () => form(scope, depth + 1));
      return `(${[`callee-${next() % 7}`, ...args].join(" ")})`;
    }
    if (kind === 4) {
      coverage.begin += 1;
      const count = next() % 4;
      return `(begin${Array.from({ length: count }, () => ` ${form(scope, depth + 1)}`).join("")})`;
    }
    if (kind === 5) {
      coverage.set += 1;
      const name = scope.length && next() & 1 ? scope[next() % scope.length] : `global-${next() % 13}`;
      return `(set! ${name} ${form(scope, depth + 1)})`;
    }
    if (kind === 6) {
      coverage.const += 1;
      return `'(${next() % 11} generated \"literal\")`;
    }
    coverage.define += 1;
    return `(define definition-${next() % 13} ${form(scope, depth + 1)})`;
  };
  return form([], 0, true);
}

test("the span-aware reader matches canonical seed data and UTF-8 byte offsets", async () => {
  const source = "; leading\n(α \"🚀\" (1 . β))\n'γ";
  const parsed = parseYalispSource(source, { unit });
  assert.equal(parsed.sourceBytes, Buffer.byteLength(source));
  assert.equal(parsed.forms.length, 2);
  assert.equal(serializeYalispData(parsed.forms[0].value), '(α "🚀" (1 . β))');
  assert.equal(serializeYalispData(parsed.forms[1].value), "(quote γ)");
  assert.deepEqual(
    parsed.forms.map(({ startByte, endByte }) => [startByte, endByte]),
    [[10, 30], [31, 34]],
  );

  const seed = await createSeedSession({ boot: false });
  for (const form of parsed.forms) {
    const canonical = serializeYalispData(form.value);
    assert.equal(seed.evaluateCanonical(`'${canonical}`), canonical);
  }
});

test("expanded core forms lower to validated IR with exact effect and tail order", async () => {
  const source = "(begin (define answer 40) (set! answer (+ answer 2)) (if answer answer 0))";
  const lowered = await lowerSourceToCoreIr(source, { unit });
  assert.equal(validateCoreIr(lowered.program).status, "valid");
  assert.equal(lowered.expansionCount, 0);
  assert.equal(serializeYalispData(lowered.program),
    '(yalisp-core-ir-v1 (begin true (src "m4/lowering.lisp" 0 74 ()) ((define false (src "m4/lowering.lisp" 7 25 ()) answer (const false (src "m4/lowering.lisp" 22 24 ()) 40)) (set false (src "m4/lowering.lisp" 26 52 ()) (global answer) (call false (src "m4/lowering.lisp" 39 51 ()) (ref false (src "m4/lowering.lisp" 40 41 ()) (global +)) ((ref false (src "m4/lowering.lisp" 42 48 ()) (global answer)) (const false (src "m4/lowering.lisp" 49 50 ()) 2)))) (if true (src "m4/lowering.lisp" 53 73 ()) (ref false (src "m4/lowering.lisp" 57 63 ()) (global answer)) (ref true (src "m4/lowering.lisp" 64 70 ()) (global answer)) (const true (src "m4/lowering.lisp" 71 72 ()) 0)))))');
});

test("lexical IDs are program-unique and source names never replace binding identity", async () => {
  const lowered = await lowerSourceToCoreIr(
    "((lambda (x) ((lambda (x . rest) (begin (set! x (car rest)) x)) x 9)) 4)",
    { unit },
  );
  const source = serializeYalispData(lowered.program);
  assert.match(source, /\(bind 0 x\)/);
  assert.match(source, /\(bind 1 x\)/);
  assert.match(source, /\(bind 2 rest\)/);
  assert.match(source, /\(local 0\)/);
  assert.match(source, /\(local 1\)/);
  assert.match(source, /\(local 2\)/);
  assert.equal(validateCoreIr(lowered.program).status, "valid");
});

test("boot macros expand recursively and lower deterministically without evaluating user code", async (t) => {
  const source = "(let ((x 3)) (when x (+ x 4)))";
  const hashes = [];
  for (let run = 0; run < 8; run += 1) {
    const seed = await createSeedSession({ boot: true });
    const lowered = await lowerSourceToCoreIr(source, {
      unit,
      expandOuter: (form) => seed.expandCanonical(form),
    });
    assert.equal(lowered.expansionCount, 2);
    assert.equal(validateCoreIr(lowered.program).status, "valid");
    hashes.push(hashCoreIr(lowered.program));
  }
  assert.equal(new Set(hashes).size, 1);
  assert.equal(hashes[0], "a693116b6607ef5065104858a31b873f4d18a3de3435d95b45abc2e2be06fab4");
  t.diagnostic(JSON.stringify({ fixture: "yalisp-core-ir-lowering-v1", runs: hashes.length, sha256: hashes[0] }));
});

test("fixed-seed generated core source lowers deterministically across every IR opcode", async (t) => {
  const config = { generator: "yalisp-core-source-v1", seed: 0x4c4f5745, cases: 256, maxDepth: 5 };
  const next = random(config.seed);
  const coverage = { const: 0, ref: 0, set: 0, define: 0, if: 0, lambda: 0, call: 0, begin: 0 };
  const digest = createHash("sha256");
  let largestIr = 0;
  for (let index = 0; index < config.cases; index += 1) {
    const source = generatedCoreSource(next, coverage);
    const first = await lowerSourceToCoreIr(source, { unit });
    const second = await lowerSourceToCoreIr(source, { unit });
    const canonical = serializeYalispData(first.program);
    assert.equal(serializeYalispData(second.program), canonical, `generated case ${index}: ${source}`);
    assert.equal(first.validation.status, "valid", `generated case ${index}: ${source}`);
    largestIr = Math.max(largestIr, first.validation.metrics.nodesVisited);
    digest.update(hashCoreIr(first.program));
  }
  for (const [opcode, count] of Object.entries(coverage)) assert.ok(count > 0, `generator missed ${opcode}`);
  const aggregateSha256 = digest.digest("hex");
  assert.equal(aggregateSha256, "2677a95639aa4aeb3b6fc2cf153eed8cc670de3ef0cc9c2ba62d81da4283004e");
  t.diagnostic(JSON.stringify({ ...config, coverage, largestIr, aggregateSha256 }));
});

test("macro-generated nodes retain the call span and ordered provenance", async () => {
  const seed = await createSeedSession({ boot: true });
  const lowered = await lowerSourceToCoreIr("(let ((x 3)) (when x x))", {
    unit,
    expandOuter: (form) => seed.expandCanonical(form),
  });
  const report = validateCoreIr(lowered.program);
  assert.equal(report.status, "valid");
  assert.equal(report.metrics.sourceOrigins > 0, true);
  const canonical = serializeYalispData(lowered.program);
  assert.match(canonical, /\(macro let "m4\/lowering\.lisp" 0 24\)/);
  assert.match(canonical, /\(macro when "m4\/lowering\.lisp" 0 24\)/);
  assert.ok(canonical.indexOf("(macro let") < canonical.indexOf("(macro when"));
});

test("special forms keep evaluator precedence and global macros respect lexical heads", async () => {
  const calls = [];
  const expandOuter = (form) => {
    calls.push(form);
    if (form.startsWith("(shadow ")) throw new Error("lexical shadow was expanded");
    return form;
  };
  const lowered = await lowerSourceToCoreIr("((lambda (shadow) (shadow 1)) (lambda (x) x))", {
    unit,
    expandOuter,
  });
  assert.equal(validateCoreIr(lowered.program).status, "valid");
  assert.ok(!calls.some((form) => form.startsWith("(shadow ")));
  assert.ok(!calls.some((form) => form.startsWith("(lambda ")),
    "kernel special forms are lowered before macro lookup");

  calls.length = 0;
  await lowerSourceToCoreIr("(if (a) (b) (c))", { unit, expandOuter });
  assert.deepEqual(calls, ["(a)", "(b)", "(c)"],
    "macro lookup follows the evaluator's source order even across branches");
});

test("reader, lowering, and expansion caps fail with stable codes and byte locations", async () => {
  const malformed = [
    [")", "reader-closing"],
    ["(", "reader-unterminated-list"],
    ["\"x", "reader-unterminated-string"],
    ["'", "reader-prefix"],
    ["(. 1)", "reader-dotted-tail"],
    ["(1 .)", "reader-dotted-tail"],
  ];
  for (const [source, code] of malformed) {
    assert.throws(() => parseYalispSource(source, { unit }), (error) => error.code === code, source);
  }
  assert.throws(() => parseYalispSource("(1 . 2 3)", { unit }), (error) => {
    assert.equal(error instanceof CoreIrLoweringError, true);
    assert.equal(error.code, "reader-dotted-tail");
    assert.equal(error.startByte, 7);
    return true;
  });
  assert.throws(() => parseYalispSource("(a (b))", { unit, caps: { maxSyntaxDepth: 1 } }),
    (error) => error.code === "reader-depth-limit");
  assert.equal(parseYalispSource("(a)", { unit, caps: { maxSourceBytes: 3 } }).sourceBytes, 3);
  assert.throws(() => parseYalispSource("(a)", { unit, caps: { maxSourceBytes: 2 } }),
    (error) => error.code === "reader-source-limit" && error.detail === 2);
  assert.equal(parseYalispSource("(a)", { unit, caps: { maxSyntaxNodes: 2, maxSyntaxDepth: 2 } })
    .metrics.syntaxNodes, 2);
  assert.throws(() => parseYalispSource("(a)", { unit, caps: { maxSyntaxNodes: 1 } }),
    (error) => error.code === "reader-node-limit" && error.detail === 1);
  await assert.rejects(() => lowerSourceToCoreIr("(macro (x) x)", { unit }),
    (error) => error.code === "unsupported-core-form" && error.startByte === 0);
  await assert.rejects(() => lowerSourceToCoreIr("", { unit }),
    (error) => error.code === "lowering-form-count" && error.detail === 0);
  await assert.rejects(() => lowerSourceToCoreIr("1 2", { unit }),
    (error) => error.code === "lowering-form-count" && error.detail === 2);
  await assert.rejects(() => lowerSourceToCoreIr("(lambda () (define x 1))", { unit }),
    (error) => error.code === "unsupported-local-define");
  await assert.rejects(() => lowerSourceToCoreIr("(loop 1)", {
    unit,
    caps: { maxMacroExpansions: 2 },
    expandOuter: (form) => form === "(loop 1)" ? "(loop 2)" : "(loop 1)",
  }), (error) => error.code === "macro-expansion-limit");

  const finiteExpansion = (form) => form === "(a)" ? "(b)" : "1";
  const exact = await lowerSourceToCoreIr("(a)", {
    unit,
    caps: {
      maxMacroExpansions: 2,
      maxMacroExpansionBytes: 4,
      maxSyntaxNodes: 5,
      maxOriginsPerSpan: 2,
    },
    expandOuter: finiteExpansion,
  });
  assert.equal(exact.expansionCount, 2);
  assert.deepEqual(exact.syntaxMetrics, {
    inputNodes: 2,
    totalNodes: 5,
    maxDepth: 2,
    macroExpansionBytes: 4,
  });
  for (const [cap, value, code] of [
    ["maxMacroExpansions", 1, "macro-expansion-limit"],
    ["maxMacroExpansionBytes", 3, "macro-expansion-byte-limit"],
    ["maxSyntaxNodes", 4, "macro-syntax-node-limit"],
    ["maxOriginsPerSpan", 1, "source-origin-limit"],
  ]) {
    await assert.rejects(() => lowerSourceToCoreIr("(a)", {
      unit,
      caps: { [cap]: value },
      expandOuter: finiteExpansion,
    }), (error) => error.code === code && error.detail === value, cap);
  }

  await assert.rejects(() => lowerSourceToCoreIr("(a)", {
    unit,
    caps: { maxSyntaxNodes: 3 },
    expandOuter: () => "(b)",
  }), (error) => error.code === "macro-syntax-node-limit" && error.detail === 3);
  await assert.rejects(() => lowerSourceToCoreIr("(a)", {
    unit,
    caps: { maxMacroExpansionBytes: 3 },
    expandOuter: () => "(bb)",
  }), (error) => error.code === "macro-expansion-byte-limit" && error.detail === 3);
  await assert.rejects(() => lowerSourceToCoreIr("(a)", {
    unit,
    caps: { maxOriginsPerSpan: 1 },
    expandOuter: (form) => form === "(a)" ? "(b)" : "(c)",
  }), (error) => error.code === "source-origin-limit" && error.detail === 1);
  assert.throws(() => parseYalispSource("1", { unit: "λλ", caps: { maxSourceUnitBytes: 3 } }),
    (error) => error.code === "source-unit-limit" && error.detail === 3);
});
