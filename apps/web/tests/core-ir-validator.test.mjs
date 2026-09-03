import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  CORE_IR_SCHEMA,
  hashCoreIr,
  irPair,
  irSymbol,
  serializeYalispData,
  validateCoreIr,
} from "../../../scripts/hardening/core-ir-v1.mjs";
import { createSeedSession } from "./seed-session.mjs";

const S = irSymbol;
const fixtureUrl = new URL("fixtures/core-ir-v1-example.lisp", import.meta.url);

function span(start, end, origins = [[S("macro"), S("when"), "m4/example.lisp", 0, 32]]) {
  return [S("src"), "m4/example.lisp", start, end, origins];
}

function constant(tail, value, start = 0, end = 1) {
  return [S("const"), tail, span(start, end), value];
}

function reference(tail, kind, nameOrId, start = 0, end = 1) {
  return [S("ref"), tail, span(start, end), [S(kind), nameOrId]];
}

function exampleProgram() {
  return [S(CORE_IR_SCHEMA),
    [S("begin"), true, span(0, 80), [
      [S("define"), false, span(0, 32), S("increment"),
        [S("lambda"), false, span(0, 32), [[S("bind"), 0, S("x")]], null,
          [S("call"), true, span(16, 31),
            reference(false, "global", S("+"), 16, 17),
            [reference(false, "local", 0, 19, 20), constant(false, 1, 21, 22)]]]],
      [S("if"), true, span(33, 80),
        reference(false, "global", S("flag"), 37, 41),
        [S("begin"), true, span(42, 68), [
          [S("set"), false, span(43, 58), [S("global"), S("result")], constant(false, 1, 56, 57)],
          reference(true, "global", S("result"), 59, 65),
        ]],
        constant(true, 0, 69, 70)],
    ]],
  ];
}

function cloneProgram() {
  return structuredClone(exampleProgram());
}

function expectInvalid(program, code, path, caps = undefined) {
  const report = validateCoreIr(program, { caps });
  assert.equal(report.status, "invalid");
  assert.equal(report.error.code, code);
  assert.deepEqual(report.error.path, path);
  return report;
}

function random(seed) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return state >>> 0;
  };
}

function generatedProgram(next, coverage) {
  const state = { nextBinding: 0, nextSource: 0 };
  const generatedSpan = () => {
    const start = state.nextSource;
    state.nextSource += 1;
    return [S("src"), "m4/generated.lisp", start, start + 1, [[S("generated"), S("property")]]];
  };
  const generatedLiteral = () => {
    const choice = next() % 6;
    if (choice === 0) return null;
    if (choice === 1) return Boolean(next() & 1);
    if (choice === 2) return (next() % 2_000_001) - 1_000_000;
    if (choice === 3) return `text-${next() % 97}`;
    if (choice === 4) return S(`symbol-${next() % 97}`);
    return irPair(S("left"), S("right"));
  };
  const generatedBinding = (scope) => (scope.length > 0 && (next() & 1)
    ? [S("local"), scope[next() % scope.length]]
    : [S("global"), S(`global-${next() % 11}`)]);
  const generate = (tail, scope, depth = 0) => {
    const leaf = depth >= 6;
    const kind = next() % (leaf ? 2 : 8);
    if (kind === 0) {
      coverage.const += 1;
      return [S("const"), tail, generatedSpan(), generatedLiteral()];
    }
    if (kind === 1) {
      coverage.ref += 1;
      return [S("ref"), tail, generatedSpan(), generatedBinding(scope)];
    }
    if (kind === 2) {
      coverage.set += 1;
      return [S("set"), tail, generatedSpan(), generatedBinding(scope), generate(false, scope, depth + 1)];
    }
    if (kind === 3) {
      coverage.define += 1;
      return [S("define"), tail, generatedSpan(), S(`definition-${next() % 11}`), generate(false, scope, depth + 1)];
    }
    if (kind === 4) {
      coverage.if += 1;
      return [S("if"), tail, generatedSpan(), generate(false, scope, depth + 1),
        generate(tail, scope, depth + 1), generate(tail, scope, depth + 1)];
    }
    if (kind === 5) {
      coverage.lambda += 1;
      const fixedCount = next() % 3;
      const parameters = [];
      const childScope = [...scope];
      for (let index = 0; index < fixedCount; index += 1) {
        const id = state.nextBinding;
        state.nextBinding += 1;
        parameters.push([S("bind"), id, S(`parameter-${id}`)]);
        childScope.push(id);
      }
      let rest = null;
      if (next() & 1) {
        const id = state.nextBinding;
        state.nextBinding += 1;
        rest = [S("bind"), id, S(`rest-${id}`)];
        childScope.push(id);
      }
      return [S("lambda"), tail, generatedSpan(), parameters, rest, generate(true, childScope, depth + 1)];
    }
    if (kind === 6) {
      coverage.call += 1;
      const count = next() % 3;
      return [S("call"), tail, generatedSpan(), generate(false, scope, depth + 1),
        Array.from({ length: count }, () => generate(false, scope, depth + 1))];
    }
    coverage.begin += 1;
    const count = next() % 4;
    return [S("begin"), tail, generatedSpan(), Array.from({ length: count }, (_, index) => (
      generate(index === count - 1 ? tail : false, scope, depth + 1)
    ))];
  };
  return [S(CORE_IR_SCHEMA), generate(true, [])];
}

