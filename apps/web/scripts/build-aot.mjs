import { readFile, writeFile } from "node:fs/promises";
import wabtInit from "wabt";

const base = new URL("../", import.meta.url);
const [seed, bootstrap, compiler] = await Promise.all([
  readFile(new URL("public/yalisp/seed.wasm", base)),
  readFile(new URL("public/yalisp/boot.lisp", base), "utf8"),
  readFile(new URL("public/yalisp/compiler.lisp", base), "utf8")
]);

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const inputPointer = 1024;
let memory;
let output = "";
const { instance } = await WebAssembly.instantiate(seed, {
  host: {
    write(pointer, length) {
      output += decoder.decode(new Uint8Array(memory.buffer, pointer, length));
    }
  }
});
memory = instance.exports.memory;

function load(source) {
  const bytes = encoder.encode(source);
  if (bytes.length > 8192 - inputPointer) throw new Error("compiler build input exceeds the seed input region");
  new Uint8Array(memory.buffer).set(bytes, inputPointer);
  return bytes.length;
}

function evaluateAll(source) {
  output = "";
  instance.exports.eval_all(inputPointer, load(source));
}

function evaluate(source) {
  output = "";
  instance.exports.eval_print(inputPointer, load(source));
  return output.trim();
}

instance.exports.init();
evaluateAll(bootstrap);
evaluateAll(compiler);
const payload = evaluate("(cc.compile '(x) '((+ (* x x) 1)))");
if (!payload || payload === "nil") throw new Error("YALISP compiler rejected the checked-in AOT workload");

const wat = `(module (func (export "run") ${payload}))`;
const wabt = await wabtInit();
const parsed = wabt.parseWat("aot-benchmark.wat", wat, {});
try {
  parsed.validate();
  const { buffer } = parsed.toBinary({ write_debug_names: false });
  await writeFile(new URL("public/yalisp/aot-benchmark.wasm", base), Buffer.from(buffer));
  console.log(`wrote public/yalisp/aot-benchmark.wasm: ${buffer.length} bytes`);
} finally {
  parsed.destroy();
}
