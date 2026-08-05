import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import ts from "typescript";

async function surfaceModule() {
  const source = await readFile(new URL("../src/examples/runtime/indexed-surface.ts", import.meta.url), "utf8");
  const javascript = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext }
  }).outputText;
  return import(`data:text/javascript;base64,${Buffer.from(javascript).toString("base64")}`);
}

test("generic indexed surfaces expand Lisp-provided palette indexes without application data", async () => {
  const { expandIndexedSurface } = await surfaceModule();
  const pixels = expandIndexedSurface(new Uint8Array([0, 1, 2, 1]), 2, 2, ["#123", "#abcdef", "#000000"]);
  assert.deepEqual(Array.from(pixels), [17, 34, 51, 255, 171, 205, 239, 255, 0, 0, 0, 255, 171, 205, 239, 255]);
  assert.throws(() => expandIndexedSurface(new Uint8Array([0]), 2, 2, ["#000"]), /expected 4 bytes/);
  assert.throws(() => expandIndexedSurface(new Uint8Array([1]), 1, 1, ["#000"]), /undeclared palette index 1/);
  assert.throws(() => expandIndexedSurface(new Uint8Array([0]), 1, 1, ["not-a-color"]), /#rgb or #rrggbb/);
});
