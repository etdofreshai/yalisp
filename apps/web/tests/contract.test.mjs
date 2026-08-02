import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const source = await readFile(new URL("../src/main.ts", import.meta.url), "utf8");

test("landing page exposes its essential semantic and social contracts", () => {
  for (const marker of [
    'id="main"',
    'id="why"',
    'id="language"',
    "https://github.com/etdofreshai/yalisp",
    'data-features',
    'data-code',
    'data-principles'
  ]) {
    assert.ok(html.includes(marker), `missing ${marker}`);
  }
});

test("interactive controls have TypeScript behavior", () => {
  assert.ok(source.includes('navigator.clipboard.writeText'));
  assert.ok(source.includes('IntersectionObserver'));
  assert.ok(source.includes('aria-expanded'));
});

test("documentation presents the three reference interfaces", async () => {
  const docs = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  for (const marker of [
    'id="reference-interfaces"',
    'id="assembly"',
    'id="system-interface"',
    'id="host"'
  ]) {
    assert.ok(docs.includes(marker), `missing ${marker}`);
  }
});

test("documentation explains the bootstrapped core REPL", async () => {
  const docs = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  assert.ok(docs.includes('id="core-repl"'));
  assert.match(docs, /bootstrapped compiler/i);
});
