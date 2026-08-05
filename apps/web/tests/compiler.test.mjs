import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import wabtInit from "wabt";

const [seed, bootstrap, compilerSource, aotArtifact] = await Promise.all([
  readFile(new URL("../public/yalisp/seed.wasm", import.meta.url)),
  readFile(new URL("../public/yalisp/boot.lisp", import.meta.url), "utf8"),
  readFile(new URL("../public/yalisp/compiler.lisp", import.meta.url), "utf8"),
  readFile(new URL("../public/yalisp/aot-benchmark.wasm", import.meta.url))
]);
const wabt = await wabtInit();
const encoder = new TextEncoder();
const decoder = new TextDecoder();
const inputPointer = 1024;
const inputEnd = 131072;

async function createCompilerSession() {
  let memory;
  let output = "";
  const { instance } = await WebAssembly.instantiate(seed, {
    host: {
      write(pointer, length) {
        output += decoder.decode(new Uint8Array(memory.buffer, pointer, length));
      },
      bytes_write() {
        throw new Error("the compiler test does not request binary output");
      }
    }
  });
  memory = instance.exports.memory;
  const load = (source) => {
    const bytes = encoder.encode(source);
    assert.ok(bytes.length <= inputEnd - inputPointer, "compiler test input exceeds the seed input region");
    new Uint8Array(memory.buffer).set(bytes, inputPointer);
    return bytes.length;
  };
  const evaluateAll = (source) => {
    output = "";
    instance.exports.eval_all(inputPointer, load(source));
  };
  const evaluate = (source) => {
    output = "";
    instance.exports.eval_print(inputPointer, load(source));
    return output.trim();
  };
  instance.exports.init();
  evaluateAll(bootstrap);
  evaluateAll(compilerSource);
  return { evaluate };
}

function assemble(payload) {
  const parsed = wabt.parseWat("yalisp-compiled.wat", `(module (func (export "run") ${payload}))`, {});
  try {
    parsed.validate();
    return Buffer.from(parsed.toBinary({ write_debug_names: false }).buffer);
  } finally {
    parsed.destroy();
  }
}

async function compile(session, params, body) {
  const payload = session.evaluate(`(cc.compile '${params} '(${body}))`);
  assert.notEqual(payload, "nil", `compiler rejected ${body}`);
  const { instance } = await WebAssembly.instantiate(assemble(payload));
  return { payload, run: instance.exports.run };
}

test("YALISP compiler is Lisp-written and preserves its Lispish provenance", () => {
  assert.match(compilerSource, /compiler written in YALISP/);
  assert.match(compilerSource, /ETdoFreshAI\/lispish/);
  assert.match(compilerSource, /commit b7214f1/);
  assert.match(compilerSource, /signed 30-bit fixnum range/);
});

test("compiled arithmetic is semantically equivalent to the seed on the supported subset", async () => {
  const session = await createCompilerSession();
  for (const body of ["(+ (* x x) 1)", "(- (* x 3) 4)", "(+ -7 (* x 2))"]) {
    const compiled = await compile(session, "(x)", body);
    for (const value of [-10, -1, 0, 1, 21, 100]) {
      const interpreted = Number(session.evaluate(`((lambda (x) ${body}) ${value})`));
      assert.equal(compiled.run(value), interpreted, `${body} diverged at ${value}`);
    }
  }
});

test("compiler rejects every form outside its declared bounded surface", async () => {
  const session = await createCompilerSession();
  for (const request of [
    "(cc.compile '(x y) '((+ x y)))",
    "(cc.compile '(x) '((/ x 2)))",
    "(cc.compile '(x) '((+ x 1 2)))",
    "(cc.compile '(x) '((+ y 1)))",
    "(cc.compile '(x) '((if x 1 0)))",
    "(cc.compile '(x) '((+ x 1) (* x 2)))"
  ]) {
    assert.equal(session.evaluate(request), "nil", `unexpectedly compiled ${request}`);
  }
});

test("checked-in AOT artifact is the compiler output for the exact benchmark workload", async () => {
  const session = await createCompilerSession();
  const payload = session.evaluate("(cc.compile '(x) '((+ (* x x) 1)))");
  assert.deepEqual(aotArtifact, assemble(payload));
  const { instance } = await WebAssembly.instantiate(aotArtifact);
  assert.equal(instance.exports.run(21), 442);
});