test("the reviewed IR example is canonical YaLisp data with a pinned identity", async (t) => {
  const program = exampleProgram();
  const source = serializeYalispData(program);
  const fixture = (await readFile(fixtureUrl, "utf8")).trimEnd();
  assert.equal(source, fixture);
  assert.equal(hashCoreIr(program), "12e1ba6d916787d5fcde58bce0ff722342040dee6a58527d9f1fc97787c1424b");

  const session = await createSeedSession({ boot: false });
  assert.equal(session.evaluateCanonical(`'${fixture}`), fixture,
    "the seed reader/printer must preserve the canonical IR bytes as data");
  t.diagnostic(JSON.stringify({ schema: CORE_IR_SCHEMA, bytes: Buffer.byteLength(fixture), sha256: hashCoreIr(program) }));
});

test("validation covers every v1 opcode, lexical binding, source map, and tail rule", () => {
  const report = validateCoreIr(exampleProgram());
  assert.equal(report.status, "valid");
  assert.equal(report.error, null);
  assert.deepEqual(report.metrics, {
    nodesVisited: 14,
    maxDepth: 5,
    sourceSpans: 14,
    sourceOrigins: 14,
    bindings: 1,
    literalNodes: 3,
    literalBytes: 0,
  });
});

test("fresh and warmed validation is deterministic and does not mutate IR", () => {
  const program = exampleProgram();
  const before = serializeYalispData(program);
  const expected = JSON.stringify(validateCoreIr(program));
  for (let run = 0; run < 32; run += 1) {
    assert.equal(JSON.stringify(validateCoreIr(structuredClone(program))), expected, `run ${run}`);
  }
  assert.equal(serializeYalispData(program), before);
});

test("seeded generated IR graphs validate and deterministic mutations fail", (t) => {
  const config = { generator: "yalisp-core-ir-v1-graphs", seed: 0x49525631, cases: 256, maxDepth: 6 };
  const next = random(config.seed);
  const coverage = { const: 0, ref: 0, set: 0, define: 0, if: 0, lambda: 0, call: 0, begin: 0 };
  const digest = createHash("sha256");
  let largestNodeCount = 0;
  for (let index = 0; index < config.cases; index += 1) {
    const program = generatedProgram(next, coverage);
    const report = validateCoreIr(program);
    assert.equal(report.status, "valid", `generated case ${index}: ${JSON.stringify(report.error)}`);
    largestNodeCount = Math.max(largestNodeCount, report.metrics.nodesVisited);
    const canonical = serializeYalispData(program);
    assert.equal(serializeYalispData(structuredClone(program)), canonical, `canonical case ${index}`);
    digest.update(hashCoreIr(program));

    const malformed = structuredClone(program);
    malformed[1][1] = false;
    const invalid = validateCoreIr(malformed);
    assert.equal(invalid.error.code, "tail-position", `mutation case ${index}`);
    assert.deepEqual(invalid.error.path, ["root", "tail"], `mutation path ${index}`);
  }
  for (const [opcode, count] of Object.entries(coverage)) assert.ok(count > 0, `generator missed ${opcode}`);
  const aggregateSha256 = digest.digest("hex");
  assert.equal(aggregateSha256, "c7e849d3916c957c1f2d8a6c43209cdd11c432ea6d1d750aa28db2087cebc342");
  t.diagnostic(JSON.stringify({ ...config, coverage, largestNodeCount, aggregateSha256 }));
});

test("validation reports the deterministic earliest malformed field", () => {
  const schema = cloneProgram();
  schema[0] = S("other-ir");
  expectInvalid(schema, "program-shape", []);

  const opcode = cloneProgram();
  opcode[1][0] = S("unknown");
  expectInvalid(opcode, "unknown-opcode", ["root", "opcode"]);

  const tail = cloneProgram();
  tail[1][3][0][1] = true;
  expectInvalid(tail, "tail-position", ["root", "forms", 0, "tail"]);

  const source = cloneProgram();
  source[1][2][3] = -1;
  expectInvalid(source, "source-range", ["root", "source", "range"]);

  const origin = cloneProgram();
  origin[1][2][4][0] = [S("macro"), S("when")];
  expectInvalid(origin, "source-origin-shape", ["root", "source", "origins", 0]);

  const arity = cloneProgram();
  arity[1][3][0].push(constant(false, 9));
  expectInvalid(arity, "node-arity", ["root", "forms", 0]);

  const local = cloneProgram();
  local[1][3][0][4][5][4][0][3][1] = 99;
  expectInvalid(local, "unbound-local", ["root", "forms", 0, "value", "body", "arguments", 0, "binding", "id"]);

  const duplicate = cloneProgram();
  duplicate[1][3][0][4][4] = [S("bind"), 0, S("rest")];
  expectInvalid(duplicate, "duplicate-binding-id", ["root", "forms", 0, "value", "rest", "id"]);
});

