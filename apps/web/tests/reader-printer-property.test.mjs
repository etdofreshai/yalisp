import assert from "node:assert/strict";
import test from "node:test";

import { createSeedSession } from "./seed-session.mjs";

const PROPERTY_CONFIG = Object.freeze({
  generator: "yalisp-acyclic-data-v1",
  seed: 0x59414c49,
  cases: 256,
  maxDepth: 4,
});

const symbols = Object.freeze(["alpha", "beta?", "gamma!", "+", "x-1", "lambda", "λ", "rocket→"]);
const stringAtoms = Object.freeze(["", "plain", "quote\"slash\\", "line\nnext", "tab\tend", "sun ☀ λ → 🚀"]);

function random(seed) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return state >>> 0;
  };
}

function choose(next, values) {
  return values[next() % values.length];
}

function generatedString(next) {
  const pieces = [
    choose(next, stringAtoms),
    String.fromCharCode(next() % 32),
    choose(next, ["", "A", "é", "λ", "🚀"]),
  ];
  return pieces.slice(0, 1 + (next() % pieces.length)).join("");
}

function generateValue(next, depth = 0) {
  const leaf = depth >= PROPERTY_CONFIG.maxDepth;
  const kind = next() % (leaf ? 5 : 8);
  if (kind === 0) return { kind: "nil" };
  if (kind === 1) return { kind: "boolean", value: Boolean(next() & 1) };
  if (kind === 2) return { kind: "integer", value: (next() % 2000001) - 1000000 };
  if (kind === 3) return { kind: "symbol", value: choose(next, symbols) };
  if (kind === 4) return { kind: "string", value: generatedString(next) };
  const length = next() % 5;
  const items = Array.from({ length }, () => generateValue(next, depth + 1));
  if (kind === 5 || length === 0) return { kind: "list", items };
  return { kind: "dotted", items, tail: generateValue(next, depth + 1) };
}

function sourceString(value) {
  let source = '"';
  for (const character of value) {
    if (character === '"' || character === "\\") source += `\\${character}`;
    else source += character;
  }
  return `${source}"`;
}

function source(value) {
  if (value.kind === "nil") return "nil";
  if (value.kind === "boolean") return value.value ? "true" : "false";
  if (value.kind === "integer") return String(value.value);
  if (value.kind === "symbol") return value.value;
  if (value.kind === "string") return sourceString(value.value);
  if (value.kind === "list") return `(${value.items.map(source).join(" ")})`;
  return `(${value.items.map(source).join(" ")} . ${source(value.tail)})`;
}

async function roundTrip(dataSource) {
  const session = await createSeedSession({ boot: false });
  const printed = session.evaluateCanonical(`'${dataSource}`);
  const reparsed = session.evaluateCanonical(`'${printed}`);
  return { printed, reparsed };
}

async function assertRoundTrip(dataSource, label) {
  const observation = await roundTrip(dataSource);
  assert.equal(observation.reparsed, observation.printed,
    `${label}: ${JSON.stringify({ source: dataSource, ...observation })}`);
  return observation.printed;
}

test("canonical string escapes are reader/printer fixed points", async () => {
  const edges = [
    ["empty", ""],
    ["quote and slash", 'say "hi" \\'],
    ["newline", "line\nnext"],
    ["tab", "tab\tend"],
    ["carriage return", "left\rright"],
    ["backspace", "left\bright"],
    ["form feed", "left\fright"],
    ["other control", `left${String.fromCharCode(1)}right`],
    ["unicode", "sun ☀ λ → 🚀"],
  ];
  for (const [label, value] of edges) await assertRoundTrip(sourceString(value), label);
});

test("fixed data grammar edges survive canonical parse/print/parse", async () => {
  for (const [index, dataSource] of [
    "nil", "true", "false", "0", "-1073741824", "1073741823",
    "alpha", "λ", "()", "(1 2 3)", "(1 . 2)", "((1 . 2) (3 (4)))",
    "; comment before data\n(alpha ; nested comment\n beta)",
  ].entries()) await assertRoundTrip(dataSource, `fixed edge ${index}`);
});

test("seeded generated acyclic data satisfies canonical read(print(value)) equality", async (t) => {
  const next = random(PROPERTY_CONFIG.seed);
  t.diagnostic(JSON.stringify(PROPERTY_CONFIG));
  for (let index = 0; index < PROPERTY_CONFIG.cases; index += 1) {
    const dataSource = source(generateValue(next));
    await assertRoundTrip(dataSource, `generated case ${index}`);
  }
});

test("malformed prefix, closing, string, and dotted forms fail at the reader boundary", async () => {
  for (const [sourceText, expected] of [
    ['"unterminated', "unterminated string"],
    ["(+ 1 2", "unterminated list"],
    [")", "read error"],
    ["(1 2))", "(1 2)\nread error"],
    ["(. 1)", "read error"],
    ["(1 .)", "read error"],
    ["(1 . 2", "read error"],
    ["(1 . 2 3)", "read error"],
    ["'", "read error"],
    ["`", "read error"],
    [",", "read error"],
    [",@", "read error"],
  ]) {
    const session = await createSeedSession({ boot: false });
    assert.throws(() => session.read(sourceText), (error) => {
      assert.equal(error.diagnostic, expected);
      return true;
    });
  }

  const valid = await createSeedSession({ boot: false });
  assert.equal(valid.read("(1 . 2)"), "(1 . 2)");
});
