import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import process from "node:process";

import wabtInit from "wabt";

const root = new URL("../../", import.meta.url);
const artifacts = Object.freeze({
  wat: new URL("apps/web/src/seed/bootstrap.wat", root),
  wasm: new URL("apps/web/public/yalisp/seed.wasm", root),
  bootstrap: new URL("apps/web/public/yalisp/boot.lisp", root),
  compiler: new URL("apps/web/public/yalisp/compiler.lisp", root),
  aotExample: new URL("apps/web/public/yalisp/aot-benchmark.wasm", root),
});

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
const bytesByName = Object.fromEntries(await Promise.all(
  Object.entries(artifacts).map(async ([name, url]) => [name, await readFile(url)]),
));

const wabt = await wabtInit();
const module = wabt.readWasm(bytesByName.wasm, { readDebugNames: false });
let unfolded;
try {
  unfolded = module.toText({ foldExprs: false, inlineExport: false });
} finally {
  module.destroy();
}

// WABT's unfolded form emits one instruction per line. The count deliberately
// includes structural control operators (block/loop/if/else/end) so the metric
// remains stable and reviewable instead of pretending to be retired hardware
// instructions. Declarations such as func/type/local/import/export are excluded.
const instruction = /^(?:i32\.|i64\.|f32\.|f64\.|local\.|global\.|memory\.|table\.|ref\.|call(?:_indirect)?\b|return\b|drop\b|select\b|unreachable\b|nop\b|block\b|loop\b|if\b|else\b|end\b|br(?:_if|_table)?\b)/;
const instructionCounts = {};
let staticInstructionLines = 0;
for (const sourceLine of unfolded.split("\n")) {
  const line = sourceLine.trim();
  if (!instruction.test(line)) continue;
  const [operator] = line.match(/^[A-Za-z0-9_.]+/) ?? [];
  if (!operator) throw new Error(`unable to identify unfolded instruction: ${line}`);
  instructionCounts[operator] = (instructionCounts[operator] ?? 0) + 1;
  staticInstructionLines += 1;
}

const compiledSeed = await WebAssembly.compile(bytesByName.wasm);
const imports = WebAssembly.Module.imports(compiledSeed);
const exports = WebAssembly.Module.exports(compiledSeed);
const definedFunctions = unfolded.split("\n").filter((line) => /^\s*\(func\b/.test(line)).length;

const result = {
  schema: "yalisp-artifact-inventory-v1",
  toolchain: {
    node: process.version,
    platform: process.platform,
    architecture: process.arch,
  },
  artifacts: Object.fromEntries(Object.entries(bytesByName).map(([name, bytes]) => [name, {
    bytes: bytes.byteLength,
    sha256: sha256(bytes),
  }])),
  seedModule: {
    imports,
    exports,
    definedFunctions,
    staticInstructionLines,
    instructionCountingRule: "WABT unfolded numeric/local/global/memory/table/ref/call/control/branch/return/drop/select/trap lines, including else/end",
    instructionCounts: Object.fromEntries(Object.entries(instructionCounts).sort(([a], [b]) => a.localeCompare(b))),
  },
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