test("node, nesting, literal, source-origin, and cycle caps fail at exact boundaries", () => {
  assert.throws(() => validateCoreIr(exampleProgram(), { caps: { maxNodez: 1 } }), /unknown core IR cap/);
  assert.throws(() => validateCoreIr(exampleProgram(), { caps: [] }), /caps must be a plain object/);
  assert.equal(validateCoreIr(exampleProgram(), { caps: { maxNodes: 14, maxDepth: 5, maxLiteralNodes: 3 } }).status, "valid");
  const nodes = expectInvalid(exampleProgram(), "node-count-limit", ["root", "forms", 1, "else"], { maxNodes: 13 });
  assert.equal(nodes.metrics.nodesVisited, 13);
  const depth = expectInvalid(exampleProgram(), "node-depth-limit",
    ["root", "forms", 0, "value", "body", "callee"], { maxDepth: 4 });
  assert.equal(depth.metrics.maxDepth, 4);
  const literals = expectInvalid(exampleProgram(), "literal-node-limit",
    ["root", "forms", 1, "else", "value"], { maxLiteralNodes: 2 });
  assert.equal(literals.metrics.literalNodes, 2);

  const origins = cloneProgram();
  origins[1][2][4].push([S("generated"), S("desugared")]);
  expectInvalid(origins, "source-origin-limit", ["root", "source", "origins", 1], { maxOriginsPerSpan: 1 });

  const sourceUnitBytes = Buffer.byteLength("m4/example.lisp");
  assert.equal(validateCoreIr(exampleProgram(), { caps: { maxSourceBytes: sourceUnitBytes } }).status, "valid");
  expectInvalid(exampleProgram(), "source-unit", ["root", "source", "unit"],
    { maxSourceBytes: sourceUnitBytes - 1 });

  const cyclicCall = [S("call"), true, span(0, 1), null, []];
  cyclicCall[3] = cyclicCall;
  const graphCycle = [S(CORE_IR_SCHEMA), cyclicCall];
  expectInvalid(graphCycle, "node-cycle", ["root", "callee"]);

  const literalCycle = [];
  literalCycle.push(irPair(S("head"), literalCycle));
  const literal = [S(CORE_IR_SCHEMA), constant(true, literalCycle)];
  expectInvalid(literal, "literal-cycle", ["root", "value", 0, "cdr"]);
});

test("portable literals retain dotted data and reject host objects or out-of-range numbers", async () => {
  const dotted = [S(CORE_IR_SCHEMA), constant(true, irPair(S("left"), S("right")))];
  assert.equal(validateCoreIr(dotted).status, "valid");
  assert.equal(serializeYalispData(dotted),
    '(yalisp-core-ir-v1 (const true (src "m4/example.lisp" 0 1 ((macro when "m4/example.lisp" 0 32))) (left . right)))');

  const pairChain = [S(CORE_IR_SCHEMA), constant(true,
    irPair(S("left"), irPair(S("middle"), [S("right")])))];
  const pairSource = serializeYalispData(pairChain);
  assert.equal(pairSource,
    '(yalisp-core-ir-v1 (const true (src "m4/example.lisp" 0 1 ((macro when "m4/example.lisp" 0 32))) (left middle right)))');
  const reader = await createSeedSession({ boot: false });
  assert.equal(reader.evaluateCanonical(`'${pairSource}`), pairSource);

  const large = [S(CORE_IR_SCHEMA), constant(true, 1_073_741_824)];
  expectInvalid(large, "literal-number", ["root", "value"]);
  assert.throws(() => serializeYalispData(large), /not portable YaLisp data/);
  const largeSourceOffset = cloneProgram();
  largeSourceOffset[1][2][3] = 1_073_741_824;
  expectInvalid(largeSourceOffset, "source-range", ["root", "source", "range"]);
  const host = [S(CORE_IR_SCHEMA), constant(true, new Date(0))];
  expectInvalid(host, "literal-type", ["root", "value"]);
  const malformedSymbol = [S(CORE_IR_SCHEMA), constant(true, { type: "symbol", name: "two words" })];
  expectInvalid(malformedSymbol, "literal-type", ["root", "value"]);

  const boundedString = [S(CORE_IR_SCHEMA), constant(true, "λx")];
  assert.equal(validateCoreIr(boundedString, { caps: { maxLiteralBytes: 3 } }).status, "valid");
  const bytes = expectInvalid(boundedString, "literal-byte-limit", ["root", "value"], { maxLiteralBytes: 2 });
  assert.equal(bytes.metrics.literalBytes, 0, "a refused literal is not charged partially");
});
