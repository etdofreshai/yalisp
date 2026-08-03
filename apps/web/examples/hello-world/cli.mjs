import { readFile } from "node:fs/promises";

const wasmUrl = new URL("../../public/yalisp/seed.wasm", import.meta.url);
const sourceUrl = new URL("../../src/examples/hello-world/hello.lisp", import.meta.url);
const [wasm, source] = await Promise.all([readFile(wasmUrl), readFile(sourceUrl, "utf8")]);
const encoder = new TextEncoder();
const decoder = new TextDecoder();
const inputPointer = 1024;
let memory;

const { instance } = await WebAssembly.instantiate(wasm, {
  host: {
    write(pointer, length) {
      process.stdout.write(decoder.decode(new Uint8Array(memory.buffer, pointer, length)));
    }
  }
});

memory = instance.exports.memory;
const bytes = encoder.encode(source.trim());
if (bytes.length > 8192 - inputPointer) throw new Error("Hello World exceeds the seed input region.");
new Uint8Array(memory.buffer).set(bytes, inputPointer);
instance.exports.init();
instance.exports.eval_print(inputPointer, bytes.length);
