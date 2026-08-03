import { readFile } from "node:fs/promises";

const wasmUrl = new URL("../../public/yalisp/seed.wasm", import.meta.url);
const bootstrapUrl = new URL("../../public/yalisp/boot.lisp", import.meta.url);
const sourceUrl = new URL("../../src/examples/hello-world/app.lisp", import.meta.url);
const [wasm, bootstrap, source] = await Promise.all([readFile(wasmUrl), readFile(bootstrapUrl, "utf8"), readFile(sourceUrl, "utf8")]);
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
const run = (form, print = false) => {
  const bytes = encoder.encode(form.trim());
  if (bytes.length > 8192 - inputPointer) throw new Error("Hello World exceeds the seed input region.");
  new Uint8Array(memory.buffer).set(bytes, inputPointer);
  instance.exports[print ? "eval_print" : "eval_all"](inputPointer, bytes.length);
};
instance.exports.init();
run(bootstrap);
run(source);
run("(app.result)", true);
