import assert from "node:assert/strict";
import test from "node:test";

import { createSeedSession } from "./seed-session.mjs";

const SOURCE_FORM_CONFIG = Object.freeze({
  generator: "yalisp-source-forms-v1",
  shrinkPolicy: "not-run-without-failure-v1",
  seed: 0x53524346,
  cases: 512,
  maxDepth: 5,
  minimalShrunkFailure: null,
});

const symbols = Object.freeze([
  "alpha", "beta?", "gamma!", "+", "x-1", "lambda", "λ", "rocket→",
]);
const strings = Object.freeze([
  "", "plain", "say \"hi\" \\", "line\nnext", "tab\tend", "sun ☀ λ → 🚀",
]);

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

function sourceString(value) {
  let result = '"';
  for (const character of value) {
    if (character === '"' || character === "\\") result += `\\${character}`;
    else result += character;
  }
  return `${result}"`;
}

function generateForm(next, coverage, depth = 0) {
  const leaf = depth >= SOURCE_FORM_CONFIG.maxDepth;
  const kind = next() % (leaf ? 4 : 10);
  if (kind === 0) { coverage.atom += 1; return choose(next, ["nil", "true", "false"]); }
  if (kind === 1) { coverage.atom += 1; return String((next() % 2_000_001) - 1_000_000); }
  if (kind === 2) { coverage.atom += 1; return choose(next, symbols); }
  if (kind === 3) { coverage.string += 1; return sourceString(choose(next, strings)); }
  if (kind === 4) {
    coverage.list += 1;
    const length = next() % 4;
    const items = Array.from({ length }, () => generateForm(next, coverage, depth + 1));
    return `(${items.join(trivia(next, coverage))})`;
  }
  if (kind === 5) {
    coverage.dotted += 1;
    const length = 1 + (next() % 3);
    const items = Array.from({ length }, () => generateForm(next, coverage, depth + 1));
    return `(${items.join(trivia(next, coverage))}${trivia(next, coverage)}.${trivia(next, coverage)}${generateForm(next, coverage, depth + 1)})`;
  }
  const [prefix, key] = [
    ["'", "quote"], ["`", "quasiquote"], [",", "unquote"], [",@", "splice"],
  ][kind - 6];
  coverage[key] += 1;
  return `${prefix}${generateForm(next, coverage, depth + 1)}`;
}

function trivia(next, coverage) {
  const value = choose(next, [" ", "\n", "\t", " ; generated\n", "\r\n"]);
  if (value.includes(";")) coverage.comment += 1;
  return value;
}

test("seeded source forms have canonical parse/print/parse idempotence", async (t) => {
  const next = random(SOURCE_FORM_CONFIG.seed);
  const coverage = {
    atom: 0, string: 0, list: 0, dotted: 0,
    quote: 0, quasiquote: 0, unquote: 0, splice: 0,
    comment: 0,
  };
  const firstReader = await createSeedSession({ boot: false });
  const secondReader = await createSeedSession({ boot: false });

  for (let index = 0; index < SOURCE_FORM_CONFIG.cases; index += 1) {
    const form = generateForm(next, coverage);
    const source = `${trivia(next, coverage)}${form}${trivia(next, coverage)}`;
    const printed = firstReader.evaluateCanonical(`(quote ${source})`);
    const reparsed = secondReader.evaluateCanonical(`(quote ${printed})`);
    assert.equal(reparsed, printed,
      `generated source case ${index}: ${JSON.stringify({ source, printed, reparsed })}`);
  }

  for (const [category, count] of Object.entries(coverage)) {
    assert.ok(count > 0, `generator did not cover ${category}`);
  }
  t.diagnostic(JSON.stringify({ ...SOURCE_FORM_CONFIG, coverage }));
});
